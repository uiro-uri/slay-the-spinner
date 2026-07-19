class_name LaunchSpeed
extends RefCounted

## 自機・敵で共有する発射速度レンジ(ユニット/秒)。
##
## かつては自機が引き量×pull_to_speedで0〜20、敵はEnemyDataの固定値(6.0〜9.8/ボス8.5)と
## レンジがバラバラだった。位置と向きは出現ごとにランダムなのに速度だけ固定という半端な
## 状態でもあった。ここに一本化する。
##
## **MAX=12** は自機・敵で共通の上限。自機は full pull でMAX、敵は抽選の上限。20だとボスが
## 壁に突撃して無敵中にrpsを大量に失い自滅する(=待つだけで倒せた。enemy_roster.gdの
## 発射速度11.0→8.5の経緯参照)。上限12でその暴発を抑える。
##
## **MIN=4.5** は敵の抽選下限。自機は引き量0で速度0まで撃てる(狙いの三角形を常時描くので
## 低速でも見える)が、敵は EnemyTelegraph の予告三角形の長さが sqrt(速度)×length_scale で
## 決まるため、低速すぎると予告がコマの下に隠れて読めなくなる(test_telegraph_visibleが
## 守っているバグ)。最大のコマ(ボス:実効半径≈1.91)でも予告がコマ縁+0.5余って見えるには
## sqrt(速度)×1.2 ≥ 2.41 → 速度 ≥ 約4.04 が要る。余裕を見て4.5。副次的に、[4.5,12]の一様
## 平均8.25は旧来の敵速度(6〜9.8/平均~8)にほぼ一致し、バランスの激変も避けられる。
## MINを下げるならtest_telegraph_visibleが最初に落ちる。
##
## Nodeに依存しない純粋な計算なので、ヘッドレスから直接テストできる。
const MIN := 4.5
const MAX := 12.0


## 敵の初速。出現位置・向きと同じく、出現ごとに[MIN, MAX]から一様抽選する。
## EnemyTelegraphが予告するので「ランダムだが読める」を維持できる。
static func random(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(MIN, MAX)


## 自機の初速。引き量(0..max_pull)の比をMAXにマップする。full pullでMAX、無引きで0。
## 自機は下限MINを持たない(引き量に応じて0まで出せる。狙いの三角形は常時見える)。
static func from_pull(pull_len: float, max_pull: float) -> float:
	if max_pull <= 0.0:
		return 0.0
	return clampf(pull_len / max_pull, 0.0, 1.0) * MAX
