extends RefCounted

## フィールドバリエーション(壁の形・障害物・土俵抽選)のテスト。
##
## spinner_physics.gd / arena_wall.gd と同じく、向き・単調性・不変量で確かめる。
## 生の数値照合はせず、手触りの調整で定数が変わっても壊れない性質を見る。

const EPS := 1e-4

## Battle.gd の enemy_spawn_radius 既定値。障害物がこのリングと重ならないことを確かめる。
const SPAWN_RING := 4.0


func run(check: Callable) -> void:
	_test_obstacle_hit(check)
	_test_obstacle_bounce(check)
	_test_from_polygon(check)
	_test_from_ellipse(check)
	_test_slope_axes(check)
	_test_clamp_inside_ellipse(check)
	_test_inradius(check)
	_test_clamp_inside_circle(check)
	_test_roster(check)
	_test_boss_octagon(check)
	_test_localization(check)
	_test_serialization(check)
	_test_ellipse_resolve(check)


func _stats(mass: float, radius: float, rps: float) -> SpinnerStats:
	var s := SpinnerStats.new()
	s.mass = mass
	s.radius = radius
	s.friction = 0.98
	s.restitution = 1.0
	s.rps = rps
	return s


func _test_obstacle_hit(check: Callable) -> void:
	var c := Vector2(5, 5)
	# めり込んで中心へ向かっていれば真
	check.call(
		SpinnerPhysics.obstacle_hit(c, 1.0, Vector2(5.8, 5), Vector2(-1, 0), 0.5),
		"障害物: めり込んで中心へ向かっていれば真"
	)
	# めり込んでいても離れる向きなら偽（多重衝突を防ぐ）
	check.call(
		not SpinnerPhysics.obstacle_hit(c, 1.0, Vector2(5.8, 5), Vector2(1, 0), 0.5),
		"障害物: めり込んでいても離れる向きなら偽"
	)
	# 離れていれば偽
	check.call(
		not SpinnerPhysics.obstacle_hit(c, 1.0, Vector2(9, 5), Vector2(-1, 0), 0.5),
		"障害物: 離れていれば偽"
	)
	# 完全に中心が重なっていても0除算せず、偽を返す（NaN・クラッシュ無し）
	check.call(
		not SpinnerPhysics.obstacle_hit(c, 1.0, c, Vector2(1, 0), 0.5),
		"障害物: 中心が重なっても壊れない"
	)


func _test_obstacle_bounce(check: Callable) -> void:
	# 障害物を原点に置き、法線＝中心からの放射方向で反射する。
	var obstacle_center := Vector2(0, 0)
	var pos := Vector2(1, 0)
	var normal := (pos - obstacle_center).normalized()
	var bounced := SpinnerPhysics.wall_bounce(Vector2(-2, 3), normal, 1.0)
	check.call(absf(bounced.x - 2.0) < EPS, "障害物: 放射方向が反転する (x=%.3f)" % bounced.x)
	check.call(absf(bounced.y - 3.0) < EPS, "障害物: 接線方向は保たれる (y=%.3f)" % bounced.y)


func _test_from_polygon(check: Callable) -> void:
	var center := Vector2(0, 0)
	var r := 5.0
	var sides := 8
	var walls := ArenaWall.from_polygon(center, r, sides)

	check.call(walls.size() == sides, "多角形: 辺の数だけ壁ができる (%d)" % walls.size())

	var apothem := r * cos(PI / float(sides))
	var normal_sum := Vector2.ZERO
	var all_unit := true
	var all_inward := true
	var all_apothem := true
	for wall in walls:
		normal_sum += wall.normal
		if absf(wall.normal.length() - 1.0) >= EPS:
			all_unit = false
		# 内向き＝中心へ向かう成分が正
		if wall.normal.dot(center - wall.point) <= 0.0:
			all_inward = false
		if absf(wall.point.distance_to(center) - apothem) >= EPS:
			all_apothem = false
	check.call(all_unit, "多角形: 法線はすべて単位ベクトル")
	check.call(all_inward, "多角形: 法線はすべて内向き")
	check.call(all_apothem, "多角形: 辺の点は内接円(apothem)上にある")
	check.call(normal_sum.length() < EPS, "多角形: 内向き法線の総和はゼロ(対称)")


