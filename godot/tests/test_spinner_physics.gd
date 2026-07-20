extends RefCounted

## spinner_physics.gd のテスト。
##
## プロトタイプ(simulation.py)との数値照合はしない。Vector2の成分は32bitで
## GDScriptのfloat(64bit)ともnumpyのfloat64とも一致せず、衝突が誤差を
## 指数的に増幅するため、軌跡の厳密一致は原理的に不可能。追いかけると
## 永遠に緑にならないテストになる。
##
## 代わりに、各関数が「意図した式になっているか」を、向きや単調性といった
## 数値に依らない性質で検証する。手触りの調整で定数を変えても壊れない。
##
## 保存則について: これはゲームのための嘘物理で、系全体では保存しない。
## spin_kickは回転をエネルギー源に運動を足すし、壁のrestitutionも1とは限らない。
## 下の運動量保存・エネルギー保存のテストは elastic_velocities という
## 「完全弾性衝突の式」単体が正しく書けているかを見ているだけで、ゲームが
## 満たすべき法則ではない。コマ同士の衝突を非弾性にしたくなったら、
## 迷わずこのテストの方を書き換えること。

const EPS := 1e-4

const SHAPE_NAMES := {
	SpinnerPhysics.StageShape.DISH: "すり鉢",
	SpinnerPhysics.StageShape.CONE: "円錐",
	SpinnerPhysics.StageShape.STEEP: "急峻",
}


func run(check: Callable) -> void:
	_test_stage_slope(check)
	_test_stage_steep(check)
	_test_stage_ellipse_warp(check)
	_test_contours(check)
	_test_friction(check)
	_test_collision_detection(check)
	_test_elastic_formula_momentum(check)
	_test_elastic_formula_energy(check)
	_test_elastic_separates(check)
	_test_elastic_restitution(check)
	_test_spin_drain(check)
	_test_spin_kick(check)
	_test_wall(check)
	_test_clamp_speed(check)
	_test_natural_decay(check)


func _test_stage_slope(check: Callable) -> void:
	var center := Vector2(5, 5)

	# どちらの形でも、中心では傾斜がないので力は働かない
	for shape in SHAPE_NAMES:
		check.call(
			SpinnerPhysics.stage_slope_accel(center, center, 4.9, shape).length() < EPS,
			"ステージ傾斜(%s): 中心では力ゼロ" % SHAPE_NAMES[shape]
		)

	# どちらの形でも、常に中心へ滑り落ちる向き
	for shape in SHAPE_NAMES:
		var accel := SpinnerPhysics.stage_slope_accel(Vector2(8, 5), center, 4.9, shape)
		check.call(
			accel.x < 0.0 and absf(accel.y) < EPS,
			"ステージ傾斜(%s): 中心へ向かう" % SHAPE_NAMES[shape]
		)

	# すり鉢は外側ほど傾斜が急: 2倍離れれば2倍の力
	var dish_near := SpinnerPhysics.stage_slope_accel(
		Vector2(6, 5), center, 4.9, SpinnerPhysics.StageShape.DISH).length()
	var dish_far := SpinnerPhysics.stage_slope_accel(
		Vector2(7, 5), center, 4.9, SpinnerPhysics.StageShape.DISH).length()
	check.call(
		absf(dish_far - dish_near * 2.0) < EPS,
		"すり鉢: 変位に比例して強くなる (%.3f vs %.3f)" % [dish_far, dish_near * 2.0]
	)

	# 円錐は一定傾斜: どこでも同じ大きさ
	var cone_near := SpinnerPhysics.stage_slope_accel(
		Vector2(6, 5), center, 4.9, SpinnerPhysics.StageShape.CONE).length()
	var cone_far := SpinnerPhysics.stage_slope_accel(
		Vector2(9, 5), center, 4.9, SpinnerPhysics.StageShape.CONE).length()
	check.call(
		absf(cone_far - cone_near) < EPS and absf(cone_near - 4.9) < EPS,
		"円錐: 距離によらず一定 (%.3f vs %.3f)" % [cone_near, cone_far]
	)


