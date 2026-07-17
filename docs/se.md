# 効果音 (SE) の実装方針

このドキュメントの対象は効果音（SE）のみ。BGMは扱わない。

## 現状

AudioManager（`godot/autoloads/AudioManager.gd`）を入れ、主要なフックにSEを結んだ。
音源はKenneyのCC0素材（`godot/assets/audio/se/`、`LICENSE-Kenney.txt`）。

| 項目 | 状態 |
|---|---|
| オーディオバス | `SE` バスをAudioManager起動時に作成（Masterへ送る） |
| 再生シングルトン | `AudioManager`（autoload登録済み） |
| 素材 (ogg) | Kenney CC0を取得済み。各フックに候補を配置 |
| 配線 | 発射・衝突・壁バウンド・勝敗・主要UIに接続済み |

音の**最終選定は耳で決める**段階に残してある（後述）。

## AudioManagerの形

`godot/autoloads/AudioManager.gd`、`extends Node`、`GameState` と同じ方式で
`project.godot` の `[autoload]` に登録している。

- 呼び出し側はキーで鳴らすだけ: `AudioManager.play("launch")`。ファイルパスもバス構成も
  AudioManagerに閉じ、呼び出し側は音源の在り処を知らない。
- キー → 音源は `SOUNDS` 定数の表。候補が複数あるフックも既定を1つ選んである。
  差し替えはこの表を書き換えるだけで、呼び出し側は無変更。
- 同時発音は `AudioStreamPlayer` を8個プールしてラウンドロビン。乱戦で衝突音が
  連続しても頭を切られない。
- ブラウザ・ネイティブ・ヘッドレステストを同じコードベースで走らせる以上、SEの
  呼び出しはすべてAudioManager経由にして、キー欠落・ロード失敗・ツリー外の呼び出しは
  ここで握りつぶす（"鳴らないだけ"で落ちない）。

```gdscript
# 悪い例: ヘッドレステストでstreamが無い/読み込めない場合に落ちる可能性がある
$SFXPlayer.stream = preload("res://assets/audio/se/launch/scratch_001.ogg")
$SFXPlayer.play()

# 良い例
AudioManager.play("launch")
```

## 結んだフック

戦闘は「発射時に最後まで計算し、あとは再生するだけ」の構成（`battle_resolver.gd` /
`Battle.gd`）。衝突・壁バウンドは計算中に起きた事象を**再生時刻が追いついたところで**
描画する作りになっており、その衝撃波を出す箇所（`_spawn_spark` / `_spawn_wall_spark`）が
そのままSEの発火点になる。当初「Battle.gdにsignalを足すか」を検討していたが、この
再生機構が既に事象ごとの発火点を持っているため**signalの追加は不要**だった。

| フック | 鳴らす場所 | キー |
|---|---|---|
| 発射音 | `Battle._begin()` | `launch` |
| 衝突音 | `Battle._spawn_spark()`（コマ同士の衝撃波と同時） | `impact` |
| 壁バウンド音 | `Battle._spawn_wall_spark()` | `wall` |
| 勝ち | `Battle._finish()` PLAYER_WIN | `win` |
| 負け・引き分け | `Battle._finish()` LOSE/DRAW | `lose` |
| 開始・ノード選択・コンティニュー | `Main` の各ハンドラ | `ui_confirm` |
| 報酬選択 | `Main._on_part_chosen()` | `ui_select` |
| あきらめる | `Main._on_give_up_requested()` | `ui_back` |
| 言語切替 | `Title._on_language_pressed()` | `ui_click` |

UIは原則 `Main`（全画面遷移が集まるハブ）の決定的操作にだけ結んだ。言語切替だけは
`Main` を経由しない画面内操作なので `Title` で直接鳴らしている。ボタン1つ1つに細かく
割り振ることはしていない。

## 音量・ピッチのばらつき（発展）

衝突の大きさ（`spin_drain`/`spin_kick` に相当）に応じてSEの音量・ピッチを変える案は
未着手。今は衝突ごとに同じ `impact` を鳴らしている。乱戦では発音が密になるので、
間引きや強弱づけはフィーリングを見てから入れる。発展扱い。

## 音源の選定について

`SOUNDS` の既定は各フックにつき1つを機械的に選んだもの。特に次の2つは**耳で決め直す**
前提で置いてある:

- **発射音**: Kenneyに専用のwhooshが無く、`ui` の `scratch` を暫定placeholderにしている。
  専用の発射音が欲しければ差し替える。
- **勝敗ジングル**: `result/` の各ジングルはファイル名から勝ち/負けを判別できない
  （Kenneyは楽器種別分類）。既定は仮に `win`/`lose` を割り当てただけなので、実際に
  鳴らして入れ替える。

いずれも `SOUNDS` の表を書き換えるだけで済む。`assets/audio/se/` には候補を複数
残してある。

## 多言語対応について

SEはテキストを持たないため、`translations/strings.csv` によるJA/EN翻訳の対象外。

## 環境ごとの違いで気をつけること

| | ブラウザ | ネイティブ | ヘッドレステスト |
|---|---|---|---|
| 音声出力 | Web Audio API経由。初回のユーザー操作までは再生がブロックされることがある | OSの音声デバイスに直接出力 | `AudioServer` はあるが出力先が無い。呼び出しても落ちないことだけが要件（テスト済み） |
| 対応フォーマット | `.ogg` 推奨（wasmビルドの制約）。素材は全て `.ogg` | wav/ogg どちらでも問題ない | 再生自体は評価されないため影響なし |
| 初回ロード | 音声アセットもwasm/pckの初回ダウンロードに乗る | なし | 対象外 |

ブラウザは初回のユーザー操作までは音が鳴らないことがあるが、最初の入力（タイトルの
ボタン等）以降は問題ない。
