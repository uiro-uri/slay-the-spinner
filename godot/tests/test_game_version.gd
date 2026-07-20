extends RefCounted

## game_version.gd のテスト。バージョン表示の書式と、project.godot との同期を固定する。
##
## バージョン番号の単一情報源は project.godot の application/config/version。
## 画面(タイトル/クリア/ゲームオーバー)の隅表示がその設定値とズレないことを機械的に押さえる。


func run(check: Callable) -> void:
	_test_format(check)
	_test_display_matches_project_setting(check)


## 整形は先頭に v を付けるだけの純関数。値に依らず書式を固定する。
func _test_format(check: Callable) -> void:
	check.call(GameVersion.format("0.0.0") == "v0.0.0", "format: '0.0.0' -> 'v%s'" % GameVersion.format("0.0.0").substr(1))
	check.call(GameVersion.format("1.2.3") == "v1.2.3", "format: '1.2.3' -> '%s'" % GameVersion.format("1.2.3"))
	check.call(GameVersion.format("10.20.30") == "v10.20.30", "format: 多桁でも先頭にvを1つだけ付ける")


## display() は project.godot の config/version を読んで整形する。
## 設定を書き換えたら表示も追従すること＝両者の同期を固定する。
func _test_display_matches_project_setting(check: Callable) -> void:
	var setting: String = str(ProjectSettings.get_setting("application/config/version", ""))
	check.call(setting != "", "project.godot に application/config/version が設定されている")
	check.call(
		GameVersion.display() == "v" + setting,
		"display() が config/version と一致する ('%s' vs 'v%s')" % [GameVersion.display(), setting]
	)
	check.call(GameVersion.display().begins_with("v"), "display() は 'v' 始まり")
