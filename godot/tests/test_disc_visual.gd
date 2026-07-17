extends RefCounted

## Disc.gd の回転の見せ方のテスト。
##
## 見た目のバグはスクショ1枚では絶対に分からない。「止まって見える」かどうかは
## フレーム間の変化でしか判定できず、しかも実速度とは無関係に起きる。
## 実際、以前の破線8本は初期値の15rpsで完全に静止していたのに、
## 画面を見ても誰も気づかなかった。だから数値で押さえる。

## 想定するフレームレート。ナイキストの計算に使う。
const FPS := 60.0

## RPSの上限(CustomPartCatalog.RPS_CAP)。ここまで破綻しないこと。
const MAX_RPS := 40.0

const EPS := 1e-4


func run(check: Callable) -> void:
	_test_no_aliasing(check)
	_test_tail_encodes_speed(check)
	_test_visual_rps_monotonic(check)
	_test_draw_order(check)


func _disc() -> Disc:
	var d := Disc.new()
	var s := SpinnerStats.new()
	s.radius = 0.5
	s.rps = 15.0
	d.stats = s
	return d


## マークが1フレームに回る角度が、正しく見える限界(180°)を超えないこと。
##
## 非対称マークは周期360°なので限界は180°/frame = 30rps。超えると逆回転に
## 見え、ちょうど180°だと前後が定まらない。実速度をそのまま使うと上限の
## 40rpsで240°/frameとなり破綻する。
func _test_no_aliasing(check: Callable) -> void:
	var d := _disc()
	var worst := 0.0
	var worst_rps := 0.0

	for i in 401:
		d.rps = i * 0.1  # 0 から 40 まで
		var deg_per_frame: float = d.visual_rps() * 360.0 / FPS
		if deg_per_frame > worst:
			worst = deg_per_frame
			worst_rps = d.rps

	check.call(
		worst < 180.0,
		"回転: どのRPSでも1フレーム180°未満(逆回転に見えない) 最大 %.1f°/frame @ rps=%.1f" % [worst, worst_rps]
	)
	# 余裕もほしい。ちょうど180°付近は前後が定まらず落ち着かない。
	check.call(
		worst <= 160.0,
		"回転: 限界(180°)に余裕がある (%.1f°/frame)" % worst
	)

	# 通常の戦闘域(初期値15rps以下)は実速度がそのまま出ること。
	# ここを丸めると遅く見えて嘘になる。
	d.rps = 15.0
	check.call(
		is_equal_approx(d.visual_rps(), 15.0),
		"回転: 初期値15rpsは実速度のまま回る (%.2f)" % d.visual_rps()
	)
	d.rps = 1.0
	check.call(is_equal_approx(d.visual_rps(), 1.0), "回転: 瀕死の低RPSも実速度のまま")

	d.free()


## 速さの大きさを尾が持つこと。マークが頭打ちになる高速域で、
## これが唯一の速度情報になる。
func _test_tail_encodes_speed(check: Callable) -> void:
	var d := _disc()

	d.rps = 0.0
	check.call(d.tail_ratio() <= EPS, "尾: 止まっていれば出ない")

	# 単調に伸びること
	var prev := -1.0
	var monotonic := true
	for i in 41:
		d.rps = float(i)
		var r := d.tail_ratio()
		if r < prev - EPS:
			monotonic = false
		prev = r
	check.call(monotonic, "尾: RPSが上がれば必ず伸びる(逆転しない)")

	# マークが頭打ちになる領域でも、尾は差を出せること。
	# ここが潰れると40rpsと25rpsが完全に同じ見た目になる。
	d.rps = d.max_visual_rps
	var at_cap := d.tail_ratio()
	d.rps = MAX_RPS
	var at_max := d.tail_ratio()
	check.call(
		at_max > at_cap + 0.05,
		"尾: マークが頭打ちの領域(%.0f〜%.0f rps)でも速さの差が出る (%.2f → %.2f)" % [
			d.max_visual_rps, MAX_RPS, at_cap, at_max
		]
	)

	# 上限で一周しきること。ブレたリングになる。
	d.rps = MAX_RPS
	check.call(
		is_equal_approx(d.tail_ratio(), 1.0),
		"尾: 上限%.0frpsで円周を一周する (%.2f)" % [MAX_RPS, d.tail_ratio()]
	)
	# 上限を超えても壊れない
	d.rps = 999.0
	check.call(d.tail_ratio() <= 1.0 + EPS, "尾: 上限を超えても一周より長くならない")

	d.free()


## 回転数が高いコマほど手前(z_indexが大)に描かれること。重なったとき勢いのある
## 方が上に見えるようにするための順位付け。床(z=0・不透明)より後ろへは落とさない。
func _test_draw_order(check: Callable) -> void:
	# 単調: 回転数が上がってz_indexが下がることはない。
	var prev := -1
	var monotonic := true
	for i in 401:
		var z := Disc.draw_order_z(i * 0.1)
		if z < prev:
			monotonic = false
		prev = z
	check.call(monotonic, "描画順: 回転数が上がってz_indexが下がることはない")

	# 差のある回転数では、速い方が厳密に手前(重なったとき確実に上)。
	check.call(
		Disc.draw_order_z(20.0) > Disc.draw_order_z(10.0),
		"描画順: 回転数の高い方がz_indexが大きい (%d > %d)" % [
			Disc.draw_order_z(20.0), Disc.draw_order_z(10.0)
		]
	)

	# 床(z=0)より後ろへ落とさない。rpsがどうであれz_indexは0以上。
	var never_negative := true
	for i in 401:
		if Disc.draw_order_z(i * 0.1) < 0:
			never_negative = false
	check.call(never_negative, "描画順: z_indexが0未満にならない(不透明な床の後ろへ落ちない)")

	# 上限で頭打ち。青天井だと予告・衝撃波のレイヤー(Battle.OVERLAY_Z)を侵す。
	check.call(
		Disc.draw_order_z(999.0) <= Disc.DRAW_ORDER_Z_MAX,
		"描画順: z_indexが上限%dで頭打ち (%d)" % [Disc.DRAW_ORDER_Z_MAX, Disc.draw_order_z(999.0)]
	)


func _test_visual_rps_monotonic(check: Callable) -> void:
	var d := _disc()
	var prev := -1.0
	var monotonic := true
	for i in 401:
		d.rps = i * 0.1
		var v := d.visual_rps()
		if v < prev - EPS:
			monotonic = false
		prev = v
	check.call(monotonic, "回転: RPSが上がって遅くなることはない")

	# 0除算やnanにならない
	d.tail_full_rps = 0.0
	check.call(d.tail_ratio() == 0.0, "尾: tail_full_rpsが0でも壊れない")
	d.free()
