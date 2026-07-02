# Podman Quadlet Migration & Canonicalization Plan

## Purpose

This is the authoritative, phased plan for three linked objectives across the entire
Hybrid Personal Cloud Server Infrastructure:

1. **Eliminate Docker, Traefik, and Caddy** — from running services, configs, scripts,
   and prose documentation. Zero references anywhere in the repo or on any node.
2. **Every service runs as a structured Podman Quadlet** — no bare `podman run`, no
   Docker Compose, no ad hoc containers. One unit-file convention for all of them.
3. **Canonical file system** — every file cleaned up, named, tagged, labeled, and
   filed per the PARA structure already defined in `para-structure.md`.

This doc supersedes the "Docker + Traefik" language in `README.md`,
`00-MASTER-ARCHITECTURE/system-overview.md`, `00-MASTER-ARCHITECTURE/infrastructure-map.md`,
and the legacy `docs/` folder — those get updated/retired in Phase 4/5 below.

**Scope note:** This repo is the operational blueprint (docs-as-code + Quadlet unit
files). Actual deployment to Nexus (Hostinger VPS) or sOs (Oracle ARM) happens on
those hosts and is gated by `06-OPS/approvals/POLICY.md` ("Any container deployment,"
"Any public exposure" both require approval) — each phase below separates *repo work*
(plan, configs, unit files — autopilot) from *live cutover* (requires your explicit
go-ahead per host).

## Key Decisions

| Decision | Choice | Why |
|---|---|---|
| Reverse proxy replacement | **nginx + certbot** | Traefik and Caddy are both banned. Static nginx vhosts + certbot is the standard pairing with Podman Quadlets — routing config becomes versioned files instead of dynamic container-label discovery (which also removes the need to mount the Podman/Docker socket into the proxy container). |
| Container orchestration | **Podman Quadlet** (`.container`/`.volume`/`.network`/`.pod` units under `systemd --user`) | Already proven in this repo — `mcp-cloud-suite.tar` ships 5 working Quadlet units. That becomes the template for every other service. |
| File naming | **Existing PARA convention**: `YYYY-MM-DD_HH-MM_category-subcategory_description_UUID24.ext` (`para-structure.md`) | Already defined; this plan applies it consistently instead of introducing a second scheme. |
| OCR / auto-tagging engine | **Paperless-ngx** (assumed default — see note below) | Already named in `infrastructure-map.md` as the intended doc-management tool. Runs as its own Quadlet service; does OCR + tagging + full-text search out of the box for every PDF/scanned doc. |
| Metadata storage | **Sidecar file per item, as source of truth** (assumed default — see note below) | Git-trackable, human-readable, no extra DB dependency for the repo itself. Paperless-ngx's own internal DB serves as the searchable index for anything ingested through it, satisfying both "versioned" and "queryable" without a second bespoke system. |
| Visual content tagging engine | **PhotoPrism, as primary and authoritative source** | You confirmed: PhotoPrism's own AI (object/label detection, scene classification, face/subject recognition, color analysis) is the content-based tagging and naming engine for every image and video — not a nice-to-have layered on top of filename conventions, but the actual source the naming/tagging pipeline reads from. |
| Geolocation resolution | **Reverse-geocode GPS EXIF to a full street address**, not just raw coordinates (assumed default — see note below) | You require pinpointed addresses, not lat/long pairs. Needs a reverse-geocoding provider — recommending **self-hosted Nominatim** (OpenStreetMap data) as the default so GPS coordinates from your personal photos never leave your infrastructure, consistent with this repo's "protect privacy at all times" principle. Google's Geocoding API is the higher-accuracy alternative but sends coordinates to Google per lookup. |
| GCP Vision / Video Intelligence | **Optional future enrichment, gated on the GCP VM decision** | See dedicated subsection below — not part of Phases 0-7, added as Phase 8 once/if you stand up the GCP VM. |

> **Note on decisions marked "assumed default" above:** these were asked back to you
> but the clarifying-question tool failed on a connection error repeatedly. I've
> proceeded with the recommended defaults so this plan isn't blocked — say so in a
> normal reply (not the question tool) if you'd choose differently and I'll revise.

## Legacy Desktop / GUI Tooling (WebTopSJL) — feasibility flagged, not yet built

You asked to add ABBYY FineReader for OCR, use your NeoFinder license (Mac media
cataloging software) against our cloud services, and install DeltaWalker v4 (Unix),
proposing a "WebTopSJL" desktop environment to host them. Three different feasibility
profiles here — flagging before building anything so the plan doesn't quietly assume
something that can't actually run:

