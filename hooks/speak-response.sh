#!/bin/bash
# Claude Code の Stop フック: 最新のアシスタント応答を AivisSpeech で読み上げる
# 実際の合成・再生は speak-worker.sh に任せ、新しい応答が来たら
# 進行中の読み上げを中断して最新の応答だけを読み上げる

# フック入力の last_assistant_message に最新応答が入っている
# (transcript ファイルは書き込みが遅れることがあるため使わない)
last_text=$(jq -r '.last_assistant_message // empty')
[ -n "$last_text" ] || exit 0

# 同じ内容の二重読み上げを防止 (resume や clear でも Stop は発火するため)
state="$HOME/.claude/hooks/.speak-last-hash"
new_hash=$(printf '%s' "$last_text" | md5 -q)
[ "$new_hash" = "$(cat "$state" 2>/dev/null)" ] && exit 0
printf '%s' "$new_hash" > "$state"

# コードブロック・URLを除去し、長すぎる場合は先頭600文字のみ読み上げ
speech=$(printf '%s' "$last_text" | sed '/^```/,/^```/d' | sed -E 's#https?://[^ )]+##g' | head -c 600)
[ -n "$speech" ] || exit 0

# 進行中の読み上げを中断してから、最新の応答を読み上げる
pkill -f "hooks/speak-worker.sh" 2>/dev/null
pkill -f "afplay .*claude-tts" 2>/dev/null
pkill -f "say -v Kyoko" 2>/dev/null
nohup "$HOME/.claude/hooks/speak-worker.sh" "$speech" >/dev/null 2>&1 &

exit 0
