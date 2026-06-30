#!/usr/bin/env python3
"""
SJL Sovereign Cloud v8.0 — SVG Infographic Generator
Produces: 070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__sha8.svg
Pure vector — infinitely scalable, no raster artifacts.
Run: python3 generate_infographic_svg.py
"""

import hashlib
import os
import re
import xml.etree.ElementTree as ET
from xml.dom import minidom

# ── Canvas ──────────────────────────────────────────────────────────────────
W, H   = 3840, 5900
PAD    = 80
COL    = (W - 3 * PAD) // 2

# ── Palette ─────────────────────────────────────────────────────────────────
BG       = "#0d0f14"
WHITE    = "#f0f2f8"
DIM      = "#787e94"
AMBER    = "#f5a623"
BLUE     = "#3c78d8"
TEAL     = "#16a765"
VIOLET   = "#8e63ce"
SLATE    = "#666666"
CRIMSON  = "#cc3a21"
GRAPHITE = "#434343"
CYAN     = "#4a86e8"
RED      = "#e66550"
FATAL    = "#cc3a21"
DARK_BG  = "#141622"
DARK_BLU = "#101e30"
DARK_GRN = "#102018"

# ── SVG builder ─────────────────────────────────────────────────────────────
class SVG:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.els = []          # list of raw SVG strings
        self.defs_content = [] # content for <defs>

    # ── primitives ──────────────────────────────────────────────────────────
    def _esc(self, s):
        return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

    def rect(self, x, y, w, h, fill, rx=0,
             stroke=None, sw=0, opacity=1.0):
        attrs = f'x="{x}" y="{y}" width="{max(1,w)}" height="{max(1,h)}" rx="{rx}" fill="{fill}"'
        if opacity < 1.0:
            attrs += f' fill-opacity="{opacity}"'
        if stroke:
            attrs += f' stroke="{stroke}" stroke-width="{sw}"'
        self.els.append(f'<rect {attrs}/>')

    def text(self, x, y, content, size, fill=WHITE, anchor="start",
             bold=False, italic=False, opacity=1.0, letter_spacing=0):
        weight = "bold" if bold else "normal"
        style  = "italic" if italic else "normal"
        ls     = f' letter-spacing="{letter_spacing}"' if letter_spacing else ""
        op     = f' opacity="{opacity}"' if opacity < 1.0 else ""
        self.els.append(
            f'<text x="{x}" y="{y}" font-family="\'DejaVu Sans\',Arial,sans-serif" '
            f'font-size="{size}" font-weight="{weight}" font-style="{style}" '
            f'fill="{fill}" text-anchor="{anchor}" dominant-baseline="hanging"{ls}{op}>'
            f'{self._esc(content)}</text>'
        )

    def ctext(self, cx, y, content, size, fill=WHITE, bold=False, x0=0, x1=None):
        """Centered text between x0 and x1 (or W)."""
        if x1 is None:
            x1 = self.w
        mid = (x0 + x1) / 2
        self.text(mid, y, content, size, fill=fill, anchor="middle", bold=bold)

    def line(self, x1, y1, x2, y2, stroke, sw=4):
        self.els.append(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
            f'stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"/>'
        )

    def hline_arrow(self, x1, y, x2, stroke, sw=6):
        """Horizontal arrow left→right."""
        self.line(x1, y, x2, y, stroke, sw)
        # arrowhead
        self.els.append(
            f'<polygon points="{x2},{y} {x2-28},{y-14} {x2-28},{y+14}" fill="{stroke}"/>'
        )

    def tag(self, x, y, w, h, fill, label, label_size=34, rx=10):
        self.rect(x, y, w, h, fill, rx=rx)
        self.text(x + w/2, y + (h - label_size*1.2)/2, label, label_size,
                  anchor="middle", bold=True)

    def badge(self, cx, cy, r, fill, label, size=32):
        self.els.append(
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'
        )
        self.text(cx, cy - size*0.5, label, size, anchor="middle")

    def section_bar(self, y, label, fill):
        self.rect(PAD, y, W - 2*PAD, 92, fill, rx=18)
        self.ctext(0, y + 18, label, 56, bold=True, x0=PAD, x1=W-PAD)
        return y + 92 + 30

    def divider(self, y):
        self.line(PAD, y, W-PAD, y, GRAPHITE, sw=2)
        return y + 28

    def pill(self, x, y, label, sub, color, pw=None):
        size = max(len(label) * 22 + 60, pw or 0)
        self.rect(x, y, size, 96, color, rx=14)
        self.text(x+20, y+10, label, 34, bold=True)
        self.text(x+20, y+56, sub, 26, fill=DIM)
        return x + size + 22

    def render(self):
        defs = ""
        if self.defs_content:
            defs = "<defs>" + "".join(self.defs_content) + "</defs>"
        body = "\n".join(self.els)
        return (
            f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'width="{self.w}" height="{self.h}" '
            f'viewBox="0 0 {self.w} {self.h}">\n'
            f'{defs}\n'
            f'<rect width="{self.w}" height="{self.h}" fill="{BG}"/>\n'
            f'{body}\n'
            f'</svg>'
        )


