class_name GameVersion

## バージョン番号の単一情報源は project.godot の application/config/version。
## 画面表示に使う "vX.Y.Z" 形式の文字列をここで組み立てる。
## 既存の scripts/core/ と同じく Node 非依存の純静的関数にして、ヘッドレスでテストできる。

## project.godot の設定値を読み、表示用文字列に整える。
static func display() -> String:
	return format(str(ProjectSettings.get_setting("application/config/version", "0.0.0")))


## 先頭に v を付けるだけの純関数（設定読み取りと切り離してテスト可能にする）。
static func format(version: String) -> String:
	return "v" + version
