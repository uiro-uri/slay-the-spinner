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