# ── Build ────────────────────────────────────────────────────────────────────
s = SVG(W, H)
y = PAD  # vertical cursor

# ═══════════════════════════════════════════════════════════════════════════
# HEADER
# ═══════════════════════════════════════════════════════════════════════════
s.rect(PAD, y, W-2*PAD, 252, DARK_BG, rx=26, stroke=CYAN, sw=4)
s.ctext(0, y+22,  "SJL SOVEREIGN CLOUD",                                   92, fill=CYAN, bold=True)
s.ctext(0, y+132, "System Architecture Reference  ·  v8.0  ·  2026-06-29", 46, fill=DIM)
s.ctext(0, y+190, "Governing Doctrine: Persistent Metadata Doctrine v8.0  ·  PARA Six-Digit System", 36, fill=SLATE)
y += 252 + 50

# ═══════════════════════════════════════════════════════════════════════════
# A — CANONICAL FILENAME
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "A — CANONICAL FILENAME CONVENTION", GRAPHITE)

s.rect(PAD, y, W-2*PAD, 168, DARK_BG, rx=18, stroke=GRAPHITE, sw=2)
s.ctext(0, y+18,  "[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext", 44, fill=CYAN)
s.ctext(0, y+88,  "070000_2026-06-29__SJL-CLOUD-0042__annual-budget-review__v1-0__a1b2c3d4.pdf", 38, fill=AMBER)

# field chips
chips = [
    ("070000",              "PARA Code",        GRAPHITE, 270),
    ("2026-06-29",          "Date",             BLUE,     260),
    ("SJL-CLOUD-0042",      "DOCID (permanent)",TEAL,     330),
    ("annual-budget-review","Semantic Title",   VIOLET,   410),
    ("v1-0",                "Version",          CRIMSON,  200),
    ("a1b2c3d4",            "SHA-8 Checksum",   AMBER,    290),
]
cx = PAD + 20;  cy = y + 168 + 20
for label, sub, color, cw in chips:
    s.rect(cx, cy, cw, 96, color, rx=12)
    s.text(cx+18, cy+10, label, 32, bold=True)
    s.text(cx+18, cy+54, sub,   26, fill="#ddd")
    cx += cw + 22
    if cx > W - PAD - 350:
        cx = PAD + 20
        cy += 110
y = cy + 110 + 40

# ═══════════════════════════════════════════════════════════════════════════
# B — SIX-DIGIT PARA
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "B — SIX-DIGIT PARA CLASSIFICATION SYSTEM", BLUE)

para = [
    ("010000","INBOX",        AMBER,    "Transient intake — unclassified incoming"),
    ("020000","PROJECTS",     BLUE,     "Active work with defined outcomes"),
    ("030000","AREAS",        TEAL,     "Ongoing responsibilities — no end date"),
    ("040000","RESOURCES",    VIOLET,   "Reference material, templates, libraries"),
    ("050000","ARCHIVES",     SLATE,    "Completed, retired, historical"),
    ("060000","PRIVATE MEDIA",CRIMSON,  "Personal photos, video, audio"),
    ("070000","SYSTEM AUTO",  GRAPHITE, "Infrastructure, configs, Quadlets"),
    ("080000","APP DATA",     CYAN,     "Service exports, DB dumps, backups"),
    ("090000","QUARANTINE",   RED,      "Unknown, suspicious, pending review"),
]
cols3 = 3
cw3   = (W - 2*PAD - (cols3-1)*24) // cols3
rh3   = 112
for i, (code, name, color, desc) in enumerate(para):
    ci = i % cols3
    ri = i // cols3
    bx = PAD + ci*(cw3+24)
    by = y + ri*(rh3+12)
    s.rect(bx, by, cw3, rh3, color, rx=14)
    s.text(bx+22, by+12, code,          38, bold=True)
    s.text(bx+200, by+12, name,         38, bold=True)
    s.text(bx+22, by+66, desc,          28, fill="#dcdcdc")
