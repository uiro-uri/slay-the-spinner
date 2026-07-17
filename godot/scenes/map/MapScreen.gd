extends Control

## 分岐マップの画面。今いるノードと、そこから進める先だけを押せる。
##
## プロトタイプはHTMLのtableとJinjaのforで矢印を1マスずつ組み立てていたが、
## ここは_draw()で線を引き、ノードだけをButtonとして置く。
##
## 見た目の演出(選択可能マスの明滅・マウスオーバー・現在地リング・入場フェード)は
## _process()で時刻を溜めて毎フレームqueue_redraw()する。演出の数式はテストできる
## よう MapGlow の純粋関数に切り出してある。

## 進める先が選ばれた。遷移先の判断はMainがする。
signal node_chosen(coord: Vector2i)

const CELL := Vector2(64.0, 62.0)

## 中央列(2)が画面中央に来る位置。設計解像度1280x720に合わせている。
## 段0からゴールの段9までがCELL.y間隔で並ぶので、上端はタイトル表示の下に置く。
const ORIGIN := Vector2(640.0, 80.0)
const NODE_RADIUS := 18.0

const COLOR_LINE := Palette.MAP_LINE
const COLOR_VISITED := Palette.MAP_VISITED
const COLOR_CURRENT := Palette.MAP_CURRENT
const COLOR_NEXT := Palette.MAP_NEXT
const COLOR_PLAIN := Palette.MAP_PLAIN

## 現在地から進める先へ伸びる線の強調色。COLOR_NEXTに寄せた明るい緑。
const COLOR_PATH := Palette.MAP_PATH
## 選択可能マスの背後に敷く淡いグロー。低アルファで、明滅で濃さが動く。
const COLOR_GLOW := Palette.MAP_GLOW
## マウスオーバー中のマスの輪郭。
const COLOR_HOVER_RING := Palette.MAP_HOVER_RING
## 現在地を示す常時リング。
const COLOR_CURRENT_RING := Palette.MAP_CURRENT_RING
## ノードの縁取り。
const COLOR_OUTLINE := Palette.MAP_OUTLINE

## グロー環が明滅で広がる最大の追加半径(px)。
const GLOW_EXTRA := 7.0
## グローのアルファの下限/上限。下限>0にして消え切らない「淡い明滅」にする。
const GLOW_ALPHA_MIN := 0.12
const GLOW_ALPHA_MAX := 0.4
## マウスオーバーでマスが膨らむ量(px)。
const HOVER_GROW := 3.0
## 入場フェードの長さ(秒)。
const ENTRANCE_DURATION := 0.35

## 選択不能を表す番兵。どのノード座標(段0〜9)とも一致しない。
const NO_HOVER := Vector2i(-1, -1)

var _tree: MapTree
var _buttons: Dictionary = {}

var _time := 0.0
var _entrance := 0.0
var _hovered_coord := NO_HOVER

@onready var _acquired_list: VBoxContainer = $AcquiredPanel/VBox/Scroll/List


func setup(tree: MapTree) -> void:
	_tree = tree
	_rebuild()
	_rebuild_acquired()


func _process(delta: float) -> void:
	# マップ画面のみ・描画も軽いので毎フレーム再描画で問題ない(battleも同様)。
	_time += delta
	_entrance += delta
	queue_redraw()


func _rebuild() -> void:
	for button in _buttons.values():
		button.queue_free()
	_buttons.clear()

	# 表示し直すたびに入場フェードとホバー状態をやり直す。
	_entrance = 0.0
	_hovered_coord = NO_HOVER

	if _tree == null:
		return

	var reachable := _tree.next_coords()
	for coord in _tree.nodes:
		var button := Button.new()
		button.size = Vector2(NODE_RADIUS, NODE_RADIUS) * 2.0
		button.position = _to_pixel(coord) - button.size * 0.5
		button.flat = true
		# ノードIDはメタ情報なので出さない（プロトタイプも同じ判断をしている）。
		button.text = ""

		var is_next: bool = coord in reachable
		button.disabled = not is_next
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if is_next else Control.CURSOR_ARROW
		)
		if is_next:
			button.pressed.connect(_on_node_pressed.bind(coord))
			# 選択可能マスだけホバーに反応させる。
			button.mouse_entered.connect(_on_node_hover.bind(coord))
			button.mouse_exited.connect(_on_node_unhover.bind(coord))
		add_child(button)
		_buttons[coord] = button

	queue_redraw()


func _on_node_pressed(coord: Vector2i) -> void:
	node_chosen.emit(coord)


func _on_node_hover(coord: Vector2i) -> void:
	_hovered_coord = coord


func _on_node_unhover(coord: Vector2i) -> void:
	# 別のマスへ移った直後の取りこぼしを避け、離れたのが今のマスの時だけ消す。
	if _hovered_coord == coord:
		_hovered_coord = NO_HOVER


