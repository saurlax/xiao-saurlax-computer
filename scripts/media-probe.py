"""Offline media smoke test: crossfade, Chinese ASS subtitles, H.264/AAC, and frame extraction."""

import json
import os
import subprocess
import tempfile
from pathlib import Path


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, timeout=45).stdout


assert os.getuid() == 1000 and os.getgid() == 1000
font = run("fc-match", "-f", "%{file}", "Noto Sans CJK SC").decode().strip()
assert Path(font).is_file() and "CJK" in font, font
with tempfile.TemporaryDirectory(prefix="media-probe-") as directory:
    root = Path(directory)
    subtitles = root / "captions.ass"
    subtitles.write_text(
        "[Script Info]\nScriptType: v4.00+\nPlayResX: 320\nPlayResY: 180\n"
        "[V4+ Styles]\n"
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
        "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, "
        "Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n"
        "Style: Default,Noto Sans CJK SC,24,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,"
        "0,0,0,0,100,100,0,0,1,1,0,2,5,5,12,1\n"
        "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
        "Dialogue: 0,0:00:00.00,0:00:01.80,Default,,0,0,0,,中文剪辑测试\n",
        encoding="utf-8",
    )
    video = root / "edited.mp4"
    run(
        "ffmpeg",
        "-hide_banner",
        "-v",
        "error",
        "-y",
        "-filter_complex_threads",
        "1",
        "-f",
        "lavfi",
        "-i",
        "color=c=blue:s=320x180:r=10:d=1",
        "-f",
        "lavfi",
        "-i",
        "color=c=red:s=320x180:r=10:d=1",
        "-f",
        "lavfi",
        "-i",
        "sine=frequency=440:sample_rate=24000:duration=1.8",
        "-filter_complex",
        f"[0:v][1:v]xfade=transition=fade:duration=0.2:offset=0.8,ass=filename={subtitles}[v]",
        "-map",
        "[v]",
        "-map",
        "2:a",
        "-t",
        "1.8",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-threads",
        "1",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-movflags",
        "+faststart",
        str(video),
    )
    metadata = json.loads(run("ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(video)))
    streams = {item["codec_type"]: item for item in metadata["streams"]}
    assert streams["video"]["codec_name"] == "h264" and streams["video"]["pix_fmt"] == "yuv420p"
    assert streams["audio"]["codec_name"] == "aac"
    assert 1.7 <= float(metadata["format"]["duration"]) <= 2.0
    frame = run(
        "ffmpeg",
        "-v",
        "error",
        "-ss",
        "0.2",
        "-i",
        str(video),
        "-frames:v",
        "1",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-",
    )
    # White subtitle pixels must be present over the otherwise blue background.
    assert sum(min(frame[i : i + 3]) > 200 for i in range(0, len(frame), 3)) > 30
    image = root / "frame.png"
    run("ffmpeg", "-v", "error", "-ss", "0.2", "-i", str(video), "-frames:v", "1", str(image))
    assert image.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")

print("UID 1000 FFmpeg/ffprobe, crossfade, Chinese subtitles, H.264/AAC and frame extraction passed")
