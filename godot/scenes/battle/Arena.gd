class_name Arena
extends Node2D

## 戦うすり鉢。既定は10x10ユニットの矩形で中心は(5,5)だが、setup()で土俵
## (フィールド)に合わせて壁の位置・形状・障害物を差し替えられる。
##
## 壁は物理ボディではなくデータ(ArenaWall)として持ち、当たり判定は
## SpinnerPhysics/BattleResolverが行う。ここは見た目だけを描く。

## Battle.tscn単体起動時とテストの既定値。フィールドが無いときのフォールバック。
const BOUNDS := Rect2(0.0, 0.0, 10.0, 10.0)

const WALL_WIDTH := 0.2
const WALL_COLOR := Palette.NEON_MAGENTA
const FLOOR_COLOR := Palette.FLOOR
const CENTER_MARK_COLOR := Palette.FLOOR_MARK
const OBSTACLE_COLOR := Palette.NEON_VIOLET
const OBSTACLE_HIGHLIGHT := Palette.NEON_VIOLET_HI

## 等高線を描く分割数。楕円でも滑らかに見える程度。
const _CONTOUR_SEGMENTS := 48

var _bounds: Rect2 = BOUNDS
var _wall_shape: ArenaWall.WallShape = ArenaWall.WallShape.RECT
var _obstacles: Array[Vector3] = []
var _stage_shape: SpinnerPhysics.StageShape = SpinnerPhysics.StageShape.DISH
var _stage_strength: float = 4.9

var walls: Array[ArenaWall] = ArenaWall.from_rect(BOUNDS)


## 土俵をフィールドに合わせて設定する。nullなら既定(矩形10x10)。傾斜(等高線)は
## フィールドがあればその値、無ければ引数のフォールバック(Battleの@export)を使う。
func setup(
	field: FieldData,
	fallback_shape: SpinnerPhysics.StageShape = SpinnerPhysics.StageShape.DISH,
	fallback_strength: float = 4.9
) -> void:
	if field != null:
		_bounds = field.arena_bounds
		_wall_shape = field.wall_shape
		_obstacles = field.obstacles
		_stage_shape = field.stage_shape
		_stage_strength = field.stage_strength
	else:
		_bounds = BOUNDS
		_wall_shape = ArenaWall.WallShape.RECT
		_obstacles = []
		_stage_shape = fallback_shape
		_stage_strength = fallback_strength
	walls = ArenaWall.build(_wall_shape, _bounds)
	queue_redraw()


func center() -> Vector2:
	return _bounds.get_center()


func _draw() -> void:
	# 床。矩形はそのまま、非矩形は多角形で塗る。
	if _wall_shape == ArenaWall.WallShape.RECT:
		draw_rect(_bounds, FLOOR_COLOR, true)
	else:
		draw_colored_polygon(ArenaWall.outline_points(_wall_shape, _bounds), FLOOR_COLOR)

	# 傾斜の等高線。等しい高さ間隔で引くので、急峻なほど本数が増え外周で密になる。
	# すり鉢の底の位置と急峻さが一目で読める。楕円ボウルでは同心楕円として描く。
	_draw_contours()

	# 壁の輪郭。矩形は枠線、非矩形は閉じた多角形。
	if _wall_shape == ArenaWall.WallShape.RECT:
		draw_rect(_bounds, WALL_COLOR, false, WALL_WIDTH)
	else:
		var pts := ArenaWall.outline_points(_wall_shape, _bounds)
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, WALL_COLOR, WALL_WIDTH)

	# 障害物は塗り円＋内側ハイライトで、盛り上がった柱に見せる。
	for o in _obstacles:
		var obstacle_center := Vector2(o.x, o.y)
		draw_circle(obstacle_center, o.z, OBSTACLE_COLOR)
		draw_circle(obstacle_center, o.z * 0.55, OBSTACLE_HIGHLIGHT)


## 傾斜の等高線を同心の円/楕円で描く。半径はStageContoursが等しい高さ間隔で決める。
func _draw_contours() -> void:
	# 描画用の半軸。楕円は縦横で違う半軸、それ以外は内接円半径の真円。
	var semi: Vector2
	if _wall_shape == ArenaWall.WallShape.ELLIPSE:
		semi = _bounds.size * 0.5
	else:
		var inr := ArenaWall.inradius_for(_wall_shape, _bounds)
		semi = Vector2(inr, inr)
	# 本数・高さは代表半径(半軸の相乗平均)で測る。円ならそのまま内接円半径。
	var rep_r := sqrt(semi.x * semi.y)
	var radii := StageContours.contour_radii(_stage_shape, _stage_strength, rep_r)
	for r in radii:
		var frac := r / rep_r
		_draw_ellipse_outline(center(), semi * frac, CENTER_MARK_COLOR, 0.03)


## 中心cの楕円(半軸semi)の輪郭を閉じた折れ線で描く。
func _draw_ellipse_outline(c: Vector2, semi: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(_CONTOUR_SEGMENTS + 1):
		var theta := float(i) / float(_CONTOUR_SEGMENTS) * TAU
		pts.append(c + Vector2(semi.x * cos(theta), semi.y * sin(theta)))
	draw_polyline(pts, color, width)