| Tool | Platform reality | Verdict |
|---|---|---|
| **DeltaWalker v4** | Deltopia ships native Linux builds (deb/rpm/tar.gz) alongside Windows/Mac. | **Feasible.** GUI app, so it still needs a display — see WebTopSJL below — but the binary itself runs natively on Linux, no emulation needed. |
| **ABBYY FineReader** | The desktop "FineReader PDF" product is Windows/Mac only — no Linux build. ABBYY does sell a separate Linux-targeted **server/SDK** product (FlexiCapture/FineReader Engine) for automated pipelines, but that's a different product and license from a desktop reader seat. | **Depends on which license you hold** — see question below. If it's the desktop app, it can't be wired into the headless Podman pipeline; it would stay a manual, interactive tool. |
| **NeoFinder** | Mac-only. No Windows or Linux version has ever existed. It catalogs locally-mounted volumes (drives, network shares) with thumbnails/metadata — it has no concept of "cloud services" directly, only whatever's mounted as a filesystem. | **Not containerizable on this Linux infrastructure.** Running it would require an actual macOS environment (real Apple hardware, or a Mac-hosting provider like MacStadium — Apple's EULA blocks virtualizing macOS on non-Apple hardware). This is a fundamentally different infra track than Podman Quadlets on Nexus/sOs. |

**What "WebTopSJL" would be, if we build it:** a Podman Quadlet running
`linuxserver/webtop` — a full Linux desktop (XFCE/KDE) rendered in-browser via
KasmVNC, deployed like any other service (its own `.container`/`.volume` units,
full `sjl.*` label set, `sjl.exposure=private`/Tailscale-only since it's an admin
tool, not public). DeltaWalker v4 installs cleanly inside it as a normal Linux
package. This becomes a real Phase 3 addition once confirmed.

**What it can't be, no matter how it's packaged:** a place to run NeoFinder or
(desktop) ABBYY FineReader, since a Linux desktop container still only runs Linux
binaries — it's not emulation or virtualization of macOS/Windows.

**Two things I need from you before I write the WebTopSJL units and DeltaWalker
Quadlet:**
1. Which ABBYY product/license do you actually hold — the desktop FineReader
   (Mac or Windows), or a server/SDK product? That determines whether it joins the
   automated OCR pipeline (Phase 3, alongside Paperless-ngx) or stays a manual tool
   run on your own machine.
2. For NeoFinder's actual goal (media tagging/metadata for cloud-stored files) —
   do you want to keep running NeoFinder locally on your Mac against
   rclone-mounted cloud storage (which works today, no infra change needed), or
   is the metadata-cataloging goal already covered by PhotoPrism (Phase 3) for
   photos/video and Paperless-ngx for documents, making a NeoFinder-equivalent
   on the Linux side unnecessary?

**Also, a standing limitation worth restating:** this session only has access to
this git repository's checkout — not SSH/terminal access to Nexus, sOs, or any
other live host. I can author the Quadlet units, install scripts, and docs (the
same as everything else in this plan), but the actual `podman` commands need to
run *on* the target host, either by you, or by me in a session with real access to
that machine.

## Container & File Tagging Convention (expanded)

The user asked for a **tagging convention**, not just a naming convention — and for
**every item** (container or file) to carry exhaustive metadata, including OCR'd
content where the item isn't natively text. This replaces the earlier, thinner
"Container Naming & Labeling" section.

### Container-level tags (Podman labels)

Every Quadlet unit sets these via `Label=` — not just identity, but operational and
security-relevant facts, so the label set alone answers "what is this, where does it
live, what does it hold, and how sensitive is it":

- `sjl.service=<service-name>` — canonical service name
- `sjl.category=<projects|areas|resources|archive>` — PARA category
- `sjl.node=<nexus|sos>` — which host this runs on
- `sjl.managed-by=quadlet` — provenance/enforcement marker (also what the Phase 7
  guardrail script checks for — anything without it is flagged as drift)
- `sjl.persistence=<volume-name|none>` — which `.volume` unit(s) hold its state
- `sjl.exposure=<public|private|tailscale-only>` — network reachability, so a `grep`
  for `sjl.exposure=public` always gives the current full public attack surface
- `sjl.data-classification=<none|personal|financial|legal|credentials>` — what kind
  of data the service touches, driving backup/encryption priority