## 楕円の壁: 頂点は楕円上、法線は単位・内向き・総和ゼロ(対称)。
func _test_from_ellipse(check: Callable) -> void:
	var center := Vector2(0, 0)
	var semi := Vector2(7.0, 4.0)
	var sides := 32
	var walls := ArenaWall.from_ellipse(center, semi, sides)

	check.call(walls.size() == sides, "楕円壁: 辺の数だけ壁ができる (%d)" % walls.size())

	var normal_sum := Vector2.ZERO
	var all_unit := true
	var all_inward := true
	var all_on_ellipse := true
	var all_gradient := true
	for wall in walls:
		normal_sum += wall.normal
		if absf(wall.normal.length() - 1.0) >= EPS:
			all_unit = false
		# 内向き＝中心へ向かう成分が正
		if wall.normal.dot(center - wall.point) <= 0.0:
			all_inward = false
		# 頂点が楕円 (x/ax)²+(y/ay)²=1 の上に乗る
		var d := wall.point - center
		if absf((d.x / semi.x) ** 2 + (d.y / semi.y) ** 2 - 1.0) >= EPS:
			all_on_ellipse = false
		# 法線は放射方向でなく楕円の勾配方向(内向き=-∇)。軸上以外では放射とずれる。
		var inward_grad := -Vector2(d.x / semi.x ** 2, d.y / semi.y ** 2).normalized()
		if wall.normal.dot(inward_grad) < 1.0 - EPS:
			all_gradient = false
	check.call(all_unit, "楕円壁: 法線はすべて単位ベクトル")
	check.call(all_inward, "楕円壁: 法線はすべて内向き")
	check.call(all_on_ellipse, "楕円壁: 頂点は楕円上にある")
	check.call(all_gradient, "楕円壁: 法線は楕円の勾配方向(放射でない)")
	check.call(normal_sum.length() < EPS, "楕円壁: 内向き法線の総和はゼロ(対称)")


## 傾斜ワープの半軸比: ELLIPSEは積=1で横長ならax>ay、それ以外はONE。
func _test_slope_axes(check: Callable) -> void:
	var oval := FieldData.slope_axes_for(ArenaWall.WallShape.ELLIPSE, Rect2(0, 0, 10, 6.5))
	check.call(absf(oval.x * oval.y - 1.0) < EPS, "傾斜軸: 積=1に正規化 (%.4f)" % (oval.x * oval.y))
	check.call(oval.x > oval.y, "傾斜軸: 横長ならx軸が大きい (%.3f > %.3f)" % [oval.x, oval.y])

	var rect := FieldData.slope_axes_for(ArenaWall.WallShape.RECT, Rect2(0, 0, 10, 10))
	check.call(rect.is_equal_approx(Vector2.ONE), "傾斜軸: 矩形は円(ONE)")


## 楕円クランプ: 内側は不変、外側は楕円の縁へ寄る。
func _test_clamp_inside_ellipse(check: Callable) -> void:
	var center := Vector2(5, 3.25)
	var semi := Vector2(5.0, 3.25)
	var radius := 0.5

	# 中心はそのまま
	var inside := ArenaWall.clamp_inside_ellipse(center, semi, center, radius)
	check.call(inside.is_equal_approx(center), "楕円クランプ: 中心は不変")

	# 横に大きくはみ出した点は縮小楕円の縁(x方向 semi.x-radius)へ
	var outside := ArenaWall.clamp_inside_ellipse(center, semi, Vector2(100, 3.25), radius)
	check.call(
		absf(outside.x - (center.x + semi.x - radius)) < EPS,
		"楕円クランプ: 横のはみ出しは縁へ (%.3f)" % outside.x
	)
	# 円クランプ(短半径)より横に広く発射できる＝横長を活かせる
	var circ := ArenaWall.clamp_inside_circle(center, minf(semi.x, semi.y), Vector2(100, 3.25), radius)
	check.call(outside.x > circ.x, "楕円クランプ: 円クランプより横に広い (%.3f > %.3f)" % [outside.x, circ.x])


