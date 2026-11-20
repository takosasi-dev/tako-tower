// ブラウザでの自動の確認の土台(RootCall の tests/web/lib.mjs を写した物)。Web 書き出しを手元で配り、
// 窓なし・消音・使い捨てのプロフィールの Chrome を CDP で動かす。状態は ?debug=1 の時の window.ttState を読むだけで、入力は本物のキーとマウスを送る。
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
export const WEB = path.join(ROOT, 'build', 'web');
export const OUT = path.join(ROOT, 'build', 'web_shots');
export const SAVE_KEY = 'tako-tower/save'; // save/save_store.gd の WEB_KEY
const HTTP_PORT = Number(process.env.TT_HTTP_PORT || 8812);
const CDP_PORT = Number(process.env.TT_CDP_PORT || 9812);
const BOOT_TIMEOUT_MS = 90000;
export const CHROME = process.env.TT_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
export const DESKTOP = { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false };
// 1 CSS px = 1 ゲームの px(塔の中の点をずれなく押せる)
export const PLAY = { width: 720, height: 1280, deviceScaleFactor: 1, mobile: false };

// CDP の Input.dispatchKeyEvent に渡す形。文字は keyOf(文字) で作る
const SPECIAL = {
	Enter: { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, text: '\r' },
	Tab: { key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 },
	Backspace: { key: 'Backspace', code: 'Backspace', windowsVirtualKeyCode: 8 },
	Escape: { key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 },
	ArrowLeft: { key: 'ArrowLeft', code: 'ArrowLeft', windowsVirtualKeyCode: 37 },
	ArrowUp: { key: 'ArrowUp', code: 'ArrowUp', windowsVirtualKeyCode: 38 },
	ArrowRight: { key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39 },
	ArrowDown: { key: 'ArrowDown', code: 'ArrowDown', windowsVirtualKeyCode: 40 },
};
const SYMBOL = { ' ': ['Space', 32], '-': ['Minus', 189], '.': ['Period', 190], '/': ['Slash', 191], '=': ['Equal', 187], '_': ['Minus', 189, true] };

export function keyOf(c) {
	if (SPECIAL[c]) return SPECIAL[c];
	if (SYMBOL[c]) {
		const [code, vk, shift] = SYMBOL[c];
		return { key: c, code, windowsVirtualKeyCode: vk, text: c, modifiers: shift ? 8 : 0 };
	}
	if (/[0-9]/.test(c)) return { key: c, code: `Digit${c}`, windowsVirtualKeyCode: c.charCodeAt(0), text: c };
	const up = c.toUpperCase();
	return { key: c, code: `Key${up}`, windowsVirtualKeyCode: up.charCodeAt(0), text: c, modifiers: c === up ? 8 : 0 };
}

let failures = 0;
export function expect(ok, label) {
	console.log(`${ok ? 'OK' : 'NG'}  ${label}`);
	if (!ok) failures++;
	return ok;
}
export const failureCount = () => failures;
export { sleep };

export async function waitFor(fn, timeoutMs, everyMs = 200) {
	const end = Date.now() + timeoutMs;
	while (Date.now() < end) {
		const v = await fn();
		if (v) return v;
		await sleep(everyMs);
	}
	return null;
}

async function connect(url) {
	const ws = new WebSocket(url);
	await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
	let id = 0;
	const pending = new Map();
	const listeners = [];
	ws.onmessage = (m) => {
		const msg = JSON.parse(m.data);
		if (msg.id && pending.has(msg.id)) {
			const { ok, ng } = pending.get(msg.id);
			pending.delete(msg.id);
			msg.error ? ng(new Error(msg.error.message)) : ok(msg.result);
		} else listeners.forEach((f) => f(msg));
	};
	return {
		send: (method, params = {}) => new Promise((ok, ng) => {
			const i = ++id;
			pending.set(i, { ok, ng });
			ws.send(JSON.stringify({ id: i, method, params }));
		}),
		onEvent: (f) => listeners.push(f),
		close: () => ws.close(),
	};
}

