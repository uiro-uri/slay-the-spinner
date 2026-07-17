# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリについて

「Slay the Spinner」— ベイブレード風のRPS(回転数)減衰バトル × Slay the Spire風の
分岐マップ × レアリティ付きパーツによるローグライク強化。

**2つの実装が同居している。**

- `godot/` — 本実装。ブラウザとSteam配信が最終目標。ここに書く。
- `archive/flask-prototype/` — ゲームデザインを検証済みの初期実装。**凍結。機能追加しない。**
  仕様リファレンスとして読み、挙動の突き合わせ（`simulation.py`を実行して基準
  トラジェクトリを出し、Godot版と数値比較する等）に使う。

実装はマイルストーン単位(M0〜M5)で進む。M1(スケルトン)まで完了。GDScriptの
コメントに `M2で導入` `M3でマップ画面へ遷移させる` のような形で次の作業箇所が
埋めてあるので、新機能を足すときはまず `grep -rn 'M[0-9]で' godot/` で拾う。

ドキュメント・コメント・コミットメッセージは日本語で書く。

## コマンド

Godotのバイナリ1つがエディタ(GUI)とヘッドレスCLIを兼ねる。`godot4` か `godot`。

```bash
scripts/verify.sh           # 全段階の検証。変更をコミットする前にこれを通す
scripts/verify.sh --quick   # 描画確認(5,6)を省略して速く回す

# 個別に回す場合
godot --headless --path godot --import                          # 生成物(.translation等)を作る
godot --headless --path godot --script res://tests/run_tests.gd # テストのみ
godot --headless --path godot --export-release "Web"            # 書き出し (Web/Linux/Windows)
(cd build/web && python3 -m http.server 8099)                   # -> http://localhost:8099/index.html
```

`GODOT_BIN` でバイナリのパス、`WEB_PORT` で確認用ポートを上書きできる。

## 検証の考え方 — 終了コードを信用しない

**このプロジェクトでは「exit 0」は成功を意味しない。** フォントと翻訳が焼き込まれて
いない壊れたWebビルドがexit 0で通り、実ブラウザで見るまで気付けなかった事故が
実際にあった。そのため `scripts/verify.sh` の各段階には実質的な判定基準が置いて
ある。判定基準を弱めたり、段階を飛ばしたりしないこと。

- **import は2回走らせ、2回目だけを見る。** 1回目は `project.godot` が参照する
  `.translation` とフォントがまだ無いので正当にエラーになる。
- **書き出しは pck のサイズ下限(8MB)で焼き漏れを捕まえる。** 正常なpckは約11MB
  (うちフォントが約6MB)、壊れたビルドは4.6MBだった。
- **描画は実際にフレームを出して色数を数える。** ネイティブは Movie Maker モード
  (`--write-movie`)でPNG連番を得るので外部ツールは不要。Webは Chromium(Playwright)で
  canvasを撮る。単色ならブランク＝失敗。結果は `build/verify/{native,web}.png` に残る
  ので、見た目は画像を見て確認する。

テスト側(`godot/tests/run_tests.gd`)も同じ理由で二重チェックしている。GDScriptの
実行時エラーは例外として捕捉できず**該当関数を黙って中断するだけ**なので、各テストは
最後に `_done()` を呼び、`EXPECTED_TESTS` と照合して完走を確認する。**テストを
追加したら `EXPECTED_TESTS` にも足すこと。**

## アーキテクチャ

- **`scenes/main/Main.gd` が画面のルーター。** Flask版のルーティング(`/`, `/map`,
  `/simulation`, `/reward`)に相当する。`goto_screen(PackedScene)` が `ScreenHolder` の
  子を差し替える。新しい画面は `scenes/<name>/` に置き、Mainから遷移させる。
- **`autoloads/GameState.gd` が1ラン分の状態を持つシングルトン。** Flask版のセッション
  相当。MVPでは永続化しない(メモリのみ)＝プロトタイプがサーバー再起動でセッションを
  失っていたのと同じ挙動。セーブ/再開は将来の課題。`reset_run()` で初期化する。
- `scripts/{core,data,util}/` と `resources/{parts,enemies,themes}/` は M2以降の置き場
  として空で用意してある。

## 踏み抜きやすい罠

- **エディタをsudo(root)で起動しない。** `godot/.godot/` がroot所有になり、以後は
  通常ユーザーでのインポート・書き出しが権限エラーで失敗する。`.import` が
  `valid=false` に書き換わり、フォントや翻訳が抜けた壊れたビルドが黙って出来上がる。
  やってしまったら `sudo rm -rf godot/.godot` で消せば再生成される。verify.shの
  段階0がこれを検出する。
- **日本語は必ず翻訳キー経由 + Noto Sans JP。** Godot標準フォントはCJKグリフを持たず
  豆腐(□)になるため `gui/theme/custom_font` に `assets/fonts/NotoSansJP-VF.otf` を
  指定してある。**この指定はpckサイズでは守れない**(フォントは `all_resources` で
  同梱されるので、指定を外しても容量が変わらない)ため、`run_tests.gd` の font テストが
  グリフの有無を直接見ている。
- 文言は `godot/translations/strings.csv` に `keys,en,ja` で足す。`.translation` は
  そこから決定的に再生成されるのでコミットしない(`.csv` と `.csv.import` はコミットする)。
  未定義キーはキー自身が返るので、訳抜けはテストで検出できる。
  なお `LANGUAGE_TOGGLE` の訳語は**意図的に反転**させてある(英語表示中は切り替え先の
  「日本語」と出したいため)。
- **書き出し先は `godot/` の外(リポジトリ直下の `build/`)。** `godot/` 配下に置くと
  Godotが `res://` として再スキャンし、書き出したPNG等をプロジェクトの資産として
  取り込んでしまう。`export_presets.cfg` の `export_path` が `../build/...` なのは
  このため。
- レンダラは `gl_compatibility` 固定(Web配信のため)。
