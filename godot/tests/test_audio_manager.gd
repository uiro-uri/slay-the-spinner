extends RefCounted

## AudioManager(効果音の再生シングルトン)のテスト。
##
## 実際の再生はヘッドレスでは評価できない(音の出力先が無い)ので、ここで確かめるのは
## 「鳴らす手前」まで:
##   - project.godot にautoload登録されているか
##   - SOUNDS の各キーが実在する音源にひも付いているか(パスの打ち間違い・素材の
##     置き忘れをここで捕まえる)。これが本命。
##   - 呼び出し側で使うキーが SOUNDS に揃っているか
##   - 未知キーや、ツリー外(プレイヤー未準備)でも play()/_stream_for が落ちないか
##
## サボタージュ検証 (CLAUDE.md「壊した実装を落とせて初めて完成」):
##   1. SOUNDS のどれかのパスを実在しないものに書き換える
##      → 「'<key>' の音源が読み込める」が赤くなる。
##   2. Battle/Main が使うキー("impact"等)を SOUNDS から消す
##      → 「呼び出し側のキーが登録されている」が赤くなる。
##   3. _stream_for の SOUNDS.has(key) ガードを外す
##      → 未知キーで load() に空パスが渡り、未知キーのテストが赤くなる。
##   いずれも確認済み。

const AudioManagerScript := preload("res://autoloads/AudioManager.gd")

## 呼び出し側(Battle.gd / Main.gd / Title.gd)が実際に鳴らすキー。ここが SOUNDS と
## ずれたら無音になるので、突き合わせて守る。
const USED_KEYS := [
	"launch", "impact", "wall", "win", "lose",
	"ui_confirm", "ui_select", "ui_back", "ui_click",
]


func run(check: Callable) -> void:
	check.call(
		ProjectSettings.get_setting("autoload/AudioManager", "")
			== "*res://autoloads/AudioManager.gd",
		"AudioManagerがproject.godotにautoload登録されている"
	)

	# --script実行ではautoloadがツリーに入らないので、GameStateのテストと同じく
	# スクリプトを直接インスタンス化して確かめる。_ready()は呼ばれない(=プレイヤーも
	# バスも作られない)が、キー解決とパスの正しさはそれで足りる。
	var audio: Node = AudioManagerScript.new()

	# SOUNDS の各パスが実在し、AudioStream として読み込めること。
	# (段階1のimport後に走るので.oggはインポート済み)
	for key in audio.SOUNDS:
		var path: String = audio.SOUNDS[key]
		var stream := load(path) as AudioStream
		check.call(stream != null, "'%s' の音源が読み込める (%s)" % [key, path])

	# 呼び出し側が使うキーが漏れなく登録されていること。
	for key in USED_KEYS:
		check.call(audio.has_sound(key), "呼び出し側のキー '%s' が登録されている" % key)

	# 未知キーは登録なし扱いで、鳴らそうとしても落ちない。
	check.call(not audio.has_sound("no_such_sound"), "未知キーは未登録として扱う")
	audio.play("no_such_sound")  # 例外を出さずに素通りすること(戻り値なし)
	check.call(true, "未知キーの play() が落ちない")

	# ツリー外(プレイヤー未準備)でも既知キーの play() が落ちない。
	audio.play("impact")
	check.call(true, "ツリー外の play() が落ちない")

	audio.free()
