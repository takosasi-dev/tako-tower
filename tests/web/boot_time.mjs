// 起動の時間を、2 つの書き出しで交互に測る(揺れる機械でも比べられるように)。タイトルが出るまでの ms を出す。
//     node tests/web/boot_time.mjs <前の build/web> <後の build/web> [回数]
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, rmdirSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { PLAY, open, sleep } from './lib.mjs';

const [a, b, n = '3'] = process.argv.slice(2);
const root = mkdtempSync(path.join(tmpdir(), 'tt-boot-'));
symlinkSync(path.resolve(a), path.join(root, 'a'), 'junction');
symlinkSync(path.resolve(b), path.join(root, 'b'), 'junction');
const server = spawn(process.env.TT_PYTHON || 'python', ['-m', 'http.server', '8812', '--bind', '127.0.0.1', '--directory', root], { stdio: 'ignore' });
await sleep(800);
const out = { a: [], b: [] };
try {
	for (let i = 0; i < Number(n); i++) {
		for (const k of ['a', 'b']) {
			const page = await open(`http://127.0.0.1:8812/${k}/?debug=1`, PLAY);
			const t = await page.waitState((s) => s.screen === 'title', 60000);
			out[k].push(t ? Date.now() - page.t0 : -1);
			await page.close();
		}
	}
} finally {
	server.kill();
	rmSync(path.join(root, 'a'), { force: true });
	rmSync(path.join(root, 'b'), { force: true });
	rmdirSync(root);
}
const med = (v) => [...v].sort((x, y) => x - y)[Math.floor(v.length / 2)];
console.log(`前 ${JSON.stringify(out.a)} 中央値 ${med(out.a)} ms / 後 ${JSON.stringify(out.b)} 中央値 ${med(out.b)} ms`);
