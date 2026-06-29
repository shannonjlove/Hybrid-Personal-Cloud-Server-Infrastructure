#!/usr/bin/env python3
"""
SJL Sovereign Cloud v8.0 — System Infographic Generator
Produces: 070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__sha8.png
          070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__sha8.pdf
Resolution: 3840 × 5400 px (300 DPI, 12.8 × 18 in)
Run: python3 generate_infographic.py
"""

import hashlib
import os
import sys
from datetime import date

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Installing Pillow...")
    os.system(f"{sys.executable} -m pip install Pillow --break-system-packages -q")
    from PIL import Image, ImageDraw, ImageFont

# ─── Canvas constants ────────────────────────────────────────────────────────
W, H = 3840, 5800
BG    = (13, 15, 20)       # near-black
WHITE = (240, 242, 248)
DIM   = (120, 126, 148)

# ─── SJL PARA palette ───────────────────────────────────────────────────────
AMBER   = (245, 166,  35)  # 010000 INBOX
BLUE    = ( 60, 120, 216)  # 020000 PROJECTS
TEAL    = ( 22, 167, 101)  # 030000 AREAS
VIOLET  = (142,  99, 206)  # 040000 RESOURCES
SLATE   = (102, 102, 102)  # 050000 ARCHIVES
CRIMSON = (204,  58,  33)  # 060000 PRIVATE MEDIA
GRAPHITE= ( 67,  67,  67)  # 070000 SYSTEM AUTO
CYAN    = ( 74, 134, 232)  # 080000 APP DATA
RED     = (230, 101,  80)  # 090000 QUARANTINE
FATAL   = (204,  58,  33)  # fatal stages

# ─── Layout helpers ──────────────────────────────────────────────────────────
PAD  = 80
COL  = (W - 3*PAD) // 2    # two-column width

def make_font(size, bold=False):
    """Try system fonts; fall back to default."""
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.otf" if bold else
        "/usr/share/fonts/truetype/freefont/FreeSans.otf",
    ]
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

# Preload fonts
F_TITLE  = make_font(92, bold=True)
F_HEAD   = make_font(64, bold=True)
F_SUB    = make_font(48, bold=True)
F_BODY   = make_font(40)
F_MONO   = make_font(38)
F_SMALL  = make_font(34)
F_TINY   = make_font(28)

def draw_rounded_box(d, x0, y0, x1, y1, fill, radius=24, outline=None, outline_width=3):
    """Draw a filled rounded rectangle onto ImageDraw d."""
    d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill,
                        outline=outline, width=outline_width)

def text_w(d, text, font):
    bb = d.textbbox((0, 0), text, font=font)
    return bb[2] - bb[0]

