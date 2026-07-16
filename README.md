# Slay the Spinner

ベイブレード風の回転数(RPS)減衰バトル × Slay the Spire風の分岐マップ ×
レアリティ付きロ―グライク強化パーツ、を組み合わせたゲームです。

ゲームデザインはFlaskで作った初期プロトタイプ（`archive/flask-prototype/`）
で検証済みです。ブラウザとSteam配信を最終目標に、実装を Godot で作り直して
います。本体は `godot/` 以下にあります。

## 開発環境

- [Godot 4.x](https://godotengine.org/download) をインストールしてください。
  同じバイナリがエディタ（GUI）とヘッドレスCLI（`godot --headless ...`）を
  兼ねています。
- `godot/project.godot` をGodotエディタで開いてください。
- **エディタをsudo（root）で起動しないでください。** インポートキャッシュ
  `godot/.godot/` がroot所有になり、以後は通常ユーザーでのインポート・
  書き出しが権限エラーで失敗するようになります（`.import`が`valid=false`に
  書き換わり、フォントや翻訳が焼き込まれない壊れたビルドができます）。
  そうなった場合は `sudo rm -rf godot/.godot` で消せば再生成されます。

## ディレクトリ構成

- `godot/` — Godotプロジェクト本体（このディレクトリを開く）
- `archive/flask-prototype/` — 検証済みゲームデザインの参考実装（凍結、
  機能追加はしない）。ローカル起動方法は同ディレクトリのREADME参照。

## ビルド/書き出し

書き出しプリセット（`godot/export_presets.cfg`）にWeb（ブラウザ）と
ネイティブ（Windows/Linux, 将来的にSteam向け）を定義しています。
成果物はリポジトリ直下の `build/` に出ます（gitignore済み）。

```bash
# 事前に一度インポートしておく（.translation等の生成物を作るため）
godot --headless --path godot --import

# 書き出し（出力先はexport_presets.cfgのexport_pathに従う）
mkdir -p build/web
godot --headless --path godot --export-release "Web"

# ローカルで確認
(cd build/web && python3 -m http.server 8099)
# -> http://localhost:8099/index.html
```

ヘッドレステスト:

```bash
godot --headless --path godot --script res://tests/run_tests.gd
```

## 実装の進め方

`docs/` はまだありませんが、実装ロードマップはマイルストーン単位
(M0〜M5)で進めています。詳細はプロジェクトの計画ドキュメントを参照して
ください。
