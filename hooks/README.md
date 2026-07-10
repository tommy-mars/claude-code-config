# Claude Code 音声会話環境

Claude Code と音声で会話するためのセットアップ。入力は組み込みの音声口述、出力（読み上げ）はこのディレクトリの Stop フックで実現している。

## 全体アーキテクチャ

```
【入力】 マイク → Claude Code 組み込みの /voice (tapモード)
【出力】 応答完了 → Stopフック → speak-response.sh → speak-worker.sh
                                       ↓
                     AivisSpeech-Engine (localhost:10101) で音声合成
                                       ↓
                             afplay で wav 再生
```

## 構成要素

### 音声入力（組み込み機能）

`~/.claude/settings.json`:

```json
"voice": { "enabled": true, "mode": "tap" }
```

- `Space` 1回で録音開始、もう1回で送信
- Claude.ai アカウントでのログインとマイク許可が必要

### 音声合成エンジン

- **AivisSpeech-Engine**（Style-Bert-VITS2 ベース、無料・ローカル動作）
- GUI 不要のエンジン単体版を `~/Applications/AivisSpeech-Engine/` に設置
  - 入手元: https://github.com/Aivis-Project/AivisSpeech-Engine/releases （macOS-arm64 の 7z を展開し `xattr -dr com.apple.quarantine` で quarantine 解除）
- 起動コマンド: `~/Applications/AivisSpeech-Engine/run --host 127.0.0.1 --port 10101`
- VOICEVOX 互換の HTTP API（`/audio_query` → `/synthesis`）を提供
- 死活確認: `curl http://127.0.0.1:10101/version`

### Stop フック（`~/.claude/settings.json`）

```json
"hooks": {
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/speak-response.sh",
          "async": true,
          "statusMessage": "応答を読み上げ中…"
        }
      ]
    }
  ]
}
```

### speak-response.sh（フック本体）

1. フック入力 JSON の `last_assistant_message` から最新応答の本文を取得
2. 前回読み上げた内容の md5 ハッシュ（`.speak-last-hash`）と比較し、同一ならスキップ（resume / clear でも Stop は発火するため）
3. コードブロック・URL を除去し、先頭 600 文字に切り詰め
4. 進行中の旧 worker と再生プロセスを `pkill` で中断
5. `speak-worker.sh` を nohup でバックグラウンド起動

### speak-worker.sh（合成・再生ワーカー）

- 文章を「。！？」と改行で文単位に分割し、1文ずつ合成
- **1文目を再生しながら裏で次の文を合成する**パイプライン方式（最初の音が出るまで約1秒）
- エンジンが落ちていたら: 自動起動をかけつつ、その回のみ `say -v Kyoko` で代替。次回から AivisSpeech に戻る

## 声の変更

`speak-worker.sh` の `SPEAKER` を書き換える（または環境変数 `AIVIS_SPEAKER` で上書き）。

| 話者 / スタイル | style_id |
|---|---|
| まお / ノーマル | 888753760 |
| まお / あまあま | 888753762 |
| まお / からかい | 888753764（現在の設定） |
| コハク / ノーマル | 1878365376 |
| コハク / あまあま | 1878365377 |

インストール済みの全スタイルは `curl -s http://127.0.0.1:10101/speakers | jq` で確認できる。
新しい音声モデル（.aivmx）は https://hub.aivis-project.com/ から入手可能。

## 設計上のポイント（ハマりどころ）

- **transcript ファイルは使わない**: フック発火時点では最新応答がまだ transcript(JSONL) に書き込まれていないことがあり、ファイル解析だと常に一つ前の応答を拾ってしまう。フック入力の `last_assistant_message` を直接使うことで解決
- **worker をプロセス分離**: 読み上げ中に新しい応答が来たら旧 worker を `pkill` して最新だけ読む、を実現するため
- **フックは `async: true`**: 読み上げが Claude Code の動作をブロックしないように

## トラブルシューティング

- 読み上げられない → `curl http://127.0.0.1:10101/version` でエンジン死活確認。落ちていれば次の応答時に自動起動される（起動に1〜2分。その間は Kyoko 代替）
- 読み上げを今すぐ止めたい → `pkill -f speak-worker.sh; killall afplay`
- フック自体が動かない → `/hooks` で登録状況を確認、`claude --debug` で実行ログを確認
