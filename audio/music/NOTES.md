# Spirebreak: In-Match BGM, "Spire Rush"

Original chiptune-phonk battle loop by DJ for Tomoki R. It is synthesized entirely in Python/numpy: pulse, triangle and LFSR-noise
channels, with no samples, MIDI or soundfont.

| | |
|---|---|
| BPM | 150 (16th = 4,410 samples, bar = 70,560 samples @ 44.1 kHz) |
| Key | F minor, with phrygian ♭2 (G♭) colour in the cowbell riff |
| Meter / bars | 4/4, 56 bars |
| Loop length | 56 × 4 × 60 / 150 = **89.600 s** = **3,951,360 samples** @ 44.1 kHz (sample-exact in both WAV and decoded OGG) |
| Loudness | loop: max −2.4 dBFS (WAV) / −2.3 (OGG), mean −16.4 dB. Preview MP4: max −2.6, mean −16.5 |
| Preview | `match-bgm-preview.mp4`: 179.2 s (the loop ×2, so the seam is audible at 1:29.6), 2 s fade at the very end |

## Structure
| Bars | Time | Section | Chords | What's playing |
|---|---|---|---|---|
| 1–8 | 0:00 | A (main riff) | Fm Fm D♭ C ×2 | 808 cowbell riff, sliding triangle 808, kick/clap, 8th hats, crash on bar 1 |
| 9–16 | 0:12.8 | A2 | same | + 50%-pulse counter-line with long tones, plus echo |
| 17–24 | 0:25.6 | B (lead) | D♭ E♭ Fm Fm B♭m C D♭ C | cowbell rests; 25% pulse lead melody with slides/vibrato and a dotted-8th echo, 12.5% arps, 16th hats |
| 25–32 | 0:38.4 | A3 | Fm Fm D♭ C ×2 | riff returns with a low pulse double, triplet hats (phonk roll feel), arps, busier 808 slides |
| 33–40 | 0:51.2 | Breakdown | Fm · D♭ · B♭m · C (2 bars each) | no kick at first, half-time clap, pulse pad, long gliding 808, sparse cowbell. Bars 37–40 bring in a low-passed riff and a half-time kick |
| 41–44 | 1:04.0 | Build | Fm Fm D♭ C | 4-on-floor kick, snare roll 4ths→8ths→16ths→32nds, rising pulse/noise riser, climbing arps, 8th-note 808. Beat 4 of bar 44 drops out |
| 45–52 | 1:10.4 | Climax | B progression | crash, chord-following cowbell ostinato, lead melody whose second half climbs higher, open hats, extra kicks |
| 53–56 | 1:23.2 | Turnaround | Fm Fm D♭ C | main riff; bar 56 ends with a descending triangle-tom fill and snare flam back into bar 1 |

Energy curve for a 10-minute match: the hard-hitting sections alternate with a cowbell-free B section and a thinner
breakdown, so the riff isn't heard non-stop. About 6.7 passes play in 10 minutes.

## Instruments / channels
- **Cowbell riff**: 808-style cowbell made of two 50% pulse waves at f and f×1.48, with a fast two-stage decay, band-passed and with a light 1/8 echo.
- **808 bass**: 4-bit stepped NES triangle plus a quiet sine sub an octave down, tanh-saturated for phonk weight. It uses pitch slides (octave jumps and glides into the next chord).
- **Lead**: 25% pulse with delayed vibrato and slides, plus a dotted-8th ping-pong echo. **Counter**: 50% pulse. **Arps**: 12.5% pulse at 32nds.
- **Pad** (breakdown): 50% pulse triads, low-passed. **Riser**: 12.5% pulse sweep plus noise.
- **Drums**: kick is a sine pitch drop with an LFSR click. Clap is a triple-burst long-mode LFSR noise. Hats are short-mode (metallic 93-step) LFSR noise. Snare, crash and toms (triangle pitch drop) come from the same noise and triangle channels.
- **Master** (`render_match_bgm.sh`): two HPFs at 34 Hz, +1.5 dB at 120 Hz, −3 dB at 2.8 kHz and −1.5 dB at 4.2 kHz (these tame the square-wave bite on phone speakers), low-pass at 11 kHz/12.5 kHz, and a limiter at about −1.5 dBFS (peaks land near −2.4).

## Godot import
Use `match-bgm-loop.ogg` (already referenced by `data/match_config.tres`). **Enable Loop** in the Import dock with loop offset 0 and click
Reimport, or set `stream.loop = true` in code. Note: Godot's auto-generated `match-bgm-loop.ogg.import` currently says `loop=false`.
I didn't edit any project or import files.

## Seamless-loop method and check
`compose_match_bgm.py` renders the 56-bar loop 3× back to back, and the whole render is mastered as one continuous file. The script
keeps pass 2, which already contains the echo and reverb tails from pass 1 exactly as the repeating loop will. The last 2048 samples
are crossfaded into the audio just before the loop start. Checked on loop×2 in both the WAV and the **decoded OGG**: the seam
sample jump is 0.045 (WAV) / 0.050 (OGG), while the 99th percentile of neighbouring-sample differences is 0.053. Bar 1 opens with
a kick, so the jump at the seam is just the kick's attack. That attack peaks at 0.118 a few samples later, the same as kick downbeats
elsewhere in the loop (0.06–0.14). There is no click or gap.

## Files
- `match-bgm-loop.ogg`: **game asset** (Vorbis q6, 3,951,360 samples).
- `match-bgm-loop.wav`: the same loop as 16-bit PCM.
- `match-bgm-preview.mp4`: 1280×720 waveform video (H.264 yuv420p and AAC, faststart, about 12.4 MB) for listening in chat.
- `compose_match_bgm.py`: the composition and synth engine, which writes `_render_3x.f32`. `render_match_bgm.sh`: rebuilds every file (`MASTER_DB` env var sets the master gain, default −10.5).

## Originality
The style is inspired by hard phonk in the vein of STAKILLAZ ("S0N6F0RMYD34TH" was the energy reference): cowbell riffs, sliding
808s, punchy kick/clap, triplet hat rolls and dark minor-key menace, translated to chiptune. **No melody, riff, hook, bassline,
chord sequence or lyric from that song or any other existing piece was used.** The reference audio was not downloaded or transcribed.
Every riff and melody was newly written for Spirebreak, and there are no samples or vocals.