y += ((len(para)+cols3-1)//cols3) * (rh3+12) + 50

# ═══════════════════════════════════════════════════════════════════════════
# C — DUAL-NODE ARCHITECTURE
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "C — DUAL-NODE INFRASTRUCTURE ARCHITECTURE", TEAL)

# Nexus
nx0,ny0 = PAD, y
nw,nh   = COL, 490
s.rect(nx0, ny0, nw, nh, DARK_BLU, rx=22, stroke=BLUE, sw=4)
s.text(nx0+28, ny0+20, "NEXUS  —  Hostinger VPS",             52, fill=BLUE, bold=True)
s.text(nx0+28, ny0+82, "72.61.74.250  ·  100.115.66.75 (TS)", 34, fill=DIM)
s.text(nx0+28, ny0+124,"4 vCPU  /  16 GB RAM  /  200 GB NVMe",32, fill=DIM)
s.text(nx0+28, ny0+162,"Ubuntu 24.04  ·  x86_64",             32, fill=DIM)
nexus_svcs = [
    "📦  Nginx Proxy Manager  (edge TLS)",
    "📚  BookStack  :6875",
    "📄  PaperParrot  :8000",
    "⚙️   n8n  :5678",
    "📊  Uptime Kuma  :3001",
    "☁️   7× MCP servers  :7701–8026",
    "🔐  Tailscale container",
]
for i, svc in enumerate(nexus_svcs):
    s.text(nx0+44, ny0+218+i*38, svc, 30, fill=WHITE)

# Tailscale bridge arrow
mid_y = y + nh//2
bx0   = nx0 + nw
bx1   = nx0 + nw + PAD
s.line(bx0, mid_y, bx1, mid_y, TEAL, sw=8)
s.ctext(bx0, mid_y-36, "Tailscale Mesh", 28, fill=TEAL, x0=bx0, x1=bx1)

# sOs
sx0 = PAD + COL + PAD
sw2,sh2 = COL, nh
s.rect(sx0, y, sw2, sh2, DARK_GRN, rx=22, stroke=TEAL, sw=4)
s.text(sx0+28, y+20,  "sOs  —  Oracle Cloud ARM64",                  52, fill=TEAL, bold=True)
s.text(sx0+28, y+82,  "100.67.229.94  (Tailscale only)",              34, fill=DIM)
s.text(sx0+28, y+124, "4 OCPU  /  24 GB RAM  ·  Block storage only", 32, fill=DIM)
s.text(sx0+28, y+162, "Ubuntu 22.04  ·  ARM64 Ampere A1.Flex",       32, fill=DIM)
sos_svcs = [
    "🔐  Tailscale container",
    "⚙️   n8n Worker  (queue mode)",
    "👁️   OCR/Vision Worker  (ARM64)",
    "🚫  No public ingress",
    "💾  Block storage only — no ephemeral disk",
]
for i, svc in enumerate(sos_svcs):
    s.text(sx0+44, y+218+i*38, svc, 30, fill=WHITE)

y += nh + 28

# NPM banner
s.rect(PAD, y, W-2*PAD, 106, DARK_GRN, rx=14, stroke=TEAL, sw=2)
s.text(PAD+28, y+16, "🔀  NPM (Nginx Proxy Manager) — Sole Reverse Proxy — TLS termination for all *.shannonjlove.cloud subdomains", 32, fill=WHITE)
s.text(PAD+28, y+66, "jc21/nginx-proxy-manager  ·  ports 80/443/81  ·  Let's Encrypt auto-renew  ·  NO Traefik / NO Caddy",  28, fill=DIM)
y += 106 + 50

