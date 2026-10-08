#!/usr/bin/env bash
# Rebuild every Spirebreak match-BGM deliverable from compose_match_bgm.py (box pipeline).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
PY=/workspace/music-venv/bin/python
T=$(mktemp -d)
N=3951360            # 56 bars x 4 beats x 60 / 150 BPM = 89.6 s @ 44.1 kHz
$PY compose_match_bgm.py
# Master the whole 3x render continuously (phone-friendly: HPF, tame 2-4 kHz squareness, LPF ~11 kHz)
EQ="highpass=f=34,highpass=f=34,equalizer=f=2800:t=q:w=1.0:g=-3,equalizer=f=4200:t=q:w=1.2:g=-1.5,equalizer=f=120:t=q:w=1:g=1.5,lowpass=f=11000,lowpass=f=12500"
LIM="volume=${MASTER_DB:--10.5}dB,alimiter=limit=0.84:attack=4:release=90:level=0:latency=1"
ffmpeg -loglevel error -y -f f32le -ar 44100 -ac 2 -i _render_3x.f32 -af "$EQ,$LIM" -f f32le -ac 2 $T/m3x.raw
# keep pass 2 (already carries pass-1 echo/reverb tails); crossfade last 2048 smp into the pre-roll
$PY - "$T" "$N" <<'PYEOF'
import sys, wave, numpy as np
T, N = sys.argv[1], int(sys.argv[2]); K = 2048
M = np.fromfile(f'{T}/m3x.raw', dtype=np.float32).reshape(-1, 2).astype(float)
L = M[N:2*N].copy(); w = (0.5 - 0.5*np.cos(np.pi*np.linspace(0, 1, K)))[:, None]
L[-K:] = L[-K:]*(1-w) + M[N-K:N]*w
o = wave.open('match-bgm-loop.wav', 'wb'); o.setnchannels(2); o.setsampwidth(2); o.setframerate(44100)
o.writeframes(np.clip(np.round(L*32767), -32768, 32767).astype('<i2').tobytes()); o.close()
# preview: loop x2 with a 2 s fade at the very end
P = np.concatenate([L, L]); f = int(2*44100); P[-f:] *= np.linspace(1, 0, f)[:, None]
o = wave.open(f'{T}/prev.wav', 'wb'); o.setnchannels(2); o.setsampwidth(2); o.setframerate(44100)
o.writeframes(np.clip(np.round(P*32767), -32768, 32767).astype('<i2').tobytes()); o.close()
PYEOF
ffmpeg -loglevel error -y -i match-bgm-loop.wav -c:a libvorbis -q:a 6 match-bgm-loop.ogg
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $T/prev.wav)
printf 'Spirebreak — Match BGM' > $T/title.txt
printf '"Spire Rush"  ·  150 BPM  ·  F minor  ·  chiptune phonk  ·  seamless 89.6 s loop (x2)' > $T/sub.txt
F1=/usr/share/fonts/truetype/sand-box/google/Fredoka/Fredoka-VariableFont_wdth,wght.ttf
F2=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
cat > $T/fg.txt <<FG
[0:a]asplit=2[a1][a2];
[a1]aformat=channel_layouts=mono,lowpass=f=300,lowpass=f=300,volume=4,showwaves=s=1200x300:mode=cline:rate=25:colors=0x6EC3FF:scale=sqrt:draw=full,format=rgba[w];
[1:v]drawtext=fontfile='$F1':textfile=$T/title.txt:fontcolor=0xF2F4FF:fontsize=68:x=(w-tw)/2:y=70:borderw=4:bordercolor=0x000000,
drawtext=fontfile='$F2':textfile=$T/sub.txt:fontcolor=0xF46E7E:fontsize=24:x=(w-tw)/2:y=170,
drawbox=x=0:y=640:w=640:h=16:color=0x4FA8F0@1:t=fill,drawbox=x=640:y=640:w=640:h=16:color=0xF0606F@1:t=fill[bg0];
color=c=0xF2F4FF:s=1280x8:r=25[pb];
[bg0][pb]overlay=x='-1280+1280*t/$D':y=620[bg];
[bg][w]overlay=x=40:y=270:shortest=1,format=yuv420p[v]
FG
ffmpeg -loglevel error -y -i $T/prev.wav -f lavfi -i "color=c=0x141a2e:s=1280x720:r=25" \
  -filter_complex_script $T/fg.txt -map "[v]" -map "[a2]" -c:v libx264 -preset slow -b:v 420k -pass 1 -passlogfile $T/x264 \
  -tune animation -pix_fmt yuv420p -an -f mp4 /dev/null
ffmpeg -loglevel error -y -i $T/prev.wav -f lavfi -i "color=c=0x141a2e:s=1280x720:r=25" \
  -filter_complex_script $T/fg.txt -map "[v]" -map "[a2]" -c:v libx264 -preset slow -b:v 420k -pass 2 -passlogfile $T/x264 \
  -tune animation -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart -shortest match-bgm-preview.mp4
rm -rf "$T" __pycache__ _render_3x.f32
echo done