def centered_text(d, text, cy, font, color=WHITE, x0=0, x1=W):
    tw = text_w(d, text, font)
    d.text(((x0 + x1 - tw) // 2, cy), text, font=font, fill=color)

def section_header(d, title, y, accent_color):
    """Full-width section header bar."""
    draw_rounded_box(d, PAD, y, W - PAD, y + 88, fill=accent_color, radius=16)
    centered_text(d, title, y + 16, F_HEAD)
    return y + 88 + 28

# ─── Build canvas ────────────────────────────────────────────────────────────
img  = Image.new("RGB", (W, H), BG)
d    = ImageDraw.Draw(img)

y = PAD  # current vertical cursor

# ═══════════════════════════════════════════════════════════════════════════════
# HEADER — Title & identity
# ═══════════════════════════════════════════════════════════════════════════════
draw_rounded_box(d, PAD, y, W - PAD, y + 240, fill=(22, 25, 38), radius=24,
                 outline=CYAN, outline_width=4)

centered_text(d, "SJL SOVEREIGN CLOUD", y + 24, F_TITLE, color=CYAN)
centered_text(d, "System Architecture Reference  ·  v8.0  ·  2026-06-29", y + 128, F_SUB, color=DIM)
centered_text(d, "Governing Doctrine: Persistent Metadata Doctrine v8.0  ·  PARA Six-Digit System", y + 186, F_SMALL, color=DIM)
y += 240 + 48

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION A — Canonical Filename Pattern
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "A — CANONICAL FILENAME CONVENTION", y, GRAPHITE)

draw_rounded_box(d, PAD, y, W - PAD, y + 160, fill=(20, 22, 35), radius=18,
                 outline=GRAPHITE, outline_width=2)
pattern = "[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext"
centered_text(d, pattern, y + 20, F_MONO, color=CYAN)
example = "070000_2026-06-29__SJL-CLOUD-0042__annual-budget-review__v1-0__a1b2c3d4.pdf"
centered_text(d, example, y + 90, F_SMALL, color=AMBER)

# Field chip row
chips = [
    ("070000", "PARA Code", GRAPHITE),
    ("2026-06-29", "Date", BLUE),
    ("SJL-CLOUD-0042", "DOCID (permanent)", TEAL),
    ("annual-budget-review", "Semantic Title", VIOLET),
    ("v1-0", "Version", CRIMSON),
    ("a1b2c3d4", "SHA8 Checksum", AMBER),
]
y += 160 + 20
chip_x = PAD + 20
chip_y = y
for label, sub, color in chips:
    chip_w = max(text_w(d, label, F_SMALL) + 40, 240)
    draw_rounded_box(d, chip_x, chip_y, chip_x + chip_w, chip_y + 90, fill=color, radius=12)
    d.text((chip_x + 20, chip_y + 8), label, font=F_SMALL, fill=WHITE)
    d.text((chip_x + 20, chip_y + 52), sub, font=F_TINY, fill=(200, 200, 200))
    chip_x += chip_w + 24
    if chip_x > W - PAD - 300:
        chip_x = PAD + 20
        chip_y += 104

y = chip_y + 104 + 40

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION B — PARA Six-Digit Namespace
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "B — SIX-DIGIT PARA CLASSIFICATION SYSTEM", y, BLUE)

para_codes = [
    ("010000", "INBOX",           AMBER,    "#F5A623", "Transient intake — unclassified incoming"),
    ("020000", "PROJECTS",        BLUE,     "#3C78D8", "Active work with defined outcomes"),
    ("030000", "AREAS",           TEAL,     "#16A765", "Ongoing responsibilities — no end date"),
    ("040000", "RESOURCES",       VIOLET,   "#8E63CE", "Reference material, templates, libraries"),
    ("050000", "ARCHIVES",        SLATE,    "#666666", "Completed, retired, historical"),
    ("060000", "PRIVATE MEDIA",   CRIMSON,  "#CC3A21", "Personal photos, video, audio"),
    ("070000", "SYSTEM AUTO",     GRAPHITE, "#434343", "Infrastructure, configs, Quadlets"),
    ("080000", "APP DATA",        CYAN,     "#4A86E8", "Service exports, DB dumps, backups"),
    ("090000", "QUARANTINE",      RED,      "#E66550", "Unknown, suspicious, pending review"),
]

cols = 3
cell_w = (W - 2*PAD - (cols-1)*24) // cols
row_h  = 110
for i, (code, name, color, hex_val, desc) in enumerate(para_codes):
    col_i = i % cols
    row_i = i // cols
    bx = PAD + col_i * (cell_w + 24)
    by = y + row_i * (row_h + 12)
    draw_rounded_box(d, bx, by, bx + cell_w, by + row_h, fill=color, radius=14)
    d.text((bx + 20, by + 10), code, font=F_SUB, fill=WHITE)
    d.text((bx + 180, by + 10), name, font=F_SUB, fill=WHITE)
    d.text((bx + 20, by + 64), desc, font=F_TINY, fill=(220, 220, 220))

rows_used = (len(para_codes) + cols - 1) // cols
y += rows_used * (row_h + 12) + 48

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION C — Dual-Node Architecture
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "C — DUAL-NODE INFRASTRUCTURE ARCHITECTURE", y, TEAL)

# Nexus box
nx0, ny0, nx1, ny1 = PAD, y, PAD + COL, y + 480
draw_rounded_box(d, nx0, ny0, nx1, ny1, fill=(16, 30, 48), radius=20, outline=BLUE, outline_width=4)
d.text((nx0 + 28, ny0 + 20), "NEXUS  —  Hostinger VPS", font=F_SUB, fill=BLUE)
d.text((nx0 + 28, ny0 + 76), "72.61.74.250  ·  100.115.66.75 (TS)", font=F_SMALL, fill=DIM)
d.text((nx0 + 28, ny0 + 120), "4 vCPU  /  16 GB RAM  /  200 GB NVMe", font=F_SMALL, fill=DIM)
d.text((nx0 + 28, ny0 + 164), "Ubuntu 24.04  ·  x86_64", font=F_SMALL, fill=DIM)
nexus_svcs = ["📦 Nginx Proxy Manager (edge TLS)",
              "📚 BookStack  :6875", "📄 PaperParrot  :8000",
              "⚙️  n8n  :5678", "📊 Uptime Kuma  :3001",
              "☁️  7× MCP servers  :7701-8026",
              "🔐 Tailscale container"]