## このランで取得済みのパーツ一覧を組み直す。集約はカタログの純関数に任せる。
func _rebuild_acquired() -> void:
	for child in _acquired_list.get_children():
		_acquired_list.remove_child(child)
		child.queue_free()

	var entries := CustomPartCatalog.aggregate_acquired(GameState.acquired_part_ids)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "MAP_NO_UPGRADES"  # キー＝自動翻訳
		_acquired_list.add_child(empty)
		return

	for entry in entries:
		_acquired_list.add_child(_build_row(entry["part"], entry["count"]))


## 取得済みパーツ1件分の行。報酬カード(RewardScreen._build_card)の縮約版。
## 選択ボタンや明滅はなく、名前＋効果を静的に見せるだけ。
func _build_row(part: CustomPart, count: int) -> Control:
	var is_rare := part.rarity == CustomPart.Rarity.RARE

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_rare:
		panel.add_theme_stylebox_override("panel", CustomPart.rare_stylebox())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title := Label.new()
	# 個数がある時だけ「×2」を付ける。1個ならキーのまま渡して自動翻訳に任せる。
	if count > 1:
		title.text = tr(part.title_key) + tr("PART_COUNT_SUFFIX").format([count])
	else:
		title.text = part.title_key
	title.add_theme_font_size_override("font_size", 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	# 説明文はパーツの実データから生成される（custom_part.gd:describe）ので嘘にならない。
	var text := Label.new()
	text.text = part.describe()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)

	if is_rare:
		# 金色の地は明るいので文字を暗くしないと読めない。報酬カードと同じ扱い。
		for label in [title, text]:
			label.add_theme_color_override("font_color", CustomPart.RARE_TEXT_COLOR)

	return panel


func _to_pixel(coord: Vector2i) -> Vector2:
	# 列は中央(2)を基準に左右へ振り分ける。
	return ORIGIN + Vector2((coord.y - 2) * CELL.x, coord.x * CELL.y)


## 入場フェードのアルファを掛けた色を返す。
func _faded(color: Color, e: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * e)


func _draw() -> void:
	if _tree == null:
		return

	var reachable := _tree.next_coords()
	var e := MapGlow.entrance(_entrance, ENTRANCE_DURATION)
	var g := MapGlow.pulse(_time)

	# --- 辺 ---
	for coord in _tree.nodes:
		var node: MapTree.MapNode = _tree.nodes[coord]
		var from := _to_pixel(coord)
		for target in node.targets():
			if not _tree.nodes.has(target):
				continue
			var to := _to_pixel(target)
			# ノードの縁から縁へ引く。
			var dir := (to - from).normalized()
			var a := from + dir * NODE_RADIUS
			var b := to - dir * NODE_RADIUS
			# 現在地から進める先の辺だけ、明るく太く・薄く明滅させて経路を強調する。
			if coord == _tree.current_coord and target in reachable:
				var path_color := COLOR_PATH
				path_color.a *= lerpf(0.7, 1.0, g)
				draw_line(a, b, _faded(path_color, e), 3.0, true)
			else:
				draw_line(a, b, _faded(COLOR_LINE, e), 2.0, true)

	# --- 選択可能マスのグロー(ノード本体の背後) ---
	for coord in reachable:
		var center := _to_pixel(coord)
		var glow := COLOR_GLOW
		glow.a = lerpf(GLOW_ALPHA_MIN, GLOW_ALPHA_MAX, g)
		draw_circle(center, NODE_RADIUS + GLOW_EXTRA * g, _faded(glow, e))

	# --- ノード本体 ---
	for coord in _tree.nodes:
		var center := _to_pixel(coord)
		var color := COLOR_PLAIN
		if coord == _tree.current_coord:
			color = COLOR_CURRENT
		elif coord in reachable:
			color = COLOR_NEXT
		elif coord.x < _tree.current_step():
			color = COLOR_VISITED

		var radius := NODE_RADIUS
		if coord == _hovered_coord:
			radius += HOVER_GROW

		draw_circle(center, radius, _faded(color, e))
		draw_arc(center, radius, 0, TAU, 32, _faded(COLOR_OUTLINE, e), 2.0, true)

		# マウスオーバー中のマスは明るい太リングで強調する。
		if coord == _hovered_coord:
			draw_arc(center, radius + 1.0, 0, TAU, 32, _faded(COLOR_HOVER_RING, e), 3.0, true)

	# --- 現在地マーカー(常時・明滅させない) ---
	if _tree.nodes.has(_tree.current_coord):
		var here := _to_pixel(_tree.current_coord)
		draw_arc(here, NODE_RADIUS + 4.0, 0, TAU, 40, _faded(COLOR_CURRENT_RING, e), 2.0, true)
