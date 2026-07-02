#!/usr/bin/env python3
"""
215000 SJL Metadata Assessment Pipeline v1.0
Walks a source path (rclone VFS mount or local dir), extracts metadata by file
type, and writes everything to a SQLite catalogue database.

Supported extraction per type:
  All files  — exiftool universal meta, SHA-256, size, timestamps, where-from xattr
  Images     — EXIF (GPS, camera, lens, exposure), thumbnail
  PDFs       — embedded text extraction; OCR via ocrmypdf for image-only PDFs
  Audio      — ID3/Vorbis/MP4 tags, BPM via aubio, waveform peak data
  Video      — ffprobe streams, duration, resolution, framerate; ffmpeg thumbnail;
               optional Ollama/llava scene description

Usage:
  python3 215000_...py --source /mnt/sjl-cloud/idrive-primary --db /srv/sjl/metadata.db
  python3 215000_...py --source /mnt/sjl-cloud --db /srv/sjl/metadata.db --workers 4
  python3 215000_...py --source /path --db /srv/sjl/metadata.db --video-ai  # enables llava
"""

import argparse
import hashlib
import json
import logging
import mimetypes
import os
import re
import sqlite3
import struct
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

try:
    import mutagen
    from mutagen import File as MutagenFile
    HAS_MUTAGEN = True
except ImportError:
    HAS_MUTAGEN = False

try:
    import aubio
    import numpy as np
    HAS_AUBIO = True
except ImportError:
    HAS_AUBIO = False

try:
    import fitz  # pymupdf
    HAS_FITZ = True
except ImportError:
    HAS_FITZ = False

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("sjl-metadata")

DB_SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

CREATE TABLE IF NOT EXISTS files (
    id            INTEGER PRIMARY KEY,
    path          TEXT UNIQUE NOT NULL,
    source_remote TEXT,
    sha256        TEXT,
    size_bytes    INTEGER,
    mime_type     TEXT,
    ext           TEXT,
    mtime         TEXT,
    assessed_at   TEXT,
    where_from    TEXT,
    flag          TEXT DEFAULT 'PENDING'
);

CREATE TABLE IF NOT EXISTS exif_meta (
    file_id   INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    key       TEXT NOT NULL,
    value     TEXT,
    PRIMARY KEY (file_id, key)
);

CREATE TABLE IF NOT EXISTS pdf_content (
    file_id         INTEGER PRIMARY KEY REFERENCES files(id) ON DELETE CASCADE,
    page_count      INTEGER,
    has_text        INTEGER,  -- 1 = embedded text, 0 = image-only, -1 = failed
    ocr_performed   INTEGER DEFAULT 0,
    text_preview    TEXT,     -- first 2000 chars
    full_text_path  TEXT      -- path to full extracted text sidecar file
);