for i, s in enumerate(nexus_svcs):
    d.text((nx0 + 40, ny0 + 220 + i * 36), s, font=F_SMALL, fill=WHITE)

# sOs box
sx0, sy0, sx1, sy1 = PAD + COL + PAD, y, W - PAD, y + 480
draw_rounded_box(d, sx0, sy0, sx1, sy1, fill=(16, 32, 24), radius=20, outline=TEAL, outline_width=4)
d.text((sx0 + 28, sy0 + 20), "sOs  —  Oracle Cloud ARM64", font=F_SUB, fill=TEAL)
d.text((sx0 + 28, sy0 + 76), "100.67.229.94 (Tailscale only)", font=F_SMALL, fill=DIM)
d.text((sx0 + 28, sy0 + 120), "4 OCPU  /  24 GB RAM  ·  Block storage only", font=F_SMALL, fill=DIM)
d.text((sx0 + 28, sy0 + 164), "Ubuntu 22.04  ·  ARM64 Ampere A1.Flex", font=F_SMALL, fill=DIM)
sos_svcs = ["🔐 Tailscale container",
            "⚙️  n8n Worker (queue mode)",
            "👁️  OCR/Vision Worker (ARM64)",
            "🚫 No public ingress",
            "📦 Block storage — no ephemeral disk"]
for i, s in enumerate(sos_svcs):
    d.text((sx0 + 40, sy0 + 220 + i * 36), s, font=F_SMALL, fill=WHITE)

# Tailscale bridge arrow
my = y + 240
d.line([(nx1, my), (sx0, my)], fill=TEAL, width=8)
bridge_label = "Tailscale Mesh  (zero-trust)"
centered_text(d, bridge_label, my - 36, F_SMALL, color=TEAL, x0=nx1, x1=sx0)

y += 480 + 40

# NPM routing summary
draw_rounded_box(d, PAD, y, W - PAD, y + 100, fill=(20, 28, 20), radius=14, outline=TEAL, outline_width=2)
d.text((PAD + 28, y + 14), "🔀 NPM (Nginx Proxy Manager) — Sole Reverse Proxy — TLS termination for all *.shannonjlove.cloud subdomains", font=F_SMALL, fill=WHITE)
d.text((PAD + 28, y + 58), "jc21/nginx-proxy-manager  ·  ports 80 / 443 / 81  ·  Let's Encrypt auto-renew  ·  NO Traefik / NO Caddy", font=F_TINY, fill=DIM)
y += 100 + 48

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION D — FileWarden 12-Stage Pipeline
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "D — FILEWARDEN v2  —  12-STAGE GOVERNANCE PIPELINE", y, VIOLET)

stages = [
    ("1", "DISCOVER",   "inotify/fanotify watch on approved roots",          BLUE,    False),
    ("2", "STABILIZE",  "Wait for write quiescence (2 s stable)",            BLUE,    False),
    ("3", "IDENTIFY",   "SHA-256 hash  +  assign/recover DOCID",             BLUE,    False),
    ("4", "ANALYZE",    "OCR (Tesseract / sOs ARM64) + Vision + PARA classify", VIOLET,False),
    ("5", "VERSION",    "Snapshot prev · increment per decision table",      VIOLET,  False),
    ("6", "DIFF",       "DiffForge.generate_diff() → .sidecars/DOCID/diffs/", GRAPHITE,False),
    ("7", "RENAME",     "Apply canonical [PPPPPP]_DATE__DOCID__title__vN-N__sha8 name", BLUE, False),
    ("8", "SIDECAR ★",  "Write provenance.json + xattr + XMP-sjl embed",    FATAL,   True),
    ("9", "HOOK",       "HookVault.register(docid, path) — async retry",     GRAPHITE,False),
    ("10","MIRROR",     "rclone copy → iDrive E2  +  verify remote SHA-256", TEAL,   False),
    ("11","REGISTER ★", "Mirror Registry INSERT (PostgreSQL)",               FATAL,   True),
    ("12","PUBLISH",    "BookStack append  +  PaperParrot archive",           TEAL,   False),
]

