class_name FieldData
extends Resource

## 1戦を戦う土俵(フィールド)。壁の位置・形状、傾斜、障害物をまとめる。
## EnemyDataと同じく、マップでノードを選んだ瞬間に FieldRosterが1つ選び、
## GameState.pending_field 経由でBattleへ渡す。
##
## 数値は手触りで調整する前提。すべて@exportでInspectorから触れる。

## フィールド名の翻訳キー。
@export var title_key: String = ""

## アリーナの矩形。中心と壁・傾斜の基準はここから決まる。
## 小さくすると狭い土俵、位置をずらすと非対称な土俵になる。
@export var arena_bounds: Rect2 = Rect2(0, 0, 10, 10)

## 外周の形。矩形/八角形/円形。
@export var wall_shape: ArenaWall.WallShape = ArenaWall.WallShape.RECT

## 傾斜の形。すり鉢(外側ほど急)か円錐(一定傾斜)か。
@export var stage_shape: SpinnerPhysics.StageShape = SpinnerPhysics.StageShape.DISH

## 傾斜の強さ。大きいほど中央へ強く戻される。
@export var stage_strength: float = 4.9

## 障害物。xy=中心(アリーナ座標)、z=半径。固定された円柱としてコマを弾く。
@export var obstacles: Array[Vector3] = []


static func make(
	title_key_: String, arena_bounds_: Rect2, wall_shape_: ArenaWall.WallShape,
	stage_shape_: SpinnerPhysics.StageShape, stage_strength_: float,
	obstacles_: Array[Vector3] = []
) -> FieldData:
	var data := FieldData.new()
	data.title_key = title_key_
	data.arena_bounds = arena_bounds_
	data.wall_shape = wall_shape_
	data.stage_shape = stage_shape_
	data.stage_strength = stage_strength_
	data.obstacles = obstacles_
	return data


## 壁の内接円半径。非矩形フィールドの発射クランプと敵の出現境界に使う。
func inradius() -> float:
	return ArenaWall.inradius_for(wall_shape, arena_bounds)


## アリーナの中心。
func center() -> Vector2:
	return arena_bounds.get_center()


## 楕円ボウルの傾斜ワープ用の半軸比。DISHの傾斜を成分ごとに 1/軸² で弱める。
func slope_axes() -> Vector2:
	return slope_axes_for(wall_shape, arena_bounds)


## wall_shape と bounds から傾斜ワープの半軸比を出す。ELLIPSE以外は円＝Vector2.ONE。
## 積=1に正規化して strength の意味を保つ: ax=√(w/h), ay=√(h/w)。横長(w>h)で
## x方向の戻しが弱くy方向が強い＝谷が横に伸びる。resolver とテストから共用する静的関数。
static func slope_axes_for(shape: ArenaWall.WallShape, bounds: Rect2) -> Vector2:
	if shape != ArenaWall.WallShape.ELLIPSE:
		return Vector2.ONE
	var w := bounds.size.x
	var h := bounds.size.y
	if w <= 0.0 or h <= 0.0:
		return Vector2.ONE
	return Vector2(sqrt(w / h), sqrt(h / w))
