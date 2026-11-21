// 1 フレームの時間を、2 つの書き出しで交互に測る(タイトルに 6 秒・遊びの画面で立ったまま 6 秒。requestAnimationFrame の間隔)。
// 窓なし Chrome はソフト描画なので、人の Chrome(GPU)の値ではない。前後の比べだけに使う。
//     node tests/web/frame_time.mjs <前の build/web> <後の build/web> [回数]
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, rmdirSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { PLAY, open, sleep } from './lib.mjs';

const [a, b, n = '2'] = process.argv.slice(2);
const root = mkdtempSync(path.join(tmpdir(), 'tt-frame-'));
symlinkSync(path.resolve(a), path.join(root, 'a'), 'junction');
symlinkSync(path.resolve(b), path.join(root, 'b'), 'junction');
const server = spawn(process.env.TT_PYTHON || 'python', ['-m', 'http.server', '8812', '--bind', '127.0.0.1', '--directory', root], { stdio: 'ignore' });
await sleep(800);
const RAF = `new Promise((ok) => { const d = []; let last = 0; const end = performance.now() + 6000;
	const f = (t) => { if (last) d.push(t - last); last = t; if (t < end) requestAnimationFrame(f); else { d.sort((x, y) => x - y); ok([d[Math.floor(d.length / 2)], d[Math.ceil(d.length * 0.95) - 1]].map((v) => Math.round(v * 10) / 10)); } };
	requestAnimationFrame(f); })`;
const out = { a: [], b: [] };
try {
	for (let i = 0; i < Number(n); i++) {
		for (const k of ['a', 'b']) {
			const page = await open(`http://127.0.0.1:8812/${k}/?debug=1`, PLAY);
			await page.waitState((s) => s.screen === 'title', 60000);
			await sleep(1500);
			const title = await page.evaluate(RAF);
			await page.clickButton('fixed');
			await page.waitState((s) => s.screen === 'play', 5000);
			await sleep(1000);
			const play = await page.evaluate(RAF);
			out[k].push({ title, play });
			await page.close();
		}
	}
} finally {
	server.kill();
	rmSync(path.join(root, 'a'), { force: true });
	rmSync(path.join(root, 'b'), { force: true });
	rmdirSync(root);
}
console.log('[中央値, 95%] ms');
console.log(`前 ${JSON.stringify(out.a)}`);
console.log(`後 ${JSON.stringify(out.b)}`);