## 急峻(STEEP)は加速度∝r²。DISHより外側で急に強くなることを確認する。
func _test_stage_steep(check: Callable) -> void:
	var center := Vector2(5, 5)
	var s := SpinnerPhysics.StageShape.STEEP

	# r=1 と r=2 で 2²=4倍。変位の2乗で戻す。
	var near := SpinnerPhysics.stage_slope_accel(Vector2(6, 5), center, 1.0, s).length()
	var far := SpinnerPhysics.stage_slope_accel(Vector2(7, 5), center, 1.0, s).length()
	check.call(
		absf(far - near * 4.0) < EPS,
		"急峻: 変位の2乗で強くなる (%.3f vs %.3f)" % [far, near * 4.0]
	)

	# 外周では DISH より急。同じ strength・同じ遠方(r=3)で比較。r³ > r。
	var steep_far := SpinnerPhysics.stage_slope_accel(
		Vector2(8, 5), center, 1.0, s).length()
	var dish_far := SpinnerPhysics.stage_slope_accel(
		Vector2(8, 5), center, 1.0, SpinnerPhysics.StageShape.DISH).length()
	check.call(steep_far > dish_far, "急峻: 外周ではDISHより急 (%.3f > %.3f)" % [steep_far, dish_far])


## 楕円ワープ: 横長(x軸が大)では x 方向の戻しが y より弱い。ONEで従来DISHと一致。
func _test_stage_ellipse_warp(check: Callable) -> void:
	var center := Vector2(5, 5)
	var d := SpinnerPhysics.StageShape.DISH
	# 積=1に正規化した横長の軸(ax>1>ay)。
	var axes := Vector2(sqrt(2.0), sqrt(0.5))

	# 同じ距離2でも、x方向の戻し < y方向の戻し(横に転がりやすい谷)。
	var ax := SpinnerPhysics.stage_slope_accel(Vector2(7, 5), center, 4.9, d, axes).length()
	var ay := SpinnerPhysics.stage_slope_accel(Vector2(5, 7), center, 4.9, d, axes).length()
	check.call(ax < ay, "楕円ワープ: 横方向の戻しが縦より弱い (%.3f < %.3f)" % [ax, ay])

	# slope_axes=ONE は従来のDISHと厳密一致。
	var warped := SpinnerPhysics.stage_slope_accel(Vector2(8, 6), center, 4.9, d, Vector2.ONE)
	var plain := SpinnerPhysics.stage_slope_accel(Vector2(8, 6), center, 4.9, d)
	check.call(warped.is_equal_approx(plain), "楕円ワープ: 軸ONEはDISHと一致")


## 等高線: 急峻(strength大/STEEP)ほど本数が増え、DISHは外周で詰まり円錐は等間隔。
func _test_contours(check: Callable) -> void:
	var d := SpinnerPhysics.StageShape.DISH
	# strengthが大きいほど本数が単調非減少(クランプ上限まで)。
	var few := StageContours.contour_radii(d, 2.0, 5.0).size()
	var many := StageContours.contour_radii(d, 8.0, 5.0).size()
	check.call(many >= few and many > 0, "等高線: 急峻(強)なほど本数が多い (%d >= %d)" % [many, few])

	# DISHは外周ほど間隔が狭い(r∝√f)。隣り合う輪郭の差が「厳密に」減少する
	# (等間隔では駄目＝すり鉢の外周が急という情報が出ていない)。
	var dish := StageContours.contour_radii(d, 4.9, 5.0)
	var dish_ok := dish.size() >= 3
	for i in range(2, dish.size()):
		if dish[i] - dish[i - 1] >= dish[i - 1] - dish[i - 2] - EPS:
			dish_ok = false
	check.call(dish_ok, "等高線: すり鉢は外周ほど詰まる")

	# 円錐は等高さ=等間隔(r∝f)。隣接差が一定。
	var cone := StageContours.contour_radii(SpinnerPhysics.StageShape.CONE, 4.9, 5.0)
	var cone_ok := cone.size() >= 3
	for i in range(2, cone.size()):
		if absf((cone[i] - cone[i - 1]) - (cone[i - 1] - cone[i - 2])) > EPS:
			cone_ok = false
	check.call(cone_ok, "等高線: 円錐は等間隔")


func _test_friction(check: Callable) -> void:
	var vel := Vector2(3, 4)  # 長さ5
	var accel := SpinnerPhysics.friction_accel(vel, 2.0)
	check.call(absf(accel.length() - 2.0) < EPS, "摩擦: 大きさは速度によらず一定")
	check.call(accel.normalized().dot(vel.normalized()) < -0.999, "摩擦: 進行方向と逆向き")
	# 速度ゼロで0除算しない（プロトタイプはここでnanになる）
	var stopped := SpinnerPhysics.friction_accel(Vector2.ZERO, 2.0)
	check.call(stopped == Vector2.ZERO, "摩擦: 停止時はゼロ(nanにならない)")