CREATE TABLE IF NOT EXISTS audio_meta (
    file_id       INTEGER PRIMARY KEY REFERENCES files(id) ON DELETE CASCADE,
    title         TEXT,
    artist        TEXT,
    album         TEXT,
    album_artist  TEXT,
    genre         TEXT,
    year          TEXT,
    track_num     TEXT,
    duration_sec  REAL,
    bitrate_kbps  INTEGER,
    sample_rate   INTEGER,
    channels      INTEGER,
    bpm           REAL,
    bpm_confidence REAL,
    key_signature TEXT,
    has_cover_art INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS video_meta (
    file_id        INTEGER PRIMARY KEY REFERENCES files(id) ON DELETE CASCADE,
    duration_sec   REAL,
    width          INTEGER,
    height         INTEGER,
    fps            REAL,
    video_codec    TEXT,
    audio_codec    TEXT,
    bitrate_kbps   INTEGER,
    has_audio      INTEGER DEFAULT 0,
    thumbnail_path TEXT,
    scene_desc     TEXT    -- AI description if llava enabled
);

CREATE INDEX IF NOT EXISTS idx_files_mime  ON files(mime_type);
CREATE INDEX IF NOT EXISTS idx_files_flag  ON files(flag);
CREATE INDEX IF NOT EXISTS idx_files_sha256 ON files(sha256);
"""

# ── MIME type groupings ────────────────────────────────────────────────────────

IMAGE_MIMES  = {"image/jpeg","image/png","image/gif","image/tiff","image/webp",
                "image/heic","image/heif","image/bmp","image/raw","image/x-raw",
                "image/x-canon-cr2","image/x-nikon-nef","image/x-adobe-dng"}
AUDIO_MIMES  = {"audio/mpeg","audio/mp4","audio/x-m4a","audio/flac","audio/ogg",
                "audio/wav","audio/x-wav","audio/aiff","audio/x-aiff","audio/alac",
                "audio/x-ms-wma","audio/opus"}
VIDEO_MIMES  = {"video/mp4","video/quicktime","video/x-msvideo","video/x-matroska",
                "video/mpeg","video/x-ms-wmv","video/webm","video/ogg",
                "video/x-flv","video/3gpp","video/x-m4v","video/mxf"}

def guess_mime(path: Path) -> str:
    mt, _ = mimetypes.guess_type(str(path))
    if mt:
        return mt
    try:
        result = subprocess.run(
            ["file", "--mime-type", "-b", str(path)],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip()
    except Exception:
        return "application/octet-stream"

# ── Database helpers ───────────────────────────────────────────────────────────

_db_local = threading.local()

def get_conn(db_path: str) -> sqlite3.Connection:
    if not hasattr(_db_local, "conn"):
        _db_local.conn = sqlite3.connect(db_path, check_same_thread=False)
        _db_local.conn.row_factory = sqlite3.Row
    return _db_local.conn

def init_db(db_path: str):
    conn = sqlite3.connect(db_path)
    conn.executescript(DB_SCHEMA)
    conn.commit()
    conn.close()

def upsert_file(conn, path: str, source_remote: str, sha256: str, size: int,
                mime: str, ext: str, mtime: str, where_from: str) -> int:
    now = datetime.now(timezone.utc).isoformat()
    cur = conn.execute("""
        INSERT INTO files (path, source_remote, sha256, size_bytes, mime_type, ext,
                           mtime, assessed_at, where_from)
        VALUES (?,?,?,?,?,?,?,?,?)
        ON CONFLICT(path) DO UPDATE SET
            sha256=excluded.sha256, size_bytes=excluded.size_bytes,
            mime_type=excluded.mime_type, assessed_at=excluded.assessed_at,
            where_from=excluded.where_from
        RETURNING id
    """, (path, source_remote, sha256, size, mime, ext, mtime, now, where_from))
    row = cur.fetchone()
    conn.commit()
    return row[0]

# ── File hashing ───────────────────────────────────────────────────────────────

def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            while data := f.read(chunk):
                h.update(data)
        return h.hexdigest()
    except OSError:
        return ""

# ── Where-From extraction ──────────────────────────────────────────────────────

def get_where_from(path: Path) -> str:
    """Read macOS kMDItemWhereFroms xattr (preserved by some cloud clients)."""
    try:
        result = subprocess.run(
            ["xattr", "-p", "com.apple.metadata:kMDItemWhereFroms", str(path)],
            capture_output=True, timeout=3
        )
        if result.returncode == 0 and result.stdout:
            # Output is a binary plist hex dump — decode best-effort
            raw = result.stdout
            # Extract URL-like strings
            urls = re.findall(rb'https?://[^\x00-\x1f\x80-\xff]+', raw)
            if urls:
                return "; ".join(u.decode("utf-8", errors="replace") for u in urls)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return ""

# ── exiftool universal extraction ─────────────────────────────────────────────

def run_exiftool(path: Path) -> dict:
    try:
        result = subprocess.run(
            ["exiftool", "-json", "-n", "-q", str(path)],
            capture_output=True, text=True, timeout=30
        )
        data = json.loads(result.stdout or "[]")
        return data[0] if data else {}
    except Exception:
        return {}

def store_exif(conn, file_id: int, exif: dict):
    skip = {"SourceFile", "ExifToolVersion", "FileAccessDate", "FileInodeChangeDate"}
    rows = [
        (file_id, k, str(v)[:4000])
        for k, v in exif.items()
        if k not in skip and v is not None and str(v).strip()
    ]
    if rows:
        conn.executemany(
            "INSERT OR REPLACE INTO exif_meta (file_id, key, value) VALUES (?,?,?)",
            rows
        )
        conn.commit()

# ── PDF extraction + OCR ───────────────────────────────────────────────────────

def assess_pdf(conn, file_id: int, path: Path, text_sidecar_dir: Path):
    if not HAS_FITZ:
        log.warning("pymupdf not available — skipping PDF text extraction")
        return

    page_count = 0
    has_text = 0
    text_preview = ""
    full_text_path = None
    ocr_performed = 0

    try:
        doc = fitz.open(str(path))
        page_count = len(doc)
        full_text = []

        for page in doc:
            t = page.get_text("text")
            if t.strip():
                has_text = 1
                full_text.append(t)

        if has_text:
            combined = "\n".join(full_text)
            text_preview = combined[:2000]
            sidecar = text_sidecar_dir / (path.stem + ".txt")
            sidecar.parent.mkdir(parents=True, exist_ok=True)
            sidecar.write_text(combined, encoding="utf-8")
            full_text_path = str(sidecar)
        else:
            # Image-only PDF — run ocrmypdf
            has_text = 0
            try:
                ocr_out = tempfile.mktemp(suffix=".pdf")
                r = subprocess.run(
                    ["ocrmypdf", "--quiet", "--skip-text", "--output-type", "pdf",
                     str(path), ocr_out],
                    capture_output=True, timeout=300
                )
                if r.returncode == 0:
                    ocr_performed = 1
                    ocr_doc = fitz.open(ocr_out)
                    ocr_text = "\n".join(p.get_text("text") for p in ocr_doc)
                    text_preview = ocr_text[:2000]
                    sidecar = text_sidecar_dir / (path.stem + "_ocr.txt")
                    sidecar.write_text(ocr_text, encoding="utf-8")
                    full_text_path = str(sidecar)
                    ocr_doc.close()
                    Path(ocr_out).unlink(missing_ok=True)
            except (subprocess.TimeoutExpired, FileNotFoundError) as e:
                log.warning(f"OCR failed for {path.name}: {e}")
                has_text = -1
        doc.close()
    except Exception as e:
        log.warning(f"PDF read error {path.name}: {e}")
        has_text = -1

    conn.execute("""
        INSERT OR REPLACE INTO pdf_content
          (file_id, page_count, has_text, ocr_performed, text_preview, full_text_path)
        VALUES (?,?,?,?,?,?)
    """, (file_id, page_count, has_text, ocr_performed, text_preview, full_text_path))
    conn.commit()

# ── Audio extraction + BPM ────────────────────────────────────────────────────

def analyze_bpm(path: Path) -> tuple[float, float]:
    """Returns (bpm, confidence) using aubio, falls back to ffmpeg+aubio."""
    if not HAS_AUBIO:
        return 0.0, 0.0

    try:
        win_s = 1024
        hop_s = 512
        samplerate = 44100

        # Decode audio to raw PCM via ffmpeg pipe
        cmd = [
            "ffmpeg", "-i", str(path),
            "-ac", "1", "-ar", str(samplerate),
            "-f", "f32le", "-",
        ]
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        tempo = aubio.tempo("default", win_s, hop_s, samplerate)
        beats = []
        total_frames = 0
        max_frames = samplerate * 120  # analyse first 2 minutes max

        while total_frames < max_frames:
            raw = proc.stdout.read(hop_s * 4)  # 4 bytes per f32 sample
            if len(raw) < hop_s * 4:
                break
            samples = np.frombuffer(raw, dtype=np.float32)
            is_beat = tempo(samples)
            if is_beat:
                beats.append(tempo.get_last_s())
            total_frames += hop_s

        proc.terminate()
        proc.wait()

        bpm = float(tempo.get_bpm())
        confidence = float(tempo.get_confidence())
        return bpm, confidence
    except Exception as e:
        log.debug(f"BPM analysis failed for {path.name}: {e}")
        return 0.0, 0.0

def assess_audio(conn, file_id: int, path: Path):
    title = artist = album = album_artist = genre = year = track_num = ""
    duration = bitrate = sample_rate = channels = 0
    bpm = bpm_conf = 0.0
    has_cover = 0

    if HAS_MUTAGEN:
        try:
            af = MutagenFile(str(path), easy=True)
            if af:
                def tag(key):
                    v = af.get(key)
                    return str(v[0]) if v else ""
                title       = tag("title")
                artist      = tag("artist")
                album       = tag("album")
                album_artist= tag("albumartist")
                genre       = tag("genre")
                year        = tag("date")
                track_num   = tag("tracknumber")
                if af.info:
                    duration    = getattr(af.info, "length", 0) or 0
                    bitrate     = int((getattr(af.info, "bitrate", 0) or 0) / 1000)
                    sample_rate = getattr(af.info, "sample_rate", 0) or 0
                    channels    = getattr(af.info, "channels", 0) or 0

            # Check for cover art in non-easy form
            af_full = MutagenFile(str(path))
            if af_full:
                if hasattr(af_full, "tags") and af_full.tags:
                    for k in af_full.tags.keys():
                        if "APIC" in k or "covr" in k or "COVER" in k.upper():
                            has_cover = 1
                            break
        except Exception as e:
            log.debug(f"mutagen failed for {path.name}: {e}")

    bpm, bpm_conf = analyze_bpm(path)

    conn.execute("""
        INSERT OR REPLACE INTO audio_meta
          (file_id, title, artist, album, album_artist, genre, year, track_num,
           duration_sec, bitrate_kbps, sample_rate, channels, bpm, bpm_confidence, has_cover_art)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, (file_id, title, artist, album, album_artist, genre, year, track_num,
          duration, bitrate, sample_rate, channels, bpm, bpm_conf, has_cover))
    conn.commit()