func _test_inradius(check: Callable) -> void:
	var bounds := Rect2(0, 0, 10, 10)
	var rect := ArenaWall.inradius_for(ArenaWall.WallShape.RECT, bounds)
	var octa := ArenaWall.inradius_for(ArenaWall.WallShape.OCTAGON, bounds)
	var round_ := ArenaWall.inradius_for(ArenaWall.WallShape.ROUND, bounds)

	check.call(absf(rect - 5.0) < EPS, "内接円: 矩形は短辺の半分 (%.3f)" % rect)
	# 辺が多いほど内接円は外接円(5)に近づく: 八角形 < 円(32角形) < 矩形
	check.call(octa < rect, "内接円: 八角形は矩形より内側")
	check.call(round_ > octa and round_ < rect, "内接円: 円は八角形と矩形の間")


func _test_clamp_inside_circle(check: Callable) -> void:
	var center := Vector2(5, 5)
	var inradius := 5.0
	var radius := 0.5

	# 内側の点はそのまま
	var inside := ArenaWall.clamp_inside_circle(center, inradius, Vector2(5.5, 5), radius)
	check.call(inside.is_equal_approx(Vector2(5.5, 5)), "円クランプ: 内側の点は不変")

	# 外側の点は inradius - radius の円周へ寄る
	var outside := ArenaWall.clamp_inside_circle(center, inradius, Vector2(100, 5), radius)
	check.call(
		absf(outside.distance_to(center) - (inradius - radius)) < EPS,
		"円クランプ: 外側は内接円-半径へ寄る (%.3f)" % outside.distance_to(center)
	)