stage_h = 74
stage_w = (W - 2*PAD) // 2 - 20
for i, (num, name, desc, color, is_fatal) in enumerate(stages):
    col_i = i % 2
    row_i = i // 2
    bx = PAD + col_i * (stage_w + 40)
    by = y + row_i * (stage_h + 10)
    outline_c = CRIMSON if is_fatal else None
    draw_rounded_box(d, bx, by, bx + stage_w, by + stage_h, fill=color, radius=12,
                     outline=outline_c, outline_width=5 if is_fatal else 0)
    badge_r = 28
    draw_rounded_box(d, bx + 14, by + 10, bx + 14 + badge_r*2, by + 10 + badge_r*2,
                     fill=(0,0,0,80) if not is_fatal else CRIMSON, radius=badge_r)
    centered_text(d, num, by + 10, F_TINY, x0=bx+14, x1=bx+14+badge_r*2)
    d.text((bx + 75, by + 8), name, font=F_SMALL, fill=WHITE)
    d.text((bx + 75, by + 44), desc, font=F_TINY, fill=(210, 215, 225))

rows_stages = (len(stages) + 1) // 2
y += rows_stages * (stage_h + 10) + 20

# Fatal legend
draw_rounded_box(d, PAD, y, W - PAD, y + 64, fill=(60, 10, 10), radius=12, outline=CRIMSON, outline_width=3)
centered_text(d, "★ FATAL STAGES (8 · SIDECAR and 11 · REGISTER) — Transaction aborts on failure · File restored to pre-rename path · Operator alert via n8n", y + 14, F_SMALL, color=CRIMSON)
y += 64 + 48

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION E — Six-Layer Metadata Pyramid
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "E — SIX-LAYER METADATA AUTHORITY PYRAMID", y, AMBER)

layers = [
    ("Layer 1", "Canonical Filename",              "(minimum recovery — always present)",   GRAPHITE),
    ("Layer 2", "Embedded XMP-sjl + EXIF",         "(portable in-file — write when format supports)", SLATE),
    ("Layer 3", "xattr  user.sjl.*",               "(local acceleration — reconstructable)", VIOLET),
    ("Layer 4", "Sidecar JSON  .sidecars/DOCID/",  "(MANDATORY per governed file)",          BLUE),
    ("Layer 5", "Mirror Registry  (PostgreSQL)",    "★ AUTHORITATIVE — single source of truth ★", TEAL),
    ("Layer 6", "Cloud Object + Manifest (iDrive E2)", "(last-resort recovery only)",        GRAPHITE),
]

pyramid_x  = W // 2
pyramid_top = y
bar_h   = 80
max_w   = W - 2*PAD
taper   = 180

