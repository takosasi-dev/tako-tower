// Web 版をまとめて確かめて、画面を撮る(Chrome 1 回の起動で済ませる)。全部の画像は build/web_shots/。
// タイトル → 設定 → いつもの塔(本物のマウスで最初の 1 手と空振り、残りは window.ttTap で探した道を流す)→ 一時停止 → 結果
// → やり直す(影・区切りの差)→ 結果 → コピー → 保存 → 読み込み後の通信 0 件。横長の PC の画面(1280×800)の見え方も撮る。
//     python tools/gd.py run res://tools/tower_path.gd fixed out=res://build/fixed_path.json   (先に道を作る)
//     node tests/web/check.mjs                  手元の build/web を配って確かめる
//     TT_URL=https://…/tako-tower/ node tests/web/check.mjs   公開した物を確かめる
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { DESKTOP, PLAY, ROOT, expect, failureCount, open, serve, sleep } from './lib.mjs';

const STAND = 0, STICK = 1, FLY = 2;
const plan = JSON.parse(readFileSync(path.join(ROOT, 'build', 'fixed_path.json'), 'utf8'));
const site = serve();
const page = await open(site.url + '?debug=1', PLAY);

// 探した道を流す。tick に届き、立つか張り付いていて、空振りの待ちが無い時に次を押す。onState で場面を撮る
async function climb(moves, onState = async () => {}, until = () => false) {
	let i = 0;
	const end = Date.now() + 60000;
	while (Date.now() < end) {
		const s = await page.state();
		if (s.screen !== 'play' || !s.play) return s;
		const p = s.play;
		if (p.over || until(s)) return s;
		await onState(s);
		if (i < moves.length && p.tick >= moves[i][0] && (p.state === STAND || p.state === STICK) && p.lock === 0 && !s.paused) {
			await page.tapWorld(moves[i][1], moves[i][2]);
			i++;
		}
		await sleep(8);
	}
	return page.state();
}

