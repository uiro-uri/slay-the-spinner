class_name Disc
extends Node2D

## コマ1体。座標も半径もアリーナのユニット系で、表示上の拡大は親のArenaRootの
## scaleが担う（1ユニット = ARENA_PIXELS_PER_UNIT ピクセル）。
##
## 物理の計算そのものはSpinnerPhysicsの純粋関数が持ち、Battleが駆動する。
## このノードは状態の保持と描画だけを受け持つ。

## 破線リングの本数。模様はTAU/DASH_COUNTごとに繰り返す。
const DASH_COUNT := 8

## リングの太さ（ユニット）。
const RING_WIDTH := 0.16

@export var stats: SpinnerStats
@export var body_color: Color = Color("3498db")

@export_group("回転の見た目")

## 見た目の回転速度の上限(rps)。
##
## 破線がDASH_COUNT本だと模様はTAU/DASH_COUNT周期で繰り返すので、1フレームで
## その半分より速く回すと、止まって見えたり逆回転して見えたりする(標本化定理)。
## 60fps・8本なら 60/8/2 = 3.75rps が限界。
##
## 実際、rps(初期値15)をそのまま見た目に使っていた頃は 15/60回転=90°/frame
## となり、模様のちょうど2周期分で完全に静止して見えていた。しかもrps=40と
## rps=5が同じ見え方になり、実速度と見た目が対応していなかった。
##
## 60fps未満に落ちると限界も下がるので、3.75より控えめにしてある。
@export_range(0.5, 8.0, 0.25) var max_visual_rps: float = 3.0

## 見た目を決めるときの物理rpsの想定上限。SpinnerStatsのrps上限に合わせる。
@export_range(1.0, 100.0, 1.0) var reference_rps: float = 40.0

var velocity: Vector2 = Vector2.ZERO

## 現在の回転数。尽きた方が負け。stats.rpsは初期値としてだけ使う。
var rps: float = 0.0

## 決着後に色を落とすためのフラグ。
var defeated: bool = false


func _ready() -> void:
	if stats == null:
		stats = SpinnerStats.new()
	reset_spin()


## statsの初期値から回転をやり直す。
func reset_spin() -> void:
	rps = stats.rps
	defeated = false
	queue_redraw()


func _process(delta: float) -> void:
	rotation += visual_rps() * TAU * delta
	queue_redraw()


## 画面上で実際に回す速さ。物理のrpsそのままではない。
##
## 実物のコマが毎秒15〜40回転していれば人の目にはただのブレで、そもそも
## 回転を数えられない。ここで欲しいのは「実速度の再現」ではなく
## 「速いか遅いかが読めること」なので、破綻しない範囲に圧縮して写す。
##
## 平方根なのは、線形だと低RPS側がほぼ止まって見えて瀕死かどうかが読めない
## ため。RPSは体力そのものなので、低い側の差が見える方が大事。
func visual_rps() -> float:
	if rps <= 0.0:
		return 0.0
	var ratio := clampf(rps / reference_rps, 0.0, 1.0)
	return max_visual_rps * sqrt(ratio)


func _draw() -> void:
	var radius := stats.radius
	var fill := body_color
	if defeated:
		fill = fill.darkened(0.7)
	draw_circle(Vector2.ZERO, radius, fill)

	# 破線のリング。無地の円だと回転しているのか分からないため。
	var ring_color := Color(1, 1, 1, 0.7)
	if defeated:
		ring_color.a = 0.25
	var arc_span := TAU / (DASH_COUNT * 2)
	for i in DASH_COUNT:
		var start := arc_span * 2 * i
		draw_arc(Vector2.ZERO, radius, start, start + arc_span, 6, ring_color, RING_WIDTH)
