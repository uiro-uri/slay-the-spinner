class_name StageContours
extends RefCounted

## ステージの傾斜(急峻さ)を等高線で見せるための純関数。Nodeにもシーンにも依存せず、
## ヘッドレステストから直接呼べる。描画はArenaが行い、ここは半径の列だけ返す。
##
## 考え方: 傾斜は「中心が低いすり鉢」の高さ場 h(r) を持つ。等しい高さ間隔で輪郭を
## 引くと、
##  - 急峻なほど全高が高く、輪郭の本数が増える（＝密になる）。
##  - すり鉢の曲がり方が輪郭の詰まり方に出る（DISHは外周で詰まり、CONEは等間隔、
##    STEEPはさらに外周で密）。
## これで「急峻さ」と「傾斜の形」が一目で読める。
##
## 高さ場（係数はstrength、rは中心からの距離）:
##  - DISH : h = 0.5 * strength * r²   （加速度 ∝ r）    → 半径 ∝ f^(1/2)
##  - CONE : h = strength * r          （加速度 一定）   → 半径 ∝ f
##  - STEEP: h = strength * r³ / 3     （加速度 ∝ r²）   → 半径 ∝ f^(1/3)
## ここで f = k/n は「その輪郭の高さ ÷ 全高」。

## 輪郭の本数の下限・上限。多すぎると読めないのでクランプする。急峻さは本数に加えて
## 詰まり方でも伝わるので、上限で頭打ちでも急峻に見える。
const MIN_LINES := 3
const MAX_LINES := 7

## 本数を決める基準の高さ間隔。全高をこれで割った数が本数（クランプ前）。
## 小さいほど本数が増えやすい。標準すり鉢(strength≒4.9, max_r≒5)で数本になるよう調整。
const DEFAULT_HEIGHT_STEP := 12.0


## 等高さ間隔の輪郭半径を、中心に近い順で返す。max_r は最外周(縁)の半径。
## 楕円ボウルでは呼び出し側がこの半径を半軸比でスケールして同心楕円として描く。
static func contour_radii(
	shape: SpinnerPhysics.StageShape, strength: float, max_r: float,
	height_step: float = DEFAULT_HEIGHT_STEP
) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	if max_r <= 0.0 or strength <= 0.0 or height_step <= 0.0:
		return radii
	var total := _height_at(shape, strength, max_r)
	var n := clampi(int(floor(total / height_step)), MIN_LINES, MAX_LINES)
	var inv_power := 1.0 / _height_power(shape)
	for k in range(1, n + 1):
		var f := float(k) / float(n)
		radii.append(max_r * pow(f, inv_power))
	return radii


## 高さ場 h(max_r)。全高＝本数計算に使う。
static func _height_at(shape: SpinnerPhysics.StageShape, strength: float, r: float) -> float:
	match shape:
		SpinnerPhysics.StageShape.CONE:
			return strength * r
		SpinnerPhysics.StageShape.STEEP:
			return strength * pow(r, 3.0) / 3.0
		_:
			return 0.5 * strength * r * r


## 高さ場が r の何乗か。等高さ→半径の逆算の指数に使う。
static func _height_power(shape: SpinnerPhysics.StageShape) -> float:
	match shape:
		SpinnerPhysics.StageShape.CONE:
			return 1.0
		SpinnerPhysics.StageShape.STEEP:
			return 3.0
		_:
			return 2.0