try {
	expect(page.booted, `起動した(${page.bootMs} ms)`);
	const t = await page.waitState((s) => s.screen === 'title', 30000);
	expect(!!t, 'S1 タイトルが出る');
	console.log(`    タイトルが出るまで: ${Date.now() - page.t0} ms(ページを開いてから)`);
	const loadedAt = Date.now();
	await sleep(300);
	await page.shot('s1_title');
	await page.resize(DESKTOP);
	await sleep(500);
	await page.shot('s1_title_desktop');
	await page.resize(PLAY);
	await sleep(500);

	// 設定
	expect(await page.clickButton('settings'), '設定を押す');
	expect(!!(await page.waitState((s) => s.settings)), 'S4 設定');
	await page.clickButton('volume_50');
	await sleep(300);
	await page.shot('s4_settings');
	expect((await page.state()).sfx >= 1, '音量を選ぶと張り付く音を鳴らす');
	await page.clickButton('volume_75');
	await page.clickButton('back');
	await page.waitState((s) => s.screen === 'title' && !s.settings);

	// いつもの塔(本物のマウス)
	expect(await page.clickButton('fixed'), 'いつもの塔を押す');
	const p0 = await page.waitState((s) => s.screen === 'play');
	expect(!!p0, 'S2 プレイ');
	await sleep(400);
	await page.shot('s2_start');
	let s = await page.state();
	// 真下の足場を押す: 空振り(too_close)。手数に数え、時計は動かない
	await page.click(...(await page.gameCss(s.play.x, s.play.y + 30 - s.play.cam_y)));
	await sleep(60);
	await page.shot('s2_cast_miss');
	s = await page.waitState((st) => st.play.lock === 0, 3000);
	expect(s && s.play.moves === 1 && s.play.clock === 0, `空振りは手数 1・時計 0: ${JSON.stringify(s?.play)}`);
	// 最初の 1 手を本物のマウスで(カメラは塔の下で止まっているので、画面の点と塔の点がずれない)
	const m0 = plan.moves[0];
	await page.click(...(await page.gameCss(m0[1], m0[2] - s.play.cam_y)));
	const fly = await page.waitState((st) => st.play.state === FLY, 2000);
	expect(!!fly, 'マウスで押すと腕が出て飛ぶ');
	await page.shot('s2_fly');
	const st1 = await page.waitState((st) => st.play.state === STICK, 2000);
	await sleep(40);
	await page.shot('s2_stick');
	expect(!!st1 && st1.play.clock > 0, '張り付くと時計が動く');

	// 残りを流す。場面を撮る
	const want = { split: true, brittle: true, crumbled: true, pause: true, high: true };
	const rest = plan.moves.slice(1).map((m) => [m[0] + st1.play.tick - plan.moves[1][0] + 1, m[1], m[2]]);
	const r1 = await climb(rest, async (st) => {
		const p = st.play;
		if (want.split && p.segment === 2) {
			want.split = false;
			await sleep(150);
			await page.shot('s2_split');
		}
		if (want.pause && p.segment === 3) {
			want.pause = false;
			await page.key('Escape');
			const ps = await page.waitState((x) => x.paused, 2000);
			expect(!!ps, 'Esc で一時停止');
			const tk = ps.play.tick;
			await sleep(600);
			await page.shot('s5_pause');
			await page.resize(DESKTOP);
			await sleep(400);
			await page.shot('s5_pause_desktop');
			expect((await page.state()).play.tick === tk, '一時停止の間は進まない');
			await page.key('Escape');
			expect(!!(await page.waitState((x) => !x.paused, 2000)), 'Esc で続ける');
			// 横長の画面で、一時停止のボタンを本物のマウスで押す(左右に余りがある時の座標)
			expect(await page.clickButton('pause'), '横長の画面で一時停止のボタンを押す');
			expect(!!(await page.waitState((x) => x.paused, 2000)), 'ボタンで一時停止');
			expect(await page.clickButton('resume'), '続けるを押す');
			expect(!!(await page.waitState((x) => !x.paused, 2000)), '続ける');
			await page.resize(PLAY);
		}
		if (want.brittle && p.brittle > 0) {
			want.brittle = false;
			await sleep(200);
			await page.shot('s2_brittle');
		}
		if (want.crumbled && p.gone > 0) {
			want.crumbled = false;
			await page.shot('s2_crumbled');
		}
		if (want.high && p.segment === 5 && p.state === FLY) {
			want.high = false;
			await page.shot('s2_high');
		}
	});
	expect(r1.screen === 'result' || r1.play?.over, `ゴールした: ${JSON.stringify(r1.play)}`);
	await page.shot('s2_goal');
	const res = await page.waitState((x) => x.screen === 'result', 5000);
	expect(!!res, 'S3 結果');
	await sleep(500);
	await page.shot('s3_result_first');
	const saved = await page.saved();
	expect(saved?.fixed?.best_ticks > 0, `保存が tako-tower/save に入る: best_ticks ${saved?.fixed?.best_ticks}`);

	// コピー
	await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
	await page.clickButton('copy');
	await sleep(500);
	const c1 = await page.clipboard();
	expect(c1.startsWith('TakoTower '), `コピーのボタン: ${JSON.stringify(c1).slice(0, 80)}`);

	// やり直す(R キー)。影と区切りの差
	await page.key('r');
	expect(!!(await page.waitState((x) => x.screen === 'play', 3000)), 'R でやり直す');
	const g = await page.state();
	expect(g.play.ghost === true, '2 回目は影が出る');
	await page.resize(DESKTOP);
	await sleep(400);
	await page.shot('s2_start_desktop');
	// 横長の画面で、真下の足場を本物のマウスで押す: 押した塔の点が ±1 px で合う(空振りになり、道はずれない)
	const gd = await page.state();
	const want0 = [Math.round(gd.play.x), Math.round(gd.play.y + 30)];
	await page.click(...(await page.gameCss(want0[0], want0[1] - gd.play.cam_y)));
	const gt = await page.waitState((x) => x.play.tap[0] !== -1, 2000);
	expect(gt && Math.abs(gt.play.tap[0] - want0[0]) <= 1 && Math.abs(gt.play.tap[1] - want0[1]) <= 1,
		`横長の画面のクリックが塔の点に合う: ${JSON.stringify(gt?.play.tap)} / ${JSON.stringify(want0)}`);
	await page.resize(PLAY);
	await sleep(300);
	// タブが裏に回ると一時停止(E-11)。戻っても自動では再開しない
	await page.hide();
	await sleep(800);
	await page.show();
	const hid = await page.waitState((x) => x.paused, 5000);
	expect(!!hid, 'タブが裏に回ると一時停止');
	if (hid) {
		await sleep(500);
		const tk = (await page.state()).play.tick;
		await sleep(800);
		expect((await page.state()).play.tick === tk, '戻っても止まったまま');
		await page.key('Escape');
		expect(!!(await page.waitState((x) => !x.paused, 3000)), 'Esc で続ける');
	}
	const want2 = { split: true, ghost: true };
	const g0 = (await page.state()).play.tick;
	// 2 回目は、1 手目の前に 1 秒待つ(影が先に行く)
	const moves2 = plan.moves.map((m) => [m[0] + g0 + 120, m[1], m[2]]);
	const r2 = await climb(moves2, async (st) => {
		const p = st.play;
		if (want2.ghost && p.segment === 1 && p.tick > g0 + 200) {
			want2.ghost = false;
			await page.shot('s2_ghost');
		}
		if (want2.split && p.segment === 2) {
			want2.split = false;
			await sleep(150);
			await page.shot('s2_split_diff');
		}
	});
	expect(r2.screen === 'result' || r2.play?.over, 'もう一度ゴールした');
	await page.waitState((x) => x.screen === 'result', 5000);
	await sleep(500);
	await page.shot('s3_result_second');
	await page.resize(DESKTOP);
	await sleep(400);
	await page.shot('s3_result_desktop');
	await page.resize(PLAY);
	await sleep(300);

	// 3 回目: 道の 46 手目まで流して手を止める。区画 5 でもろい壁が崩れてトゲに落ち、ミスになる(ヘッドレスの Climb で確かめた列)
	const t3 = Date.now();
	expect(await page.clickButton('retry'), '結果のやり直すをマウスで押す');
	expect(!!(await page.waitState((x) => x.screen === 'play', 3000, 5)), `やり直す(押してから操作できるまで ${Date.now() - t3} ms。状態を読む間を含む)`);
	// タッチ(模擬)で真下の足場を押す: マウスの左ボタンとして届き、押した点が合う(AC-25 は窓なし Chrome の模擬まで)
	const gs = await page.state();
	const want3 = [Math.round(gs.play.x), Math.round(gs.play.y + 30)];
	await page.touch(...(await page.gameCss(want3[0], want3[1] - gs.play.cam_y)));
	const tt = await page.waitState((x) => x.play.tap[0] !== -1, 2000);
	expect(tt && tt.play.moves === 1 && Math.abs(tt.play.tap[0] - want3[0]) <= 1 && Math.abs(tt.play.tap[1] - want3[1]) <= 1,
		`タッチでも押せる: ${JSON.stringify(tt?.play.tap)} / ${JSON.stringify(want3)} 手数 ${tt?.play.moves}`);
	const g3 = (await page.state()).play.tick;
	const ms = await climb(plan.moves.slice(0, 46).map((m) => [m[0] + g3 + 2, m[1], m[2]]), async () => {}, (x) => x.play.misses > 0);
	if (expect(ms.play?.misses > 0, `手を止めるとミスになる: ${JSON.stringify(ms.play)}`)) {
		await page.shot('s2_miss');
		await sleep(180);
		await page.shot('s2_respawn');
		const back = await page.waitState((x) => x.play.state === STAND, 3000);
		expect(!!back, '入口に戻って立つ');
		await page.shot('s2_respawned');
	}
	// 4 回目: 点滅を弱める=入・揺れ=切 にして同じミス(NFR-12 の画像)
	await page.key('Escape');
	await page.waitState((x) => x.paused, 2000);
	await page.clickButton('settings');
	await page.waitState((x) => x.settings, 2000);
	await page.clickButton('reduce_flash_true');
	await page.clickButton('shake_false');
	await sleep(200);
	await page.shot('s4_settings_reduced');
	await page.clickButton('back');
	await page.waitState((x) => !x.settings && x.paused, 2000);
	await page.clickButton('restart');
	expect(!!(await page.waitState((x) => x.screen === 'play' && !x.paused && x.play.tick < 30, 3000)), '一時停止からやり直す');
	const g4 = (await page.state()).play.tick;
	const ms4 = await climb(plan.moves.slice(0, 46).map((m) => [m[0] + g4 + 2, m[1], m[2]]), async () => {}, (x) => x.play.misses > 0);
	if (expect(ms4.play?.misses > 0, '点滅を弱めた時もミスになる')) await page.shot('s2_miss_reduced');
	await page.key('Escape');
	await page.waitState((x) => x.paused, 2000);
	await page.clickButton('title');
	expect(!!(await page.waitState((x) => x.screen === 'title', 3000)), '一時停止からタイトルへ');
	await sleep(300);
	await page.shot('s1_title_record');
	await sleep(1000);
	await page.shot('s1_title_demo');
	await page.resize({ width: 720, height: 1600, deviceScaleFactor: 1, mobile: false });
	await sleep(500);
	await page.shot('s1_title_tall');
	await page.resize(PLAY);

	// 読み込みの後 3 分の通信(AC-27)
	const left = loadedAt + 180000 - Date.now();
	if (left > 0) await sleep(left);
	const after = page.requests.filter((r) => r.at > loadedAt);
	expect(after.length === 0, `読み込みの後の通信 ${after.length} 件(${Math.round((Date.now() - loadedAt) / 1000)} 秒見た)` + (after.length ? ': ' + after.map((r) => r.url).join(', ') : ''));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));
	console.log('    押してから腕を描くまで・1 フレーム(ms): ' + JSON.stringify(await page.stats()));

	// 開き直す(同じプロフィール): 保存を読み戻し、いつもの塔に影が出て、設定が残る
	expect(await page.goto(page.url0), '同じプロフィールで開き直す');
	expect(!!(await page.waitState((x) => x.screen === 'title', 30000)), '開き直してタイトル');
	expect(await page.clickButton('fixed'), 'いつもの塔');
	const rl = await page.waitState((x) => x.screen === 'play', 3000);
	expect(rl?.play?.ghost === true, `開き直しても影が出る(保存を読めた): ${rl?.play?.ghost}`);
	const sv = await page.saved();
	expect(sv?.settings?.reduce_flash === true && sv?.settings?.shake === false, `設定が残る: ${JSON.stringify(sv?.settings)}`);
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? 'ALL OK' : `NG ${failureCount()} 件`);
process.exit(failureCount() === 0 ? 0 : 1);