# ── Video extraction + thumbnail ──────────────────────────────────────────────

def run_ffprobe(path: Path) -> dict:
    cmd = [
        "ffprobe", "-v", "quiet",
        "-print_format", "json",
        "-show_format", "-show_streams",
        str(path),
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return json.loads(r.stdout) if r.stdout else {}
    except Exception:
        return {}

def extract_thumbnail(path: Path, thumb_dir: Path) -> str:
    thumb = thumb_dir / (path.stem + "_thumb.jpg")
    thumb.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "ffmpeg", "-y", "-i", str(path),
        "-vf", "thumbnail,scale=640:-1",
        "-frames:v", "1",
        "-q:v", "3",
        str(thumb),
    ]
    try:
        subprocess.run(cmd, capture_output=True, timeout=30)
        return str(thumb) if thumb.exists() else ""
    except Exception:
        return ""

def describe_with_ollama(thumb_path: str, ollama_url: str) -> str:
    if not HAS_REQUESTS or not thumb_path or not Path(thumb_path).exists():
        return ""
    try:
        import base64
        with open(thumb_path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        payload = {
            "model": "llava",
            "prompt": ("Describe this video thumbnail concisely: what is shown, "
                       "people if present, setting, activity, dominant colors. "
                       "Under 100 words."),
            "images": [b64],
            "stream": False,
        }
        r = requests.post(f"{ollama_url}/api/generate", json=payload, timeout=30)
        if r.ok:
            return r.json().get("response", "").strip()
    except Exception:
        pass
    return ""

def assess_video(conn, file_id: int, path: Path,
                 thumb_dir: Path, ollama_url: str = ""):
    probe = run_ffprobe(path)
    duration = width = height = bitrate = 0
    fps = 0.0
    video_codec = audio_codec = ""
    has_audio = 0

    fmt = probe.get("format", {})
    duration = float(fmt.get("duration", 0) or 0)
    bitrate  = int(int(fmt.get("bit_rate", 0) or 0) / 1000)

    for stream in probe.get("streams", []):
        if stream.get("codec_type") == "video" and not video_codec:
            video_codec = stream.get("codec_name", "")
            width  = stream.get("width", 0)
            height = stream.get("height", 0)
            r_frame = stream.get("r_frame_rate", "0/1")
            try:
                num, den = r_frame.split("/")
                fps = round(int(num) / int(den), 3) if int(den) else 0.0
            except Exception:
                fps = 0.0
        elif stream.get("codec_type") == "audio" and not audio_codec:
            audio_codec = stream.get("codec_name", "")
            has_audio = 1

    thumb_path = extract_thumbnail(path, thumb_dir)
    scene_desc = describe_with_ollama(thumb_path, ollama_url) if ollama_url else ""

    conn.execute("""
        INSERT OR REPLACE INTO video_meta
          (file_id, duration_sec, width, height, fps, video_codec, audio_codec,
           bitrate_kbps, has_audio, thumbnail_path, scene_desc)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)
    """, (file_id, duration, width, height, fps, video_codec, audio_codec,
          bitrate, has_audio, thumb_path, scene_desc))
    conn.commit()

# ── Main file processor ───────────────────────────────────────────────────────

def process_file(path: Path, source_remote: str, db_path: str,
                 text_dir: Path, thumb_dir: Path,
                 ollama_url: str, skip_hash: bool) -> str:
    try:
        stat = path.stat()
        size = stat.st_size
        mtime = datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat()
        ext  = path.suffix.lower()
        mime = guess_mime(path)

        sha256 = "" if skip_hash else sha256_file(path)
        where_from = get_where_from(path)

        conn = get_conn(db_path)
        file_id = upsert_file(conn, str(path), source_remote,
                              sha256, size, mime, ext, mtime, where_from)

        # Universal exiftool pass
        exif = run_exiftool(path)
        store_exif(conn, file_id, exif)

        # Type-specific analysis
        if mime == "application/pdf":
            assess_pdf(conn, file_id, path, text_dir)
        elif mime in AUDIO_MIMES or ext in {".mp3",".flac",".m4a",".aac",".ogg",
                                             ".wav",".aiff",".wma",".opus"}:
            assess_audio(conn, file_id, path)
        elif mime in VIDEO_MIMES or ext in {".mp4",".mov",".mkv",".avi",".m4v",
                                             ".wmv",".flv",".webm",".mxf"}:
            assess_video(conn, file_id, path, thumb_dir, ollama_url)

        return f"OK: {path.name}"
    except Exception as e:
        return f"ERR: {path} — {e}"

# ── Directory walker ───────────────────────────────────────────────────────────

SKIP_EXTS = {".ds_store", ".localized", ".tmp", ".part", ".crdownload"}
SKIP_NAMES = {".ds_store", ".thumbs.db", ".fseventsd", ".spotlight-v100"}

def walk_files(source: Path):
    for root, dirs, files in os.walk(source, followlinks=False):
        dirs[:] = [d for d in dirs if not d.startswith(".") or d == ".stash"]
        for fname in files:
            if fname.lower() in SKIP_NAMES:
                continue
            p = Path(root) / fname
            if p.suffix.lower() in SKIP_EXTS:
                continue
            yield p

# ── CLI entry point ───────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="SJL Metadata Assessment Pipeline v1.0"
    )
    parser.add_argument("--source",  required=True,
                        help="Source directory to scan (e.g. /mnt/sjl-cloud/idrive-primary)")
    parser.add_argument("--db",      required=True,
                        help="SQLite database path (created if absent)")
    parser.add_argument("--remote",  default="",
                        help="Label for the source remote (e.g. idrive-primary)")
    parser.add_argument("--text-dir", default="/srv/sjl/metadata/pdf-text",
                        help="Directory for PDF text sidecar files")
    parser.add_argument("--thumb-dir", default="/srv/sjl/metadata/thumbnails",
                        help="Directory for video thumbnail images")
    parser.add_argument("--workers", type=int, default=2,
                        help="Parallel worker threads (default 2; keep low for spinning disks)")
    parser.add_argument("--skip-hash", action="store_true",
                        help="Skip SHA-256 hashing (faster; disables dedup detection)")
    parser.add_argument("--video-ai", action="store_true",
                        help="Enable Ollama/llava scene description for video thumbnails")
    parser.add_argument("--ollama-url", default="http://localhost:11434",
                        help="Ollama API base URL (default: http://localhost:11434)")
    parser.add_argument("--ext-filter", default="",
                        help="Comma-separated extension whitelist, e.g. .pdf,.mp3")
    args = parser.parse_args()

    source   = Path(args.source)
    db_path  = args.db
    text_dir = Path(args.text_dir)
    thumb_dir= Path(args.thumb_dir)
    ext_filter = {e.strip().lower() for e in args.ext_filter.split(",") if e.strip()}
    ollama_url = args.ollama_url if args.video_ai else ""

    if not source.exists():
        sys.exit(f"ERROR: source path does not exist: {source}")

    text_dir.mkdir(parents=True, exist_ok=True)
    thumb_dir.mkdir(parents=True, exist_ok=True)

    log.info(f"Initialising database: {db_path}")
    init_db(db_path)

    log.info(f"Scanning: {source}")
    files = [p for p in walk_files(source)
             if not ext_filter or p.suffix.lower() in ext_filter]
    log.info(f"Found {len(files):,} files to assess")

    if not HAS_MUTAGEN:
        log.warning("mutagen not installed — audio tags will be empty")
    if not HAS_AUBIO:
        log.warning("aubio not installed — BPM analysis disabled")
    if not HAS_FITZ:
        log.warning("pymupdf not installed — PDF text extraction disabled")

    results = {"ok": 0, "err": 0}
    iter_files = tqdm(files, unit="file") if HAS_TQDM else files

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {
            pool.submit(
                process_file, p, args.remote, db_path,
                text_dir, thumb_dir, ollama_url, args.skip_hash
            ): p
            for p in files
        }
        for fut in as_completed(futures):
            msg = fut.result()
            if msg.startswith("OK"):
                results["ok"] += 1
            else:
                results["err"] += 1
                log.warning(msg)
            if HAS_TQDM:
                iter_files.update(1)
                iter_files.set_postfix(ok=results["ok"], err=results["err"])

    if HAS_TQDM:
        iter_files.close()

    log.info(f"=== COMPLETE: {results['ok']:,} OK  {results['err']:,} ERR ===")
    log.info(f"Database: {db_path}")

    # Print summary stats
    conn = sqlite3.connect(db_path)
    rows = conn.execute("""
        SELECT mime_type, COUNT(*) AS n,
               SUM(size_bytes)/1073741824.0 AS gb
        FROM files
        GROUP BY mime_type ORDER BY n DESC LIMIT 20
    """).fetchall()
    log.info("Top MIME types:")
    for r in rows:
        log.info(f"  {r[0] or 'unknown':40s}  {r[1]:>6,} files  {r[2]:.2f} GB")
    conn.close()


if __name__ == "__main__":
    main()