func _test_collision_detection(check: Callable) -> void:
	var approaching_a := Vector2(0, 0)
	var approaching_b := Vector2(0.9, 0)
	check.call(
		SpinnerPhysics.is_colliding(approaching_a, 0.5, Vector2(1, 0), approaching_b, 0.5, Vector2(-1, 0)),
		"衝突判定: 接触して近づいていれば真"
	)
	# 接触していても離れていく最中なら偽（多重衝突を防ぐ）
	check.call(
		not SpinnerPhysics.is_colliding(approaching_a, 0.5, Vector2(-1, 0), approaching_b, 0.5, Vector2(1, 0)),
		"衝突判定: 離れていく最中は偽"
	)
	# 離れていれば偽
	check.call(
		not SpinnerPhysics.is_colliding(Vector2(0, 0), 0.5, Vector2(1, 0), Vector2(5, 0), 0.5, Vector2(-1, 0)),
		"衝突判定: 離れていれば偽"
	)


## 以下2つは「完全弾性衝突の式が正しく書けているか」の確認であって、
## ゲームが保存則を満たすべきという主張ではない。質量比の取り違えなど
## よくある移植ミスがここで確実に落ちるので、式の検算として置いている。
func _test_elastic_formula_momentum(check: Callable) -> void:
	var pos_a := Vector2(0, 0); var vel_a := Vector2(2, 1); var mass_a := 1.5
	var pos_b := Vector2(0.9, 0.2); var vel_b := Vector2(-1, 0.5); var mass_b := 3.0

	var before := mass_a * vel_a + mass_b * vel_b
	var result := SpinnerPhysics.elastic_velocities(pos_a, vel_a, mass_a, pos_b, vel_b, mass_b)
	var after := mass_a * result[0] + mass_b * result[1]

	check.call(
		(after - before).length() < EPS,
		"弾性衝突の式: 運動量が保存する (%s -> %s)" % [before, after]
	)


func _test_elastic_formula_energy(check: Callable) -> void:
	var pos_a := Vector2(0, 0); var vel_a := Vector2(2, 1); var mass_a := 1.5
	var pos_b := Vector2(0.9, 0.2); var vel_b := Vector2(-1, 0.5); var mass_b := 3.0

	var before := 0.5 * mass_a * vel_a.length_squared() + 0.5 * mass_b * vel_b.length_squared()
	var result := SpinnerPhysics.elastic_velocities(pos_a, vel_a, mass_a, pos_b, vel_b, mass_b)
	var after := 0.5 * mass_a * result[0].length_squared() + 0.5 * mass_b * result[1].length_squared()

	check.call(
		absf(after - before) < 1e-3,
		"弾性衝突の式: 運動エネルギーが保存する (%.5f -> %.5f)" % [before, after]
	)


func _test_elastic_separates(check: Callable) -> void:
	# 正面衝突したら離れる向きになること
	var pos_a := Vector2(0, 0); var pos_b := Vector2(0.9, 0)
	var result := SpinnerPhysics.elastic_velocities(
		pos_a, Vector2(1, 0), 1.0, pos_b, Vector2(-1, 0), 1.0
	)
	var closing := (result[0] - result[1]).dot(pos_a - pos_b)
	check.call(closing > 0.0, "弾性衝突: 衝突後は離れていく (closing=%.3f)" % closing)

	# 完全に重なっている場合は向きが定まらないので何もしない
	var overlapped := SpinnerPhysics.elastic_velocities(
		Vector2.ZERO, Vector2(1, 0), 1.0, Vector2.ZERO, Vector2(-1, 0), 1.0
	)
	check.call(
		overlapped[0] == Vector2(1, 0) and overlapped[1] == Vector2(-1, 0),
		"弾性衝突: 完全に重なった時は変化なし(0除算しない)"
	)


