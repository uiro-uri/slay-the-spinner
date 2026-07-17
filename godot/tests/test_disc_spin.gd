extends RefCounted

## Disc.gd の回転の見た目のテスト。
##
## 「速く回っているのに止まって見える」状態を機械的に防ぐのが目的。
## rpsは体力そのものなので、見た目から残量が読めないのは致命的だが、
## 見た目のバグはスクリーンショット1枚では絶対に分からない（連続フレームを
## 比べないと静止しているか判断できない）。ここで数値として押さえる。

## 想定するフレームレート。設計解像度と同じく60fps前提で作っている。
const ASSUMED_FPS := 60.0


func run(check: Callable) -> void:
	var disc: Node2D = load("res://scenes/battle/Disc.tscn").instantiate()
	disc.stats = SpinnerStats.new()

	_test_no_aliasing(check, disc)
	_test_monotonic(check, disc)
	_test_stopped(check, disc)

	disc.free()


## 見た目の回転が破線の模様を追い越さないこと。
##
## 破線がDASH_COUNT本なら模様はTAU/DASH_COUNTごとに繰り返す。1フレームで
## その半分より速く回すと、止まって見えたり逆回転して見えたりする
## （標本化定理）。実際、物理のrpsをそのまま見た目に使っていた頃は
## rps=15(初期値)がちょうど90°/frame＝模様2周期分となり完全に静止していた。
func _test_no_aliasing(check: Callable, disc: Node2D) -> void:
	var limit: float = ASSUMED_FPS / float(Disc.DASH_COUNT) / 2.0

	check.call(
		disc.max_visual_rps < limit,
		"回転の見た目: 上限%.2frpsが破線%d本の限界%.2frpsを下回る" % [
			disc.max_visual_rps, Disc.DASH_COUNT, limit
		]
	)

	# 実際に取りうるrpsの全域で限界を超えないこと。
	var worst := 0.0
	for i in 101:
		disc.rps = disc.reference_rps * float(i) / 100.0
		var v: float = disc.visual_rps()
		worst = maxf(worst, v)
	check.call(
		worst < limit,
		"回転の見た目: rps全域で限界内 (最大%.2f < %.2f)" % [worst, limit]
	)

	# 想定上限を超えるrpsを渡されても破綻しないこと。
	disc.rps = disc.reference_rps * 10.0
	check.call(
		disc.visual_rps() < limit,
		"回転の見た目: 想定を超えるrpsでも限界内 (%.2f)" % disc.visual_rps()
	)


## rpsが減れば見た目も必ず遅くなること。
##
## 修正前はrps=40とrps=5が同じ見え方になり、rps=1がrps=5より遅く見えていた。
## 実速度と見た目が対応していないと、プレイヤーは残量を読めない。
func _test_monotonic(check: Callable, disc: Node2D) -> void:
	var samples: Array[float] = [40.0, 30.0, 20.0, 15.0, 10.0, 5.0, 2.0, 1.0, 0.5, 0.2]
	var previous := INF
	var broken := ""
	for rps in samples:
		disc.rps = rps
		var visual: float = disc.visual_rps()
		if visual >= previous:
			broken = "rps=%.1f で %.3f (直前は %.3f)" % [rps, visual, previous]
			break
		previous = visual
	check.call(broken == "", "回転の見た目: rpsが減れば必ず遅くなる %s" % broken)

	# 初期値と瀕死で明確に差が出ること。差が無いと減っていくのが分からない。
	disc.rps = 15.0
	var fresh: float = disc.visual_rps()
	disc.rps = 1.0
	var dying: float = disc.visual_rps()
	check.call(
		fresh > dying * 2.0,
		"回転の見た目: 初期値(15)と瀕死(1)で倍以上の差 (%.2f vs %.2f)" % [fresh, dying]
	)


func _test_stopped(check: Callable, disc: Node2D) -> void:
	disc.rps = 0.0
	check.call(disc.visual_rps() == 0.0, "回転の見た目: rps=0なら止まる")
	disc.rps = -1.0
	check.call(disc.visual_rps() == 0.0, "回転の見た目: 負のrpsでも逆回転しない")
