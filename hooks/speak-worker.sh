#!/bin/bash
# 読み上げワーカー: $1 のテキストを AivisSpeech で合成・再生する
# speak-response.sh から起動され、新しい応答が来ると pkill で中断される
ENGINE_URL="http://127.0.0.1:10101"
ENGINE_BIN="$HOME/Applications/AivisSpeech-Engine/run"
# 話者スタイルID: まお/ノーマル=888753760 あまあま=888753762 からかい=888753764
#                コハク/ノーマル=1878365376 あまあま=1878365377
SPEAKER="${AIVIS_SPEAKER:-888753764}"

speech="$1"
[ -n "$speech" ] || exit 0

synth() {
  curl -s -m 30 -X POST "$ENGINE_URL/audio_query?speaker=$SPEAKER" \
    --get --data-urlencode "text=$1" \
  | curl -s -m 60 -X POST "$ENGINE_URL/synthesis?speaker=$SPEAKER" \
      -H "Content-Type: application/json" -d @- -o "$2"
}

if curl -s -m 2 "$ENGINE_URL/version" >/dev/null 2>&1; then
  play_pid=""
  # 文末(。！？)と改行で区切り、1文ずつ合成しながら順に再生する
  while IFS= read -r chunk; do
    [ -n "$chunk" ] || continue
    wav="$(mktemp -t claude-tts).wav"
    synth "$chunk" "$wav"
    [ -n "$play_pid" ] && wait "$play_pid"
    if [ -s "$wav" ]; then
      { afplay "$wav"; rm -f "$wav"; } &
      play_pid=$!
    else
      rm -f "$wav"
    fi
  done < <(printf '%s\n' "$speech" | sed -E 's/([。！？])/\1\n/g' | sed -E 's/^[[:space:]]+//' | grep -v '^[[:space:]]*$')
  [ -n "$play_pid" ] && wait "$play_pid"
else
  # エンジンを次回に備えて起動しつつ、今回は say で代替
  [ -x "$ENGINE_BIN" ] && nohup "$ENGINE_BIN" --host 127.0.0.1 --port 10101 >/dev/null 2>&1 &
  printf '%s' "$speech" | say -v Kyoko
fi
