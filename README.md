# Claude Code 設定ファイル

[Claude Code](https://claude.com/claude-code) の個人設定を管理するリポジトリ。会話履歴・セッション・メモリなどの機密ファイルは `.gitignore` のホワイトリスト方式で除外し、設定ファイルのみを追跡している。

## 収録ファイル

| ファイル | 内容 |
|---|---|
| `CLAUDE.md` | 全プロジェクト共通の指示（応答スタイルなど） |
| `settings.json` | メイン設定（モデル・フック・音声・テーマなど） |
| `settings.local.json` | ローカルの権限許可リスト |
| `statusline-command.sh` | ステータスライン表示スクリプト |
| `hooks/` | Stopフックによる音声読み上げ環境（下記参照） |

## 音声会話環境

Claude Code と音声で会話するためのセットアップを含む。入力は組み込みの音声口述、出力（読み上げ）は Stop フック + ローカル TTS エンジン（AivisSpeech）で実現している。詳細は [`hooks/README.md`](hooks/README.md) を参照。

## セットアップ

このリポジトリは `~/.claude/` の内容そのもの。別マシンで使う場合は各ファイルを `~/.claude/` に配置する。音声読み上げには [AivisSpeech-Engine](https://github.com/Aivis-Project/AivisSpeech-Engine) の別途インストールが必要（[`hooks/README.md`](hooks/README.md) 参照）。