for i, (lnum, lname, ldesc, lcolor) in enumerate(layers):
    bar_w = max_w - i * taper // (len(layers) - 1)
    bx = pyramid_x - bar_w // 2
    by = pyramid_top + i * (bar_h + 6)
    outline_c = WHITE if i == 4 else None
    draw_rounded_box(d, bx, by, bx + bar_w, by + bar_h, fill=lcolor, radius=10,
                     outline=outline_c, outline_width=4)
    label = f"{lnum}  ·  {lname}   {ldesc}"
    tw = text_w(d, label, F_SMALL)
    d.text((pyramid_x - tw // 2, by + 22), label, font=F_SMALL, fill=WHITE)

y += len(layers) * (bar_h + 6) + 48

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION F — Version Decision Table
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "F — VERSION BUMP DECISION TABLE", y, CRIMSON)

version_rows = [
    ("Identical SHA-256",                     "No bump",    "Log no-op",        GRAPHITE),
    ("Metadata / tag / cleanup only",         "PATCH",      "v1-0 → v1-1",      AMBER),
    ("Typo / formatting fix",                 "PATCH",      "v1-1 → v1-2",      AMBER),
    ("Meaningful content update",             "MINOR",      "v1-2 → v2-0",      BLUE),
    ("New service or workflow added",         "MAJOR",      "v2-0 → v3-0",      VIOLET),
    ("SHA changed without approved event",    "#drift",     "→ 090000 QUARANTINE", CRIMSON),
]

row_h_v = 70
col_widths = [900, 340, 420]
col_starts = [PAD, PAD + 940, PAD + 1320]

# Header row
hx = PAD
draw_rounded_box(d, PAD, y, W - PAD, y + row_h_v, fill=GRAPHITE, radius=10)
for label, cx in zip(["Situation", "Bump", "Result"], col_starts):
    d.text((cx + 14, y + 18), label, font=F_SUB, fill=WHITE)
y += row_h_v + 6

for situation, bump, result, color in version_rows:
    draw_rounded_box(d, PAD, y, W - PAD, y + row_h_v, fill=(25, 27, 40), radius=10,
                     outline=color, outline_width=2)
    d.text((col_starts[0] + 14, y + 18), situation, font=F_SMALL, fill=WHITE)
    draw_rounded_box(d, col_starts[1], y + 8, col_starts[1] + 300, y + row_h_v - 8,
                     fill=color, radius=8)
    centered_text(d, bump, y + 16, F_SMALL, x0=col_starts[1], x1=col_starts[1]+300)
    d.text((col_starts[2] + 14, y + 18), result, font=F_SMALL, fill=color)
    y += row_h_v + 6
y += 40

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION G — Subdomain Map
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "G — SUBDOMAIN MAP  ·  shannonjlove.cloud", y, CYAN)

subdomains = [
    ("bookstack",     "BookStack knowledge layer",     ":6875",  "Public via NPM", BLUE),
    ("paperless",     "PaperParrot (Paperless-NGX)",   ":8000",  "Public via NPM", BLUE),
    ("n8n",           "n8n workflow automation",       ":5678",  "Public via NPM", TEAL),
    ("status",        "Uptime Kuma monitoring",        ":3001",  "Public via NPM", TEAL),
    ("admin",         "NPM admin UI",                 ":81",    "Public (auth required)", GRAPHITE),
    ("agent",         "ops-agent / AI Brain",         ":8787",  "Public via NPM", VIOLET),
    ("mcp",           "MCP gateway endpoint",         ":varies","Public",          VIOLET),
    ("github-mcp",    "GitHub MCP server",            ":varies","HTTP 401 = correct", GRAPHITE),
    ("paperless-ai",  "PaperParrot-AI companion",     "TS:3000","Tailscale ONLY ⚠", CRIMSON),
]

sub_w = (W - 2*PAD - 24) // 2
sub_h = 82
for i, (sub, desc, port, access, color) in enumerate(subdomains):
    col_i = i % 2
    row_i = i // 2
    bx = PAD + col_i * (sub_w + 24)
    by = y + row_i * (sub_h + 10)
    draw_rounded_box(d, bx, by, bx + sub_w, by + sub_h, fill=(20, 25, 38), radius=12,
                     outline=color, outline_width=3)
    d.text((bx + 20, by + 8),  f"{sub}.shannonjlove.cloud", font=F_SMALL, fill=color)
    d.text((bx + 20, by + 44), f"{desc}  ·  {port}  ·  {access}", font=F_TINY, fill=DIM)

sub_rows = (len(subdomains) + 1) // 2
y += sub_rows * (sub_h + 10) + 48

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION H — MCP Fleet + Component Architecture
# ═══════════════════════════════════════════════════════════════════════════════
y = section_header(d, "H — MCP CLOUD FLEET  ·  COMPONENT ARCHITECTURE", y, VIOLET)

mcp_servers = [
    ("pCloud",       ":7701", BLUE),
    ("Backblaze B2", ":7702", TEAL),
    ("MediaFire",    ":7703", VIOLET),
    ("MEGA",         ":7704", CRIMSON),
    ("Google Drive", ":7705", BLUE),
    ("iDrive E2",    ":8025", AMBER),
    ("rclone",       ":8026", TEAL),
]

mcp_w = (W - 2*PAD - 6*20) // 7
mcp_h = 140
for i, (name, port, color) in enumerate(mcp_servers):
    bx = PAD + i * (mcp_w + 20)
    draw_rounded_box(d, bx, y, bx + mcp_w, y + mcp_h, fill=color, radius=14)
    centered_text(d, "☁️ MCP", y + 12, F_TINY, x0=bx, x1=bx+mcp_w)
    centered_text(d, name, y + 52, F_SMALL, x0=bx, x1=bx+mcp_w)
    centered_text(d, port, y + 98, F_SMALL, x0=bx, x1=bx+mcp_w, color=(210,210,210))