## 反発係数を敵衝突にも効かせる引数(Rage Reflectionの想定)。
## e=1で従来の完全弾性と一致し、e<1で分離速度が落ちる（非弾性）。
func _test_elastic_restitution(check: Callable) -> void:
	var pos_a := Vector2(0, 0); var pos_b := Vector2(0.9, 0)
	var vel_a := Vector2(1, 0); var vel_b := Vector2(-1, 0)

	# 引数なし(既定e=1)と e=1.0 明示が一致すること。
	var default_e := SpinnerPhysics.elastic_velocities(pos_a, vel_a, 1.0, pos_b, vel_b, 1.0)
	var explicit_1 := SpinnerPhysics.elastic_velocities(pos_a, vel_a, 1.0, pos_b, vel_b, 1.0, 1.0)
	check.call(
		default_e[0].is_equal_approx(explicit_1[0]) and default_e[1].is_equal_approx(explicit_1[1]),
		"反発係数: e=1は従来の完全弾性と一致"
	)

	# 正面衝突の分離速度: e=1 > e=0.5 > e=0。単調に落ちる。
	var sep_1 := (explicit_1[0] - explicit_1[1]).dot(pos_a - pos_b)
	var half := SpinnerPhysics.elastic_velocities(pos_a, vel_a, 1.0, pos_b, vel_b, 1.0, 0.5)
	var sep_half := (half[0] - half[1]).dot(pos_a - pos_b)
	var zero := SpinnerPhysics.elastic_velocities(pos_a, vel_a, 1.0, pos_b, vel_b, 1.0, 0.0)
	var sep_zero := (zero[0] - zero[1]).dot(pos_a - pos_b)
	check.call(sep_1 > sep_half + EPS, "反発係数: e<1は分離速度が小さい (%.3f > %.3f)" % [sep_1, sep_half])
	check.call(sep_half > sep_zero - EPS and sep_zero < EPS + 0.0,
		"反発係数: e=0は法線方向に一体化(分離ゼロ) (%.3f)" % sep_zero)
	# 分離速度が反発係数に比例する（e=0.5はe=1のほぼ半分）。
	check.call(absf(sep_half - sep_1 * 0.5) < EPS,
		"反発係数: 分離速度がeに比例 (%.3f vs %.3f)" % [sep_half, sep_1 * 0.5])


func _test_spin_drain(check: Callable) -> void:
	# 相手が重いほど削られる
	var light := SpinnerPhysics.spin_drain(1.0, 5.0, 2.0, 0.5, 0.08)
	var heavy := SpinnerPhysics.spin_drain(4.0, 5.0, 2.0, 0.5, 0.08)
	check.call(heavy > light, "RPS減少: 相手が重いほど大きい")

	# ぶつかる相対速さが大きいほど削られる（第2引数は相手の絶対速度ではなく相対速度）
	var slow := SpinnerPhysics.spin_drain(2.0, 1.0, 2.0, 0.5, 0.08)
	var fast := SpinnerPhysics.spin_drain(2.0, 9.0, 2.0, 0.5, 0.08)
	check.call(fast > slow, "RPS減少: 相対速さが大きいほど大きい")

	# 自分が重い/大きいほど削られにくい
	var frail := SpinnerPhysics.spin_drain(2.0, 5.0, 1.0, 0.5, 0.08)
	var sturdy := SpinnerPhysics.spin_drain(2.0, 5.0, 4.0, 0.5, 0.08)
	check.call(sturdy < frail, "RPS減少: 自分が重いほど小さい")
	var small := SpinnerPhysics.spin_drain(2.0, 5.0, 2.0, 0.5, 0.08)
	var big := SpinnerPhysics.spin_drain(2.0, 5.0, 2.0, 1.5, 0.08)
	check.call(big < small, "RPS減少: 自分が大きいほど小さい")

	# ゼロ除算しない
	check.call(SpinnerPhysics.spin_drain(2.0, 5.0, 0.0, 0.5, 0.08) == 0.0, "RPS減少: 質量0でも落ちない")


func _test_spin_kick(check: Callable) -> void:
	var pos_self := Vector2(0, 0)
	var pos_other := Vector2(1, 0)
	var kick := SpinnerPhysics.spin_kick(pos_self, pos_other, 0.5, 2.0, 1.0)
	# 相手から離れる向き（プロトタイプはここが逆で引き寄せ合っていた）
	check.call(kick.x < 0.0, "回転キック: 相手から離れる向き (%s)" % kick)
	# 削られた量が多いほど強く弾ける
	var weak := SpinnerPhysics.spin_kick(pos_self, pos_other, 0.5, 1.0, 1.0).length()
	var strong := SpinnerPhysics.spin_kick(pos_self, pos_other, 0.5, 3.0, 1.0).length()
	check.call(strong > weak, "回転キック: RPS減少が大きいほど強い")


