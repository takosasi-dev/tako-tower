// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前後の見比べと、はみ出しの確かめ用)。画像は build/web_shots/<組>/。
// 縦画面のゲームなので、1280×720 などは縦横を入れ替えた 720×1280・1080×1920・768×1024・1080×2560 と、スマホの 390×844(記録だけ)。
//     python tools/gd.py run res://tools/tower_path.gd fixed out=res://build/fixed_path.json   (先に道を作る)
//     node tests/web/shots.mjs after
import { mkdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { OUT, PLAY, ROOT, expect, failureCount, open, serve, sleep } from './lib.mjs';

const SET = process.argv[2] || 'after';
const SIZES = [[720, 1280], [1080, 1920], [768, 1024], [1080, 2560], [390, 844], [1280, 800]];
const STAND = 0, STICK = 1;
const plan = JSON.parse(readFileSync(path.join(ROOT, 'build', 'fixed_path.json'), 'utf8'));
mkdirSync(path.join(OUT, SET), { recursive: true });
const site = serve();
const page = await open(site.url + '?debug=1', PLAY);

async function all(name, wait = 450) {
	for (const [w, h] of SIZES) {
		await page.resize({ width: w, height: h, deviceScaleFactor: 1, mobile: false });
		await sleep(wait);
		await page.shot(`${SET}/${name}_${w}x${h}`);
	}
	await page.resize(PLAY);
	await sleep(200);
}

let done = 0; // 流した手の数
async function climb(moves, until, i = 0) {
	const end = Date.now() + 60000;
	while (Date.now() < end) {
		const s = await page.state();
		if (s.screen !== 'play' || !s.play || s.play.over || until(s)) return s;
		const p = s.play;
		if (i < moves.length && p.tick >= moves[i][0] && (p.state === STAND || p.state === STICK) && p.lock === 0 && !s.paused) {
			await page.tapWorld(moves[i][1], moves[i][2]);
			i++;
			done = i;
		}
		await sleep(8);
	}
	return page.state();
}

try {
	const first = await page.waitState((s) => s.screen === 'title', 60000);
	console.log(`    起動 ${page.bootMs} ms、タイトルまで ${Date.now() - page.t0} ms`);
	expect(!!first, 'タイトル');
	// S0(読み込み): 回線を絞って開き直し、読み込みの途中を撮る
	await page.cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 20, downloadThroughput: 4e6, uploadThroughput: 1e6 });
	const from = page.logs.length;
	await page.cdp.send('Page.navigate', { url: page.url0 });
	await sleep(2500);
	await page.shot(`${SET}/s0_loading_720x1280`).catch(() => null);
	await sleep(1500);
	await page.shot(`${SET}/s0_loading2_720x1280`).catch(() => null);
	await page.cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
	await page.waitState((s) => s.screen === 'title', 90000);
	expect(page.logs.slice(from).some((l) => String(l.text).startsWith('Godot Engine v')), '起動した');
	await sleep(600);
	await all('s1_title');
	expect(await page.clickButton('settings'), '設定');
	await page.waitState((s) => s.settings);
	await all('s4_settings');
	await page.key('Escape');
	await page.waitState((s) => !s.settings && s.screen === 'title');
	await sleep(500);
	expect(await page.clickButton('fixed'), 'いつもの塔');
	const p0 = await page.waitState((s) => s.screen === 'play' && !s.settings);
	await sleep(600);
	await all('s2_start');
	const t0 = p0.play.tick;
	const moves = plan.moves.map((m) => [m[0] + t0 + 30, m[1], m[2]]);
	// 区画 3 で張り付いたまま手を止めて撮る
	await climb(moves, (s) => s.play.segment >= 3 && s.play.state === STICK);
	await all('s2_mid', 350);
	await page.key('Escape');
	await page.waitState((s) => s.paused);
	await sleep(500);
	await all('s5_pause');
	await page.key('Escape');
	await page.waitState((s) => !s.paused);
	await climb(moves.map((m) => [0, m[1], m[2]]), () => false, done);
	const r = await page.waitState((s) => s.screen === 'result', 15000);
	expect(!!r, '結果');
	await sleep(1500);
	await all('s3_result', 300);
	// 2 回目で自己最高を出す(影・区切りの差・記録更新の祝い)
	const tr = Date.now();
	await page.key('r');
	const q = await page.waitState((s) => s.screen === 'play' && s.play.tick < 30, 5000, 5);
	console.log(`    R から遊びまで ${Date.now() - tr} ms(状態を読む間を含む)`);
	await climb(plan.moves.map((m) => [m[0] + q.play.tick + 2, m[1], m[2]]), () => false);
	await page.waitState((s) => s.screen === 'result', 15000);
	await sleep(1800);
	await all('s3_result_best', 300);
	await page.clickButton('copy');
	await sleep(400);
	await page.shot(`${SET}/s3_toast_720x1280`);
	// 共有の枠の右クリックの品書き(既定の見た目が漏れていないか)
	const [mx, my] = await page.gameCss(300, 949);
	for (const type of ['mousePressed', 'mouseReleased']) await page.cdp.send('Input.dispatchMouseEvent', { type, x: mx, y: my, button: 'right', clickCount: 1 });
	await sleep(400);
	await page.shot(`${SET}/s3_menu_720x1280`);
	await page.key('Escape');
	await sleep(200);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title');
	await sleep(800);
	await page.shot(`${SET}/s1_title_record_720x1280`);
	// キーボードだけ: 下の矢印でフォーカスが今日の塔へ動く
	await page.key('ArrowDown');
	await sleep(300);
	await page.shot(`${SET}/s1_focus_720x1280`);
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? 'ALL OK' : `NG ${failureCount()} 件`);
process.exit(failureCount() === 0 ? 0 : 1);
