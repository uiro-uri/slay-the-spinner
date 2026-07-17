class_name LaunchController
extends Node2D

## 引っ張って離すとコマが飛ぶ（スリングショット式）。
##
## プロトタイプはmousedown/mousemove/mouseupで初速を作り、フォームを
## サーバーへ送って全ステップを計算させていた。ここでは押している間に
## 狙いを描き、離した瞬間にその場で発射する。
##
## 座標はアリーナのユニット系。ArenaRootの子として置くこと。

## 引いた距離(ユニット)を初速(ユニット/秒)に変換する倍率。
@export_range(0.1, 20.0, 0.1) var pull_to_speed: float = 5.0

## これ以上引いても速くならない上限(ユニット)。
@export_range(0.5, 10.0, 0.1) var max_pull: float = 4.0

## 発射位置と速度が決まった。
signal launched(pos: Vector2, velocity: Vector2)

var _dragging: bool = false
var _origin: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _enabled: bool = true


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_dragging = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_origin = get_local_mouse_position()
			_current = _origin
			queue_redraw()
		elif _dragging:
			_dragging = false
			_release()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		_current = get_local_mouse_position()
		queue_redraw()


func _release() -> void:
	# 引いた向きと逆に飛ぶ（パチンコと同じ）。
	var pull := _origin - _current
	if pull.length() > max_pull:
		pull = pull.normalized() * max_pull
	queue_redraw()
	launched.emit(_origin, pull * pull_to_speed)


func _draw() -> void:
	if not _dragging:
		return

	var pull := _origin - _current
	if pull.length() > max_pull:
		pull = pull.normalized() * max_pull

	# 発射地点
	draw_circle(_origin, 0.12, Color(1, 1, 1, 0.8))
	# 飛んでいく向きと強さ
	var tip := _origin + pull
	draw_line(_origin, tip, Color(0.4, 1, 0.4, 0.9), 0.08)
	if pull.length() > 0.2:
		var dir := pull.normalized()
		var side := dir.orthogonal() * 0.18
		draw_colored_polygon(
			[tip + dir * 0.3, tip + side, tip - side], Color(0.4, 1, 0.4, 0.9)
		)