# ═══════════════════════════════════════════════════════════════════════════
# D — FILEWARDEN PIPELINE
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "D — FILEWARDEN v2  —  12-STAGE GOVERNANCE PIPELINE", VIOLET)

stages = [
    ("1",  "DISCOVER",    "inotify/fanotify watch on approved roots",              BLUE,    False),
    ("2",  "STABILIZE",   "Wait for write quiescence (2 s stable)",                BLUE,    False),
    ("3",  "IDENTIFY",    "SHA-256 hash  +  assign/recover DOCID",                 BLUE,    False),
    ("4",  "ANALYZE",     "OCR (Tesseract · sOs ARM64) + Vision + PARA classify",  VIOLET,  False),
    ("5",  "VERSION",     "Snapshot previous · increment per decision table",       VIOLET,  False),
    ("6",  "DIFF",        "DiffForge.generate_diff() → .sidecars/DOCID/diffs/",    GRAPHITE,False),
    ("7",  "RENAME",      "Apply canonical [PPPPPP]_DATE__DOCID__title__vN-N name",BLUE,    False),
    ("8",  "SIDECAR ★",   "Write provenance.json + xattr + XMP-sjl embed",         FATAL,   True),
    ("9",  "HOOK",        "HookVault.register(docid, path) — async retry",          GRAPHITE,False),
    ("10", "MIRROR",      "rclone copy → iDrive E2  +  verify remote SHA-256",     TEAL,    False),
    ("11", "REGISTER ★",  "Mirror Registry INSERT (PostgreSQL)",                    FATAL,   True),
    ("12", "PUBLISH",     "BookStack append  +  PaperParrot archive",               TEAL,    False),
]
sw_s = (W - 2*PAD - 40) // 2
sh_s = 78
for i, (num, name, desc, color, fatal) in enumerate(stages):
    ci = i % 2
    ri = i // 2
    bx = PAD + ci*(sw_s+40)
    by = y + ri*(sh_s+10)
    out_c = "#991a0a" if fatal else None
    s.rect(bx, by, sw_s, sh_s, color, rx=12, stroke=out_c, sw=5 if fatal else 0)
    # badge circle
    s.els.append(f'<circle cx="{bx+42}" cy="{by+sh_s//2}" r="26" fill="rgba(0,0,0,0.35)"/>')
    s.text(bx+42, by+sh_s//2-16, num, 28, anchor="middle", bold=True)
    s.text(bx+80, by+10, name, 34, bold=True)
    s.text(bx+80, by+50, desc, 26, fill="#d0d4e0")

rows_d = (len(stages)+1)//2
y += rows_d*(sh_s+10) + 20

# fatal legend
s.rect(PAD, y, W-2*PAD, 68, "#3c0a0a", rx=12, stroke=CRIMSON, sw=3)
s.ctext(0, y+14, "★ FATAL STAGES (8·SIDECAR and 11·REGISTER) — Transaction aborts on failure · File restored to pre-rename path · Operator alert via n8n", 30, fill=CRIMSON)
y += 68 + 50

# ═══════════════════════════════════════════════════════════════════════════
# E — SIX-LAYER METADATA PYRAMID
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "E — SIX-LAYER METADATA AUTHORITY PYRAMID", AMBER)

layers = [
    ("Layer 1","Canonical Filename",             "(minimum recovery — always present)",     GRAPHITE, False),
    ("Layer 2","Embedded XMP-sjl + EXIF",        "(portable in-file · write when supported)", SLATE, False),
    ("Layer 3","xattr  user.sjl.*",              "(local acceleration — reconstructable)",   VIOLET,  False),
    ("Layer 4","Sidecar JSON  .sidecars/DOCID/", "(MANDATORY per governed file)",             BLUE,    False),
    ("Layer 5","Mirror Registry  (PostgreSQL)",  "★ AUTHORITATIVE — single source of truth ★",TEAL,   True),
    ("Layer 6","Cloud Object + Manifest (iDrive E2)","(last-resort recovery only)",          GRAPHITE,False),
]
bh_l = 84
max_w_l = W - 2*PAD
taper_l = 200
pcx = W // 2
for i, (lnum, lname, ldesc, lcolor, auth) in enumerate(layers):
    bw = max_w_l - i * taper_l // (len(layers)-1)
    bx = pcx - bw//2
    by = y + i*(bh_l+6)
    out_c = WHITE if auth else None
    s.rect(bx, by, bw, bh_l, lcolor, rx=10, stroke=out_c, sw=4 if auth else 0)
    label = f"{lnum}  ·  {lname}   {ldesc}"
    s.ctext(0, by+22, label, 30, fill=WHITE, x0=bx, x1=bx+bw)
