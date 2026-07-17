extends Node

## 効果音(SE)の再生を一手に引き受けるシングルトン。呼び出し側はキーで鳴らすだけで、
## ファイルパスもオーディオバスの構成もここに閉じる。方針は docs/se.md を参照。
##
## ブラウザ・ネイティブ・ヘッドレステストを同じコードベースで走らせる以上、SEの
## 呼び出しはすべてここを通す。音が実際に出ない環境(ヘッドレステスト)や、キーの
## 打ち間違い・ロード失敗があっても落ちないよう、ここで握りつぶす("鳴らないだけ")。
##
## 音源はKenneyのCC0素材(godot/assets/audio/、LICENSE-Kenney.txt)。各フックに複数の
## 候補を置いてあるが、既定として1つを SOUNDS で選ぶ。差し替えはこの表を書き換える
## だけで済み、呼び出し側は無変更。最終的にどの音にするかは実際に鳴らして耳で決める。

## SE専用のオーディオバス。将来BGMを足すときに音量を別々に絞れるよう、最初から
## Masterと分けておく(docs/se.md)。無ければ起動時に作る。
const SE_BUS := "SE"

## 同時発音数。乱戦で衝突音が連続しても頭を切られないよう、複数のプレイヤーを
## 使い回す(ラウンドロビン)。
const VOICE_COUNT := 8

## キー → 音源ファイル。呼び出し側はこのキーだけを知る。
## 候補が複数あるフックも、ここでは既定を1つに決める。
const SOUNDS := {
	"launch": "res://assets/audio/se/launch/scratch_001.ogg",
	"impact": "res://assets/audio/se/impact/impactMetal_heavy_000.ogg",
	"wall": "res://assets/audio/se/wall/impactWood_medium_000.ogg",
	"win": "res://assets/audio/se/result/jingles_NES00.ogg",
	"lose": "res://assets/audio/se/result/jingles_HIT00.ogg",
	"ui_confirm": "res://assets/audio/se/ui/confirmation_001.ogg",
	"ui_select": "res://assets/audio/se/ui/select_001.ogg",
	"ui_back": "res://assets/audio/se/ui/back_001.ogg",
	"ui_click": "res://assets/audio/se/ui/click_001.ogg",
}

## 使い回すプレイヤー群と、次に使う番号。
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0

## ロード済み音源のキャッシュ。ロードは初回だけ。失敗(null)もキャッシュして
## 毎回ロードし直さない。
var _cache: Dictionary = {}


func _ready() -> void:
	_ensure_se_bus()
	for _i in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = SE_BUS
		add_child(player)
		_players.append(player)


## SEバスが無ければ作ってMasterへ送る。ヘッドレスでもAudioServerは在るので、この
## 呼び出し自体は安全(音が出ないだけ)。既にあれば何もしない。
func _ensure_se_bus() -> void:
	if AudioServer.get_bus_index(SE_BUS) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, SE_BUS)
	AudioServer.set_bus_send(idx, "Master")


## キーで指定したSEを鳴らす。未知キー・ロード失敗・プレイヤー未準備(ツリー外)は
## すべて静かに無視する。ここが唯一の再生経路。
func play(key: String) -> void:
	var stream := _stream_for(key)
	if stream == null or _players.is_empty():
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()


## キーに対応する音源を返す。無ければnull。初回だけロードし、以後は使い回す。
func _stream_for(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	if SOUNDS.has(key):
		stream = load(SOUNDS[key]) as AudioStream
	_cache[key] = stream  # nullも入れて再試行を避ける
	return stream


## 指定キーが登録されているか。テストや呼び出し側の事前確認用。
func has_sound(key: String) -> bool:
	return SOUNDS.has(key)