func _test_roster(check: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for step in range(1, MapTree.STEP_GOAL + 1):
		var field: FieldData = FieldRoster.pick_for_step(step, rng)
		check.call(
			field != null and field.title_key != "" and field.inradius() > 0.0,
			"土俵抽選: 段%d に出せる土俵がある" % step
		)

	# 全フィールドの障害物が土俵内に収まり、出現リング(半径4)と重ならない。
	var ring_ok := true
	var in_bounds := true
	var strength_ok := true
	for field in FieldRoster.all():
		if field.stage_strength < 0.0:
			strength_ok = false
		var arena_center := field.center()
		var inr := field.inradius()
		for o in field.obstacles:
			var oc := Vector2(o.x, o.y)
			var dist := oc.distance_to(arena_center)
			# 障害物全体が内接円の内側に収まる
			if dist + o.z > inr:
				in_bounds = false
			# 障害物が出現リングを跨がない（リング上の敵と初期重なりを避ける）
			if absf(dist - SPAWN_RING) <= o.z:
				ring_ok = false
	check.call(strength_ok, "土俵抽選: 傾斜の強さは非負")
	check.call(in_bounds, "土俵抽選: 障害物は土俵内に収まる")
	check.call(ring_ok, "土俵抽選: 障害物は出現リングと重ならない")


## ボス段(レベル5)の土俵は必ず八角形闘技場で固定されること。決戦の特別感。
## ボス以外の段は従来どおりランダム(形が固定されない)ことも合わせて見る。
func _test_boss_octagon(check: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	var all_octa := true
	for i in range(20):
		rng.seed = i
		var field: FieldData = FieldRoster.pick_for_step(MapTree.STEP_GOAL, rng)
		if field.wall_shape != ArenaWall.WallShape.OCTAGON:
			all_octa = false
	check.call(all_octa, "土俵抽選: ボス段は必ず八角形闘技場")

	# ボス以外(段1)は形が固定されず、複数の形が出る。
	var shapes := {}
	for i in range(60):
		rng.seed = i + 100
		var field: FieldData = FieldRoster.pick_for_step(1, rng)
		shapes[field.wall_shape] = true
	check.call(shapes.size() > 1, "土俵抽選: ボス以外は形が固定されない (%d種)" % shapes.size())


func _test_localization(check: Callable) -> void:
	TranslationServer.set_locale("ja")
	var untranslated: Array[String] = []
	for field in FieldRoster.all():
		if tr(field.title_key) == field.title_key:
			untranslated.append(field.title_key)
	check.call(untranslated.is_empty(), "土俵: 名前に訳がある (未訳: %s)" % [untranslated])


func _test_serialization(check: Callable) -> void:
	var r := BattleRequest.new()
	r.player = BattleRequest.Launch.new(_stats(1.5, 0.5, 15.0), Vector2(2, 8), Vector2(6, -6))
	r.enemies = [BattleRequest.Launch.new(_stats(1.0, 0.5, 15.0), Vector2(8, 2), Vector2(-3, 4))]
	r.wall_shape = ArenaWall.WallShape.OCTAGON
	r.obstacles = [Vector3(3, 3, 0.6), Vector3(7, 7, 0.6)]

	var revived := BattleRequest.from_dict(r.to_dict())
	check.call(revived.wall_shape == r.wall_shape, "直列化: wall_shapeが往復する")
	check.call(revived.obstacles.size() == r.obstacles.size(), "直列化: 障害物の数が往復する")
	check.call(
		revived.obstacles.size() == 2 and revived.obstacles[0].is_equal_approx(Vector3(3, 3, 0.6)),
		"直列化: 障害物の値が往復する"
	)

	# JSONを通しても壊れない（サーバーへ送る前提）
	var parsed = JSON.parse_string(JSON.stringify(r.to_dict()))
	check.call(parsed != null, "直列化: JSONにできる")
	if parsed != null:
		var from_json := BattleRequest.from_dict(parsed)
		check.call(
			from_json.wall_shape == r.wall_shape and from_json.obstacles.size() == 2,
			"直列化: JSONを通しても土俵が変わらない"
		)

	# 障害物ありのリクエストでも解決が終わり決定的
	r.max_duration = 10.0
	var a := BattleResolver.resolve(r)
	var b := BattleResolver.resolve(BattleRequest.from_dict(r.to_dict()))
	check.call(a.outcome == b.outcome, "直列化: 障害物ありでも同じ結果")


## 楕円ボウルは傾斜軸を wall_shape+arena_bounds から再導出する。JSON往復で軌跡が一致すること。
## (楕円ワープが直列化されず落ちていれば、往復後は円の傾斜になり軌跡がずれて落ちる。)
func _test_ellipse_resolve(check: Callable) -> void:
	var r := BattleRequest.new()
	r.arena_bounds = Rect2(0, 0, 10, 6.5)
	r.wall_shape = ArenaWall.WallShape.ELLIPSE
	r.stage_shape = SpinnerPhysics.StageShape.DISH
	# 横方向へ発射: 楕円ワープの有無で戻され方が変わる位置。
	r.player = BattleRequest.Launch.new(_stats(1.5, 0.5, 15.0), Vector2(2, 3.25), Vector2(5, 0))
	r.enemies = [BattleRequest.Launch.new(_stats(1.0, 0.5, 15.0), Vector2(8, 3.25), Vector2(-3, 0))]
	r.max_duration = 8.0

	var a := BattleResolver.resolve(r)
	var b := BattleResolver.resolve(BattleRequest.from_dict(r.to_dict()))
	check.call(a.outcome == b.outcome, "楕円: JSON往復で結果が一致(傾斜軸を再導出)")
	# プレイヤーの最終位置まで一致(軌跡が完全再現)。
	var same_track := a.player_frames.size() == b.player_frames.size()
	if same_track and a.player_frames.size() > 0:
		var last := a.player_frames.size() - 1
		same_track = a.player_frames[last].position.is_equal_approx(b.player_frames[last].position)
	check.call(same_track, "楕円: 往復後も軌跡が一致")
