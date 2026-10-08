# Match music

**`match-bgm-loop.ogg`** — looping match BGM (Ogg Vorbis). Plays on the Music bus during matches.
Loop is enabled at runtime; the web export also forces native looping via a `head_include` script.

Source / scratch files (`.wav`, `.mp4`, `.f32`, render scripts) are gitignored — only the `.ogg` ships.
Re-render with `./render_match_bgm.sh` (see `NOTES.md` and `compose_match_bgm.py`).
