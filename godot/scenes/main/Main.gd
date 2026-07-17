extends Node

## 画面切り替えのルート。Flask版のルーティング（/, /map, /simulation, /reward）に相当する。
## 各画面はScreenHolderの子として差し替える。

const TITLE_SCENE: PackedScene = preload("res://scenes/title/Title.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/Battle.tscn")

@onready var _screen_holder: Node = $ScreenHolder


func _ready() -> void:
	goto_title()


func goto_title() -> void:
	var title := _swap_screen(TITLE_SCENE)
	title.start_requested.connect(goto_battle)


## M3でマップ画面を挟み、選ばれた敵を渡すようにする。今は直接戦闘へ入る。
func goto_battle() -> void:
	var battle := _swap_screen(BATTLE_SCENE)
	battle.finished.connect(_on_battle_finished)


## M4で勝利時は報酬画面へ、敗北時はゲームオーバーへ分岐させる。
func _on_battle_finished(_player_won: bool) -> void:
	goto_title()


func _swap_screen(scene: PackedScene) -> Node:
	for child in _screen_holder.get_children():
		_screen_holder.remove_child(child)
		child.queue_free()
	var screen := scene.instantiate()
	_screen_holder.add_child(screen)
	return screen