// build/web を /tako-tower/ の下に置いて配る(Pages と同じ形)。TT_URL を入れると、その URL(公開した物)を確かめる。
export function serve() {
	if (process.env.TT_URL) return { url: process.env.TT_URL, stop: () => {} };
	if (!existsSync(path.join(WEB, 'index.html'))) throw new Error('build/web/index.html が無い(先に python tools/gd.py export)');
	const root = mkdtempSync(path.join(tmpdir(), 'tt-site-'));
	symlinkSync(WEB, path.join(root, 'tako-tower'), 'junction');
	const py = process.env.TT_PYTHON || 'python';
	const server = spawn(py, ['-m', 'http.server', String(HTTP_PORT), '--bind', '127.0.0.1', '--directory', root], { stdio: 'ignore' });
	return {
		url: `http://127.0.0.1:${HTTP_PORT}/tako-tower/`,
		stop: () => { server.kill(); rmSync(path.join(root, 'tako-tower'), { force: true }); },
	};
}

export async function open(url, metrics = DESKTOP) {
	if (!existsSync(CHROME)) throw new Error('Chrome が無い');
	mkdirSync(OUT, { recursive: true });
	const profile = mkdtempSync(path.join(tmpdir(), 'tt-chrome-'));
	const args = ['--headless=new', '--mute-audio', `--remote-debugging-port=${CDP_PORT}`, `--user-data-dir=${profile}`,
		'--no-first-run', '--no-default-browser-check', '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
		'--enable-unsafe-swiftshader', 'about:blank'];
	const proc = spawn(CHROME, args, { stdio: 'ignore' });
	const target = await waitFor(async () => {
		try { return (await (await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`)).json()).find((t) => t.type === 'page'); }
		catch { return null; }
	}, BOOT_TIMEOUT_MS);
	if (!target) { proc.kill(); throw new Error('ブラウザにつながらない'); }
	const cdp = await connect(target.webSocketDebuggerUrl);
	const logs = [];
	const requests = [];
	const urls = new Map();
	const sizes = {};
	cdp.onEvent((msg) => {
		const p = msg.params;
		if (msg.method === 'Runtime.consoleAPICalled') logs.push({ level: p.type, text: p.args.map((a) => a.value ?? a.description).join(' ') });
		else if (msg.method === 'Runtime.exceptionThrown') logs.push({ level: 'exception', text: p.exceptionDetails.exception?.description ?? p.exceptionDetails.text });
		else if (msg.method === 'Network.requestWillBeSent' && /^https?:/.test(p.request.url)) {
			requests.push({ at: Date.now(), url: p.request.url });
			urls.set(p.requestId, p.request.url);
		} else if (msg.method === 'Network.webSocketCreated') requests.push({ at: Date.now(), url: p.url });
		else if (msg.method === 'Network.loadingFinished') {
			const file = path.posix.basename(new URL(urls.get(p.requestId) ?? 'http://x/?').pathname) || 'index.html';
			sizes[file] = (sizes[file] ?? 0) + p.encodedDataLength;
		}
	});
	for (const m of ['Runtime.enable', 'Page.enable', 'Network.enable']) await cdp.send(m);
	await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
	await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true });
	await cdp.send('Emulation.setDeviceMetricsOverride', metrics);
	const t0 = Date.now();
	await cdp.send('Page.navigate', { url });
	const booted = await waitFor(() => logs.some((l) => String(l.text).startsWith('Godot Engine v')), BOOT_TIMEOUT_MS, 50);
	const evaluate = async (expression) => (await cdp.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })).result.value;
	const page = {
		cdp, logs, requests, booted: booted !== null, bootMs: Date.now() - t0, t0, url0: url,
		sizes: () => ({ ...sizes }),
		evaluate,
		state: async () => { try { return JSON.parse(await evaluate('window.ttState') || '{}'); } catch { return {}; } },
		stats: async () => { try { return JSON.parse(await evaluate('window.ttStats') || '{}'); } catch { return {}; } },
		waitState: async (pred, timeoutMs = 15000) => waitFor(async () => { const s = await page.state(); return pred(s) ? s : null; }, timeoutMs, 50),
		saved: async () => JSON.parse(await evaluate(`localStorage.getItem('${SAVE_KEY}')`) ?? 'null'),
		// 同じプロフィールのまま別の URL を開き直す。Godot が起動するまで待つ
		goto: async (to) => {
			const from = logs.length;
			await cdp.send('Page.navigate', { url: to });
			return await waitFor(() => logs.slice(from).some((l) => String(l.text).startsWith('Godot Engine v')), BOOT_TIMEOUT_MS, 50) !== null;
		},
		touch: async (x, y) => {
			await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
			await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y, id: 0 }] });
			await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
			await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: false });
		},
		clipboard: async () => {
			await cdp.send('Browser.grantPermissions', { permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'] }).catch(() => {});
			return await evaluate('navigator.clipboard.readText().catch((e) => "(読めない: " + e + ")")');
		},
		// 修飾キー付きで押す(modifiers: 2 = Ctrl、8 = Shift)
		keyMod: async (k, modifiers) => {
			const ev = { ...keyOf(k), modifiers, text: undefined };
			await cdp.send('Input.dispatchKeyEvent', { type: 'rawKeyDown', ...ev, commands: modifiers === 2 && k === 'a' ? ['selectAll'] : modifiers === 2 && k === 'c' ? ['copy'] : [] });
			await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', ...ev });
		},
		// 1 文字か特別なキー(Enter・Tab など)を押して離す
		key: async (k) => {
			const ev = keyOf(k);
			await cdp.send('Input.dispatchKeyEvent', { type: ev.text ? 'keyDown' : 'rawKeyDown', ...ev });
			await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', ...ev, text: undefined });
		},
		// 文字を打つ。\n は Enter、\t は Tab
		type: async (text, gapMs = 40) => {
			for (const c of text) {
				await page.key(c === '\n' ? 'Enter' : c === '\t' ? 'Tab' : c);
				await sleep(gapMs);
			}
		},
		// ゲームの座標(720×1280)→ CSS の px(縦横比を保って中央に置かれる)
		gameCss: async (gx, gy) => {
			const [w, h] = await evaluate('[window.innerWidth, window.innerHeight]');
			const k = Math.min(w / 720, h / 1280);
			return [(w - 720 * k) / 2 + gx * k, (h - 1280 * k) / 2 + gy * k];
		},
		click: async (x, y) => {
			await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
			await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
		},
		// 塔の中の点を押す(?debug=1 の window.ttTap。カメラが動いていても点がずれない)
		tapWorld: (wx, wy) => evaluate(`window.ttTap(${wx}, ${wy})`),
		// 画面の大きさを変える(同じプロフィールのまま)
		resize: (m) => cdp.send('Emulation.setDeviceMetricsOverride', m),
		clickButton: async (name) => {
			const s = await page.waitState((st) => st.buttons && st.buttons[name], 8000);
			if (!s) return false;
			await page.click(...(await page.gameCss(...s.buttons[name])));
			return true;
		},
		hide: async () => {
			await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: false });
			await fetch(`http://127.0.0.1:${CDP_PORT}/json/new?about:blank`, { method: 'PUT' });
		},
		show: () => fetch(`http://127.0.0.1:${CDP_PORT}/json/activate/${target.id}`, { method: 'PUT' }),
		shot: async (label) => {
			const file = path.join(OUT, `${label}.png`);
			writeFileSync(file, Buffer.from((await cdp.send('Page.captureScreenshot', { format: 'png' })).data, 'base64'));
			return file;
		},
		errors: () => logs.filter((l) => ['error', 'exception'].includes(l.level) && !String(l.text).includes('favicon.ico')),
		close: async () => {
			try { await cdp.send('Browser.close'); } catch { /* もう閉じた */ }
			cdp.close();
			await Promise.race([new Promise((ok) => proc.once('exit', ok)), sleep(3000)]);
			proc.kill();
			rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 500 });
		},
	};
	return page;
}