- `sjl.backup-policy=<none|daily|weekly|manual>`
- `sjl.owner=sjl` — reserved for future multi-user use, currently always you
- `sjl.image-ref=<image>:<tag>` — exact pinned image, since Quadlets should never
  float on `:latest` (closes a gap in the current `docker-compose.yml`, which pins
  nothing)
- `sjl.deployed=<YYYY-MM-DD>` — when this unit was last (re)deployed

Volumes get their own subset: `sjl.service`, `sjl.persistence-role=<primary|db|cache>`,
`sjl.backup-policy`.

### File-level tags (every item in the repo, and eventually every item in the S3 vault)

"Exhaustively tagged" means every file gets a metadata record whether or not it's
human-authored text:

- **Text/config/doc files** (`.md`, `.yml`, `.sh`, etc.): tagged via YAML frontmatter
  at the top of the file itself — `para_category`, `description`, `uuid24`,
  `created`, `related_service`, `sensitivity`.
- **Binary/opaque files** (PDFs, images, archives — e.g. the 5 MCP PDFs, `README.pdf`,
  `mcp-cloud-suite.tar`): can't hold frontmatter, so each gets a sidecar
  `<filename>.meta.yaml` next to it, carrying the same fields **plus**:
  - `ocr_text_present: true|false`
  - `ocr_source: paperless-ngx|tesseract|none`
  - `ocr_extracted_at: <timestamp>`
  - `ocr_confidence: <if available>`
  - a `content_summary` field (short human/AI-written summary of what OCR found,
    since raw OCR dumps aren't useful as a tag)
- **Images/photos/video — PhotoPrism as primary, authoritative tagging engine**:
  PhotoPrism's full analysis output (object/label detection, scene classification,
  face/subject recognition, dominant colors, camera/lens model, classification
  confidence scores) is pulled into the sidecar under `photoprism_tags: [...]`,
  `photoprism_subjects: [...]`, `photoprism_colors: [...]`, etc. — not summarized,
  the full structured output — so tags survive even if PhotoPrism is ever replaced,
  and so the **filename/PARA description itself is generated from this content
  analysis** (e.g. a photo PhotoPrism classifies as `beach, sunset, dog` renames
  through Hazel as `..._resources-photos_beach-sunset-dog_<uuid24>.jpg`, not a
  generic camera filename). This is the exhaustive, content-driven naming the plan
  now includes explicitly, not just chronological/manual naming.
- **Anything Hookmark links to**: the Hookmark deep-link ID is stored in the sidecar
  too (`hookmark_id`), closing the loop between the deep-linking layer and the
  canonical metadata record.

### EXIF / embedded technical metadata (mandatory, all photo & video files)

Every photo and video, wherever it lands in the system, must have its **full embedded
metadata preserved and surfaced**, not just PhotoPrism's derived content tags:

