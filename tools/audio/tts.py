# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.5.3", "scipy==1.18.1"]
# ///
"""Render the PA lines (sounds/pa.py LINES) with Windows text-to-speech into sources/tts/<voice>_<id>.wav.

    uv run tools/audio/tts.py            # every voice and line; Windows only (System.Speech through PowerShell)

The WAVs are committed like any recording, so export.py never needs a speech engine. Re-run only when a line's
text or a voice changes. Stand-in voice until a recorded read replaces it (designer, 2026-10-18).
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sounds.pa import LINES, VOICES  # noqa: E402

OUT = Path(__file__).resolve().parent / "sources" / "tts"


def main():
    OUT.mkdir(exist_ok=True)
    script = ["Add-Type -AssemblyName System.Speech",
              "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer",
              "$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(44100, 'Sixteen', 'Mono')"]
    for key, (name, rate) in VOICES.items():
        script += [f"$s.SelectVoice('{name}')", f"$s.Rate = {rate}"]
        for pid, (text, _) in LINES.items():
            path = str(OUT / f"{key}_{pid}.wav").replace("'", "''")
            script += [f"$s.SetOutputToWaveFile('{path}', $f)", f"$s.Speak('{text.replace(chr(39), chr(39) * 2)}')"]
    script.append("$s.SetOutputToNull()")
    subprocess.run(["powershell", "-NoProfile", "-Command", "; ".join(script)], check=True)
    print(f"wrote {len(VOICES) * len(LINES)} files to {OUT}")


if __name__ == "__main__":
    main()