y += mcp_h + 20

draw_rounded_box(d, PAD, y, W - PAD, y + 60, fill=(20, 22, 35), radius=10, outline=GRAPHITE, outline_width=2)
centered_text(d, "All MCP servers on mcp-fleet.network (internal bridge) · localhost-only · Never public · Root images built from FastMCP source", y + 14, F_SMALL, color=DIM)
y += 60 + 30

# Component boxes: FileWarden / HookVault / DiffForge
components = [
    ("FileWarden v2", "12-stage pipeline daemon\n(Python · inotify · DOCID auth)", "SPEC ONLY", VIOLET),
    ("HookVault",     "Cross-system link store\nFastAPI + SQLite · port 8086\nsjl-hook CLI", "SPEC ONLY", TEAL),
    ("DiffForge",     "Automatic content diff\nFastAPI · port 8087\nper-version diff_record", "SPEC ONLY", BLUE),
    ("Mirror Registry","PostgreSQL on Nexus\nAuthoritative file index\nAll logical_files rows", "DESIGNED", AMBER),
]

comp_w = (W - 2*PAD - 3*24) // 4
comp_h = 180
for i, (name, desc, status, color) in enumerate(components):
    bx = PAD + i * (comp_w + 24)
    draw_rounded_box(d, bx, y, bx + comp_w, y + comp_h, fill=(20, 22, 40), radius=14,
                     outline=color, outline_width=4)
    d.text((bx + 20, y + 16), name, font=F_SUB, fill=color)
    status_color = AMBER if status == "DESIGNED" else CRIMSON
    draw_rounded_box(d, bx + 20, y + 68, bx + 20 + 220, y + 68 + 44, fill=status_color, radius=8)
    centered_text(d, status, y + 76, F_TINY, x0=bx+20, x1=bx+240)
    for li, line in enumerate(desc.split('\n')):
        d.text((bx + 20, y + 122 + li * 30), line, font=F_TINY, fill=DIM)

y += comp_h + 40

# ═══════════════════════════════════════════════════════════════════════════════
# FOOTER
# ═══════════════════════════════════════════════════════════════════════════════
draw_rounded_box(d, PAD, y, W - PAD, y + 100, fill=(20, 22, 35), radius=14,
                 outline=GRAPHITE, outline_width=2)
centered_text(d, "SJL Sovereign Cloud v8.0  ·  shannonjlove.cloud  ·  2026-06-29", y + 18, F_SUB, color=GRAPHITE)
centered_text(d, "No Traefik · No Caddy · No Docker Compose · Podman Quadlets + GNU Stow + NPM + Tailscale", y + 62, F_SMALL, color=DIM)
y += 100 + PAD

# ─── Save PNG ────────────────────────────────────────────────────────────────
out_dir = os.path.dirname(os.path.abspath(__file__))
png_tmp = os.path.join(out_dir, "_infographic_tmp.png")
img.save(png_tmp, "PNG", dpi=(300, 300))

# Compute SHA-8 of PNG content
sha8 = hashlib.sha256(open(png_tmp, "rb").read()).hexdigest()[:8]

png_name = f"070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__{sha8}.png"
pdf_name = f"070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__{sha8}.pdf"

png_path = os.path.join(out_dir, png_name)
pdf_path = os.path.join(out_dir, pdf_name)

os.rename(png_tmp, png_path)
print(f"✅ PNG: {png_name}  ({os.path.getsize(png_path) // 1024} KB)")

# Save PDF (Pillow built-in)
img_rgb = img.convert("RGB")
img_rgb.save(pdf_path, "PDF", resolution=300)
print(f"✅ PDF: {pdf_name}  ({os.path.getsize(pdf_path) // 1024} KB)")

# Pixel audit
import struct
pixels = list(img.getdata())
non_bg = sum(1 for p in pixels if p != BG)
pct = 100 * non_bg / len(pixels)
print(f"📊 Pixel audit: {pct:.1f}% non-background — canvas height used: {y} / {H} px")
print(f"🔑 SHA-8: {sha8}")
