"""Prepare the credited music assets from downloaded creator MP3s.

Development dependencies: numpy, soundfile, imageio-ffmpeg.
Usage: python tools/prepare_music.py --source build/audio_sources --output assets/audio
The original files and temporary PCM remain in ignored build/audio_sources.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import quote

import imageio_ffmpeg
import numpy as np
import soundfile as sf


TRACKS = {
    "dungeon_theme": ("darkest_child.mp3", "Darkest Child", "USUAN1100783"),
    "raid_theme": ("darkest_child_var_a.mp3", "Darkest Child var A", "USUAN1100784"),
}


def measure(ffmpeg, path):
    result = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", str(path), "-af",
         "loudnorm=I=-23:TP=-5:LRA=9:print_format=json", "-f", "null", "-"],
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, check=True,
    )
    return json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind("{"):])[0]


def prepare(source, output):
    output.mkdir(parents=True, exist_ok=True)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    manifest = []
    for stem, (filename, title, isrc) in TRACKS.items():
        original = source / filename
        samples, rate = sf.read(original, dtype="float32", always_2d=True)
        original_seconds = len(samples) / rate
        # Remove near-silence at file boundaries, preserving 100 ms of the tail.
        frame = max(1, rate // 100)
        count = len(samples) // frame
        rms = np.sqrt(np.mean(samples[:count * frame].reshape(count, frame, -1) ** 2, axis=(1, 2)))
        audible = np.flatnonzero(rms > 0.001)
        if not len(audible):
            raise ValueError(f"Silent source: {original}")
        start = max(0, int(audible[0] * frame) - rate // 10)
        end = min(len(samples), int((audible[-1] + 1) * frame) + rate // 10)
        samples = samples[start:end]
        overlap = round(3.0 * rate)
        if len(samples) <= overlap * 4:
            raise ValueError(f"Track too short for the loop: {original}")
        theta = np.linspace(0, np.pi / 2, overlap, dtype="float32")[:, None]
        seam = samples[-overlap:] * np.cos(theta) + samples[:overlap] * np.sin(theta)
        # The closing seam ends at the opening phrase's third second, followed
        # immediately by that phrase in the next repeat. No hard reset or silence.
        loop = np.concatenate((samples[overlap:-overlap], seam))
        pcm = source / f"{stem}_loop.wav"
        sf.write(pcm, loop, rate, subtype="PCM_24")
        first = measure(ffmpeg, pcm)
        normalization = (
            "loudnorm=I=-23:TP=-5:LRA=9:linear=true:"
            f"measured_I={first['input_i']}:measured_TP={first['input_tp']}:"
            f"measured_LRA={first['input_lra']}:measured_thresh={first['input_thresh']}:"
            f"offset={first['target_offset']}"
        )
        target = output / f"{stem}.ogg"
        subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(pcm),
             "-af", normalization, "-ar", "44100", "-c:a", "libvorbis", "-q:a", "3",
             "-metadata", f"title={title} (Goblin Grimoire loop)",
             "-metadata", "artist=Kevin MacLeod",
             "-metadata", "license=https://creativecommons.org/licenses/by/4.0/", str(target)],
            check=True,
        )
        final = measure(ffmpeg, target)
        decoded, decoded_rate = sf.read(target, dtype="float32", always_2d=True)
        peak = float(np.max(np.abs(decoded)))
        boundary_step = float(np.max(np.abs(decoded[0] - decoded[-1])))
        if peak > 0.64 or float(final["input_tp"]) > -3.8:
            raise ValueError(f"Insufficient crossfade headroom: {target}")
        row = {
            "file": target.name, "title": title, "artist": "Kevin MacLeod",
            "source_page": f"https://incompetech.com/music/royalty-free/index.html?isrc={isrc}",
            "source_url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/" + quote(title + ".mp3", safe=""),
            "license": "CC BY 4.0", "license_url": "https://creativecommons.org/licenses/by/4.0/",
            "changes": "Near-silence trimmed; three-second equal-power loop seam; loudness normalized; encoded as OGG Vorbis.",
            "source_seconds": round(original_seconds, 3),
            "loop_seconds": round(len(decoded) / decoded_rate, 3),
            "integrated_lufs": float(final["input_i"]), "true_peak_db": float(final["input_tp"]),
            "decoded_peak": round(peak, 6), "boundary_step": round(boundary_step, 6),
            "bytes": target.stat().st_size,
            "source_sha256": hashlib.sha256(original.read_bytes()).hexdigest(),
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        }
        manifest.append(row)
        print(json.dumps(row))
    (output / "track-info.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    prepare(args.source, args.output)