y += len(layers)*(bh_l+6) + 50

# ═══════════════════════════════════════════════════════════════════════════
# F — VERSION DECISION TABLE
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "F — VERSION BUMP DECISION TABLE", CRIMSON)

ver_rows = [
    ("Identical SHA-256",                  "No bump", "Log no-op",           GRAPHITE),
    ("Metadata / tag / cleanup only",      "PATCH",   "v1-0 → v1-1",         AMBER),
    ("Typo / formatting fix",              "PATCH",   "v1-1 → v1-2",         AMBER),
    ("Meaningful content update",          "MINOR",   "v1-2 → v2-0",         BLUE),
    ("New service or workflow added",      "MAJOR",   "v2-0 → v3-0",         VIOLET),
    ("SHA changed without approved event", "#drift",  "→ 090000 QUARANTINE", CRIMSON),
]
vrow_h = 74
vcols  = [900, 340, 0]  # widths for col 0 and 1; col 2 fills rest
vc_x   = [PAD, PAD+940, PAD+1320]

# header
s.rect(PAD, y, W-2*PAD, vrow_h, GRAPHITE, rx=10)
for lbl, cx in zip(["Situation","Bump","Result"], vc_x):
    s.text(cx+16, y+20, lbl, 38, bold=True)
y += vrow_h + 6

for situation, bump, result, color in ver_rows:
    s.rect(PAD, y, W-2*PAD, vrow_h, DARK_BG, rx=10, stroke=color, sw=2)
    s.text(vc_x[0]+16, y+20, situation, 32)
    s.rect(vc_x[1], y+8, 310, vrow_h-16, color, rx=8)
    s.ctext(vc_x[1], y+16, bump, 32, bold=True, x0=vc_x[1], x1=vc_x[1]+310)
    s.text(vc_x[2]+16, y+20, result, 32, fill=color)
    y += vrow_h + 6
y += 44

# ═══════════════════════════════════════════════════════════════════════════
# G — SUBDOMAIN MAP
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "G — SUBDOMAIN MAP  ·  shannonjlove.cloud", CYAN)

subs = [
    ("bookstack",   "BookStack knowledge layer",    ":6875",  "Public via NPM",        BLUE),
    ("paperless",   "PaperParrot (Paperless-NGX)",  ":8000",  "Public via NPM",        BLUE),
    ("n8n",         "n8n workflow automation",      ":5678",  "Public via NPM",        TEAL),
    ("status",      "Uptime Kuma monitoring",       ":3001",  "Public via NPM",        TEAL),
    ("admin",       "NPM admin UI",                ":81",    "Public (auth required)",GRAPHITE),
    ("agent",       "ops-agent / AI Brain",         ":8787",  "Public via NPM",        VIOLET),
    ("mcp",         "MCP gateway endpoint",         ":varies","Public",                VIOLET),
    ("github-mcp",  "GitHub MCP server",            ":varies","HTTP 401 = correct",    GRAPHITE),
    ("paperless-ai","PaperParrot-AI companion",     "TS:3000","Tailscale ONLY ⚠",      CRIMSON),
]
sub_w = (W - 2*PAD - 24) // 2
sub_h = 86
for i, (sub, desc, port, access, color) in enumerate(subs):
    ci = i % 2
    ri = i // 2
    bx = PAD + ci*(sub_w+24)
    by = y + ri*(sub_h+10)
    s.rect(bx, by, sub_w, sub_h, DARK_BG, rx=12, stroke=color, sw=3)
    s.text(bx+22, by+10, f"{sub}.shannonjlove.cloud", 34, fill=color, bold=True)
    s.text(bx+22, by+54, f"{desc}  ·  {port}  ·  {access}", 26, fill=DIM)