func _test_wall(check: Callable) -> void:
	# 左の壁: x=0にあり、内側(+x)を向く
	var wall_point := Vector2(0, 5)
	var wall_normal := Vector2(1, 0)

	check.call(
		SpinnerPhysics.wall_hit(wall_point, wall_normal, Vector2(0.3, 5), Vector2(-1, 0), 0.5),
		"壁: めり込んで壁へ向かっていれば真"
	)
	check.call(
		not SpinnerPhysics.wall_hit(wall_point, wall_normal, Vector2(0.3, 5), Vector2(1, 0), 0.5),
		"壁: めり込んでいても離れる向きなら偽"
	)
	check.call(
		not SpinnerPhysics.wall_hit(wall_point, wall_normal, Vector2(5, 5), Vector2(-1, 0), 0.5),
		"壁: 離れていれば偽"
	)

	# 反射: 法線方向が反転し、接線方向は保たれる
	var bounced := SpinnerPhysics.wall_bounce(Vector2(-2, 3), wall_normal, 1.0)
	check.call(absf(bounced.x - 2.0) < EPS, "壁: 法線方向が反転する (x=%.3f)" % bounced.x)
	check.call(absf(bounced.y - 3.0) < EPS, "壁: 接線方向は保たれる (y=%.3f)" % bounced.y)

	# restitutionで勢いが落ちる
	var damped := SpinnerPhysics.wall_bounce(Vector2(-2, 0), wall_normal, 0.5)
	check.call(absf(damped.x - 1.0) < EPS, "壁: restitutionで勢いが落ちる (x=%.3f)" % damped.x)

	# 壁rps保持(wall_keep)は実効ダンピングを1.0(無損失)へ寄せる。Rage Reflection用。
	check.call(
		absf(SpinnerPhysics.effective_wall_damping(0.8, 0.0) - 0.8) < EPS,
		"壁rps保持: keep=0は素通し(baseのまま)"
	)
	check.call(
		absf(SpinnerPhysics.effective_wall_damping(0.8, 1.0) - 1.0) < EPS,
		"壁rps保持: keep=1で無損失(1.0)"
	)
	# keep=0.5でbaseと1.0の中点。かつkeepが増えるほど1.0へ近づく(損失が減る)。
	check.call(
		absf(SpinnerPhysics.effective_wall_damping(0.8, 0.5) - 0.9) < EPS,
		"壁rps保持: ke=0.5でbaseと1.0の中点 (%.3f)" % SpinnerPhysics.effective_wall_damping(0.8, 0.5)
	)
	check.call(
		SpinnerPhysics.effective_wall_damping(0.8, 0.5) > SpinnerPhysics.effective_wall_damping(0.8, 0.0),
		"壁rps保持: keepが増えると壁でのrps喪失が減る"
	)


## 速度上限。反発>1(Rage Reflection)で壁反射のたびに加速して脱出するのを防ぐ。
func _test_clamp_speed(check: Callable) -> void:
	# 上限超は大きさが上限に丸められ、向きは保たれる。
	var fast := SpinnerPhysics.clamp_speed(Vector2(30, 40), 10.0)  # 元の大きさ50
	check.call(absf(fast.length() - 10.0) < EPS, "速度上限: 上限超は大きさが上限に丸まる (%.3f)" % fast.length())
	check.call(
		fast.normalized().dot(Vector2(30, 40).normalized()) > 0.999,
		"速度上限: 丸めても向きは保たれる"
	)
	# 上限以下は不変。
	var slow := SpinnerPhysics.clamp_speed(Vector2(3, 4), 10.0)  # 大きさ5
	check.call(slow.is_equal_approx(Vector2(3, 4)), "速度上限: 上限以下は不変")
	# max_speed<=0は無制限(不変)。
	var uncapped := SpinnerPhysics.clamp_speed(Vector2(30, 40), 0.0)
	check.call(uncapped.is_equal_approx(Vector2(30, 40)), "速度上限: <=0は無制限で不変")
	# ゼロベクトルはNaNにならずゼロのまま。
	var zero := SpinnerPhysics.clamp_speed(Vector2.ZERO, 10.0)
	check.call(zero == Vector2.ZERO, "速度上限: ゼロはゼロのまま(nanにならない)")


func _test_natural_decay(check: Callable) -> void:
	var small := SpinnerPhysics.natural_spin_decay(0.5, 1.0, 0.1)
	var big := SpinnerPhysics.natural_spin_decay(1.5, 1.0, 0.1)
	check.call(big > small, "自然減衰: 大きいコマほど速く回転を失う")
	check.call(absf(small - 0.05) < EPS, "自然減衰: radius*rate*delta (%.4f)" % small)