- **Extraction engine: [ExifTool](https://exiftool.org/)** (Phil Harvey) — the actual
  named tool for this step, filling a gap this plan previously left implicit. It's
  open-source, cross-platform (native Linux package: `libimage-exiftool-perl`), and
  reads/writes EXIF/IPTC/XMP/MakerNotes across hundreds of formats — the most
  exhaustive option available and more thorough than PhotoPrism's own built-in
  parsing, which only surfaces a subset. Verified working (v12.76) via
  `apt install libimage-exiftool-perl` on Ubuntu 24.04, matching the Debian-based
  images `linuxserver/webtop` and most Quadlet base images already use.
- Full EXIF (camera, lens, exposure, timestamp, orientation) + IPTC/XMP where present,
  extracted in full into the sidecar under an `exif:` block via `exiftool -json`
  (structured, scriptable output) — not a curated subset.
- **GPS is reverse-geocoded, not left as raw coordinates.** ExifTool extracts the raw
  `GPSLatitude`/`GPSLongitude` (never discarded — it's the ground truth); the sidecar
  also carries a resolved `address:` block (`street`, `city`, `region`, `postal_code`,
  `country`) via the Nominatim reverse-geocoding provider from the Key Decisions table.
- Division of labor: **ExifTool owns raw technical/embedded metadata extraction**;
  **PhotoPrism owns content-based tagging** (objects, scenes, faces) that ExifTool
  can't do; **Nominatim owns coordinate-to-address resolution**. All three feed the
  same per-file sidecar, so no tool is asked to do a job outside what it's built for.
- Runs as a small tagging-pipeline utility (Phase 5 automation script calling
  `exiftool`), not as its own always-on Quadlet service — it's a CLI tool invoked
  per file, so it just needs to be installed inside whichever container/host runs
  the `03-AUTOMATION/auto-tagging/` pipeline.
- Non-photo/video files carry whatever embedded metadata their format supports
  (PDF `/Info` + XMP, audio ID3, etc.) — ExifTool reads all of these too — into the
  same sidecar shape for consistency, even though most won't have GPS data.

### GCP Vision / Video Intelligence enrichment (future — Phase 8, gated on the GCP VM)

You're considering a GCP VM and asked whether GCP's image/video recognition models
could either supplement PhotoPrism directly or **teach/calibrate PhotoPrism's local
models**. Two modes, both deferred to a Phase 8 that only starts once the GCP VM is
actually stood up (not blocking Phases 0-7, and each mode has a real tradeoff to weigh
before committing):

1. **Direct enrichment pass** — send images/video through Cloud Vision API / Video
   Intelligence API as a second tagging pass alongside PhotoPrism, merging both label
   sets into the sidecar (`gcp_vision_tags: [...]`) tagged with `source: gcp` so it's
   always distinguishable from PhotoPrism's own output. Tradeoff: your photos/video
   leave local infrastructure per API call, plus per-image/per-minute GCP cost — a
   real conflict with this repo's stated "protect privacy at all times" principle that
   needs your explicit sign-off before any image is sent, service by service.
2. **Model calibration/distillation** — run GCP's models once over a labeled batch and
   use the output as higher-quality ground-truth labels to fine-tune or calibrate
   PhotoPrism's on-device classification (improving local confidence without an
   ongoing per-image API dependency). This is a heavier ML engineering task than
   option 1 and would get its own sub-plan when the GCP VM materializes — noted here
   so it isn't lost, not scoped further yet.

This is what turns `03-AUTOMATION/auto-tagging/` and
`03-AUTOMATION/metadata-persistence/` from stubs into a real, enforceable pipeline:
new file lands → Hazel rule renames it to the PARA convention → tagging script
OCRs it (via Paperless-ngx for documents, PhotoPrism + EXIF/reverse-geocoding for
images/video) → writes/updates the sidecar → done. Phase 5 builds this; Phase 7's
guardrail script can then flag any file that's missing its sidecar, the same way it
flags Docker/Traefik/Caddy text.

---

## Phase 0 — Groundwork (this deliverable)

- [x] Audit repo for every Docker/Traefik/Caddy reference (done — see summary below).
- [x] Decide reverse-proxy replacement (nginx + certbot).
- [x] Write this phased plan into `00-MASTER-ARCHITECTURE/`.
- [ ] You review and approve scope/ordering before Phase 1 work starts.

**Audit summary (as of 2026-07-02):** 47 files in repo. Only one real compose file
(root `docker-compose.yml`: Traefik + BookStack + BookStack-DB + PhotoPrism, Docker
socket mount, Traefik labels). No Caddyfile exists on disk. "Docker"/"Traefik"/"Caddy"
appear as prose in ~15 files (mostly `02-CONTAINERS/*/README.md`, `00-MASTER-ARCHITECTURE/*`,
`05-DOCS/*`, root `README.md`). A **working Podman Quadlet precedent already exists**
in `mcp-cloud-suite.tar` (5 MCP-server `.container` units + `deploy-cloud-mcp-suite.sh`,
`systemctl --user`-based) — this is the template for Phase 3.

---

## Phase 1 — Freeze & Inventory (repo work, ~2-3 days)

- Extract and review `mcp-cloud-suite.tar` / `01-DEPLOYMENT/mcp-cloud-suite.zip`
  in place (they're duplicates — keep one canonical copy, archive the other per PARA).
- Build a single service inventory table (name, current runtime, target node,
  domain/subdomain, persistence needs, current phase status) — becomes
  `02-CONTAINERS/SERVICE-INVENTORY.md`. Services identified so far: Traefik (→ retired),
  BookStack (+ DB), PhotoPrism, Stash, Hookmark-sync, AI-MCP-servers (5 sub-services),
  **Paperless-ngx (new — OCR/tagging)**, **Nominatim (new — self-hosted reverse
  geocoding, see EXIF/Geolocation subsection above)**, **WebTopSJL (new — pending
  your answers in the Legacy Desktop Tooling section above; hosts DeltaWalker v4)**.
- Confirm with you: any services running live on Nexus/sOs *right now* that aren't
  reflected in this repo yet (the repo currently looks pre-deployment/planning-stage
  for most services except the MCP suite).

## Phase 2 — Reverse Proxy Foundation (repo work, ~3-5 days)

- Retire `02-CONTAINERS/traefik/` entirely; add `02-CONTAINERS/nginx/`.
- Author `nginx.container` + `nginx-certs.volume` Quadlet units.
- Author one nginx vhost config per planned service under `02-CONTAINERS/nginx/conf.d/`
  (static, versioned — replaces dynamic Traefik labels).
- Certbot: either a `certbot.container` Quadlet run via a systemd timer, or a small
  renewal script triggered by `systemd --user` timer unit — document the choice.
- No live cutover yet (public port 80/443 changes require your approval per
  `06-OPS/approvals/POLICY.md`).

## Phase 3 — Service-by-Service Quadlet Migration (repo work, ~1-2 weeks)

For each service (BookStack+DB, PhotoPrism, Stash, Hookmark-sync, AI-MCP-servers
sub-services, **Paperless-ngx**), using the existing MCP-suite units as the template:

- Write `.container` / `.volume` / `.network` Quadlet units with the full label set
  from the Tagging Convention above (not just `sjl.service`/`sjl.node` — every
  label, including `sjl.exposure`, `sjl.data-classification`, `sjl.backup-policy`,
  `sjl.image-ref` pinned to a digest or version tag, never `:latest`).
- Add `02-CONTAINERS/paperless-ngx/` as a new service module (doesn't exist yet —
  currently only referenced in prose in `infrastructure-map.md`), scoped to OCR +
  tagging + full-text search for every PDF/document in the repo and, later, the S3 vault.
- Add `02-CONTAINERS/nominatim/` as a new, private-only (`sjl.exposure=private`)
  reverse-geocoding service feeding the EXIF/address pipeline — a self-contained
  OSM-data container, no external API calls, no data leaves your infrastructure.
- **Once the two questions in "Legacy Desktop / GUI Tooling" above are answered**:
  add `02-CONTAINERS/webtop-sjl/` (`linuxserver/webtop` Quadlet, `sjl.exposure=private`)
  with DeltaWalker v4 installed inside it. ABBYY FineReader joins the OCR pipeline
  here only if it turns out to be a Linux-capable server/SDK product; otherwise it's
  documented as a manual tool, not part of the automated Quadlet services. NeoFinder
  is out of scope for this repo's services list regardless of the answer, since it
  cannot run on Linux — at most, this repo documents how it stays part of your
  Mac-side workflow against rclone-mounted cloud storage.
- Replace root `docker-compose.yml` service-by-service until it can be deleted.
- Each service's `README.md` "Files (Planned)" section gets replaced with the real,
  committed Quadlet units (closes out the current stub state).
- Delete root `docker-compose.yml` once every service it defines has a Quadlet
  equivalent committed.

## Phase 4 — Docker/Traefik/Caddy Purge Sweep (repo work, ~2-3 days)

- Re-run the full-repo case-insensitive search for `docker`, `docker-compose`,
  `caddy`, `caddyfile`, `traefik` across every text file.
- Update prose in `README.md`, `00-MASTER-ARCHITECTURE/system-overview.md`,
  `00-MASTER-ARCHITECTURE/infrastructure-map.md`, `05-DOCS/full-system-manual.md`,
  `05-DOCS/troubleshooting.md`, `04-SECURITY/tailscale/README.md`,
  `01-DEPLOYMENT/hostinger/README.md`, `06-OPS/approvals/POLICY.md` to reflect
  Podman Quadlet + nginx.
- Add a **guardrail script** (`06-OPS/check-banned-terms.sh`) that fails if any of
  those terms reappear anywhere in the repo (excluding this plan doc's own history/
  rationale text) — wire it in as a pre-commit hook so the "no traces ANYWHERE"
  requirement is enforced going forward, not just achieved once.
- Consolidate/retire the legacy `docs/` folder (`master-roadmap.md`,
  `architecture.md`, `master-system.md`, `security-rules.md`, `system-purpose.md`,
  `docs/README.md`) — it predates the `00-06` numbered structure and duplicates/
  conflicts with it (e.g. still says "Docker containerization"). Archive it under
  a `99-ARCHIVE/` (PARA "Archive") rather than delete, per the non-destructive
  default in `06-OPS/approvals/POLICY.md`.

## Phase 5 — Canonical File System Pass (repo work, ~4-6 days — expanded for exhaustive tagging)

- Apply the PARA naming convention (`YYYY-MM-DD_HH-MM_category-subcategory_description_UUID24.ext`)
  to loose root-level files that don't fit it yet: the 5 MCP PDFs, `README.pdf`,
  `mcp-cloud-suite.tar`/`.zip` duplicate.
- File everything into the correct `00-06` directory — nothing stays loose at repo root
  except `README.md` itself.
- **Run every existing binary/opaque file through OCR once** (Paperless-ngx for the
  5 MCP PDFs + `README.pdf`; PhotoPrism + ExifTool + Nominatim reverse-geocoding for
  any images/video added later) to backfill `<filename>.meta.yaml` sidecars — this is
  the one-time catch-up pass; going forward new files get tagged at ingestion, not
  retroactively.
- Wire PhotoPrism's content tags directly into the Hazel renaming step so filenames
  are content-derived (see the "PhotoPrism as primary tagging engine" note above),
  run **ExifTool** (`exiftool -json`) for the full embedded-metadata block, and wire
  Nominatim into the same pipeline so every photo/video sidecar gets a resolved
  address, not just coordinates. Install target: `libimage-exiftool-perl` (verified
  working, v12.76, on the Debian/Ubuntu base most Quadlet images already use).
- Add YAML frontmatter (`para_category`, `description`, `uuid24`, `created`,
  `related_service`, `sensitivity`) to every text/config/doc file that doesn't have it.
- Tag every Quadlet unit with the full `sjl.*` label set from the Tagging Convention
  above, so persistence, exposure, and data classification are inspectable via
  `podman inspect`/`podman volume ls` for every container, not just named per-service.
- Build the tagging pipeline script(s) under `03-AUTOMATION/auto-tagging/` and
  `03-AUTOMATION/metadata-persistence/` (currently stubs): new file → Hazel renames
  it to PARA convention → script OCRs/tags it → sidecar written/updated. Extends the
  existing Hazel-rule automation described in `para-structure.md` rather than
  replacing it.
- Confirm coverage is exhaustive: every file in the repo has either (a) frontmatter,
  (b) a `.meta.yaml` sidecar, or (c) is itself a `.meta.yaml`/generated artifact
  exempt by rule — Phase 7's guardrail extends to flag any file matching none of these.

## Phase 6 — Live Cutover (requires your explicit approval, per host)

- Deploy Quadlet units to Nexus first (proxy + public services), then sOs.
- Run old (Docker/Traefik) and new (Podman/nginx) side by side only as long as needed
  to verify, then decommission Docker and Traefik packages from both hosts.
- Rotate any TLS certs/DNS as needed for the nginx+certbot handoff.
- This phase is entirely gated behind `06-OPS/approvals/POLICY.md` ("public exposure,"
  "container deployment") — I'll prepare the exact commands/units for your review but
  won't execute against live infrastructure without your go-ahead each step.

## Phase 7 — Ongoing Guardrails

- Guardrail script from Phase 4 stays permanently wired into pre-commit / CI, and gets
  a second check added in Phase 5: flag any file missing frontmatter/sidecar tagging,
  and any Quadlet unit missing a required `sjl.*` label.
- `02-CONTAINERS/<service>/README.md` becomes the source of truth per service instead
  of "Files (Planned)" stubs — update as part of any future service change.
- Quarterly repo audit (same method as Phase 0) to confirm zero drift back toward
  Docker/Traefik/Caddy, and that tagging coverage is still exhaustive.

## Phase 8 — GCP Vision/Video Intelligence Enrichment (future, not yet scheduled)

Only starts once the GCP VM decision is made — see the dedicated subsection above
for the two possible modes (direct enrichment pass vs. model calibration/distillation).
Before this phase begins, it needs its own explicit sign-off round: which mode, which
services' images/video are in scope, and confirmation that sending them to GCP is
acceptable given this repo's stated privacy-first posture. Not included in the
Phase 0-7 timeline below.

---

## Suggested Timeline

Assuming part-time, one-person effort: Phases 0-1 this week, Phase 2 next week,
Phase 3 spread over ~2-3 weeks (one service at a time, now including Paperless-ngx
and Nominatim), Phase 4-5 in the following 1-2 weeks (Phase 5 is heavier now with
EXIF/geolocation/content-derived-naming work), Phase 6 whenever you're ready to
schedule a maintenance window per host, Phase 7 ongoing indefinitely, Phase 8
whenever the GCP VM decision actually happens. Total repo-side work (Phases 0-5):
**~5-6 weeks** part-time. Live cutover (Phase 6) and GCP enrichment (Phase 8)
timing are yours to set.