sub_rows = (len(subs)+1)//2
y += sub_rows*(sub_h+10) + 50

# ═══════════════════════════════════════════════════════════════════════════
# H — MCP FLEET + COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════
y = s.section_bar(y, "H — MCP CLOUD FLEET  ·  COMPONENT ARCHITECTURE", VIOLET)

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
mcp_h = 148
for i, (name, port, color) in enumerate(mcp_servers):
    bx = PAD + i*(mcp_w+20)
    s.rect(bx, y, mcp_w, mcp_h, color, rx=16)
    s.ctext(0, y+14, "☁ MCP",  28, fill=WHITE, x0=bx, x1=bx+mcp_w)
    s.ctext(0, y+54, name,     34, fill=WHITE, bold=True, x0=bx, x1=bx+mcp_w)
    s.ctext(0, y+100, port,    30, fill="#ddd", x0=bx, x1=bx+mcp_w)
y += mcp_h + 18

s.rect(PAD, y, W-2*PAD, 62, DARK_BG, rx=10, stroke=GRAPHITE, sw=2)
s.ctext(0, y+16, "All MCP servers on mcp-fleet.network (internal)  ·  localhost-only  ·  Never public  ·  Images built from FastMCP source", 30, fill=DIM)
y += 62 + 30

# component boxes
comps = [
    ("FileWarden v2",  "12-stage pipeline daemon\nPython · inotify · DOCID authority", "SPEC ONLY",  VIOLET),
    ("HookVault",      "Cross-system link store\nFastAPI + SQLite · port 8086\nsjl-hook CLI",       "SPEC ONLY",  TEAL),
    ("DiffForge",      "Automatic content diff\nFastAPI · port 8087\nper-version diff_record",      "SPEC ONLY",  BLUE),
    ("Mirror Registry","PostgreSQL on Nexus\nAuthoritative file index\nlogical_files table",        "DESIGNED",   AMBER),
]
comp_w = (W - 2*PAD - 3*24) // 4
comp_h = 192
for i, (name, desc, status, color) in enumerate(comps):
    bx = PAD + i*(comp_w+24)
    s.rect(bx, y, comp_w, comp_h, DARK_BG, rx=16, stroke=color, sw=4)
    s.text(bx+22, y+16, name, 40, fill=color, bold=True)
    sc = AMBER if status == "DESIGNED" else CRIMSON
    s.rect(bx+22, y+68, 220, 46, sc, rx=8)
    s.ctext(bx+22, y+78, status, 28, bold=True, x0=bx+22, x1=bx+242)
    for li, line in enumerate(desc.split("\n")):
        s.text(bx+22, y+128+li*30, line, 26, fill=DIM)
y += comp_h + 40

# ═══════════════════════════════════════════════════════════════════════════
# FOOTER
# ═══════════════════════════════════════════════════════════════════════════
s.rect(PAD, y, W-2*PAD, 108, DARK_BG, rx=16, stroke=GRAPHITE, sw=2)
s.ctext(0, y+16, "SJL Sovereign Cloud v8.0  ·  shannonjlove.cloud  ·  2026-06-29",         44, fill=GRAPHITE, bold=True)
s.ctext(0, y+70, "No Traefik · No Caddy · No Docker Compose · Podman Quadlets + GNU Stow + NPM + Tailscale", 30, fill=SLATE)
y += 108 + PAD


# ── Output ───────────────────────────────────────────────────────────────────
out_dir = os.path.dirname(os.path.abspath(__file__))
svg_str  = s.render()

sha8 = hashlib.sha256(svg_str.encode()).hexdigest()[:8]
svg_name = (f"070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC"
            f"__sovereign-cloud-v8-poster__v1-0__{sha8}.svg")
svg_path = os.path.join(out_dir, svg_name)

with open(svg_path, "w", encoding="utf-8") as f:
    f.write(svg_str)

size_kb = os.path.getsize(svg_path) // 1024
print(f"✅ SVG : {svg_name}  ({size_kb} KB)")
print(f"📐 Canvas: {W} × {y} px (content), viewBox: 0 0 {W} {H}")
print(f"🔑 SHA-8: {sha8}")
print(f"🎨 Elements: {len(s.els)}")
