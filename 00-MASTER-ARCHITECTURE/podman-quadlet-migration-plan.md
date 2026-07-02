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

## New Convention Introduced by This Plan: Container Naming & Labeling

No container-naming/labeling scheme exists today (compose files just used ad hoc
`container_name:`). Phase 3 establishes:

- **Unit location**: `02-CONTAINERS/<service>/systemd/<service>.container` (+ `.volume`,
  `.network` units alongside as needed).
- **Podman labels** (set via `Label=` in every Quadlet unit):
  - `sjl.category=<projects|areas|resources|archive>` (PARA category)
  - `sjl.service=<service-name>`
  - `sjl.node=<nexus|sos>`
  - `sjl.managed-by=quadlet`
  - `sjl.persistence=<volume-name-or-none>`
- **Volume naming**: `<service>-data`, `<service>-db-data`, defined as their own
  `.volume` Quadlet units (not implicit), so persistence is explicit and inspectable
  via `podman volume ls --filter label=sjl.managed-by=quadlet`.

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
  BookStack (+ DB), PhotoPrism, Stash, Hookmark-sync, AI-MCP-servers (5 sub-services).
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
sub-services), using the existing MCP-suite units as the template:

- Write `.container` / `.volume` / `.network` Quadlet units with the labeling scheme above.
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

## Phase 5 — Canonical File System Pass (repo work, ~3-5 days)

- Apply the PARA naming convention (`YYYY-MM-DD_HH-MM_category-subcategory_description_UUID24.ext`)
  to loose root-level files that don't fit it yet: the 5 MCP PDFs, `README.pdf`,
  `mcp-cloud-suite.tar`/`.zip` duplicate.
- File everything into the correct `00-06` directory — nothing stays loose at repo root
  except `README.md` itself.
- Tag every Quadlet unit and doc with the `sjl.*` label scheme (containers) or matching
  frontmatter/metadata (docs), so persistence and provenance are inspectable everywhere.
- Cross-link `03-AUTOMATION/auto-tagging/` and `03-AUTOMATION/metadata-persistence/`
  stubs into real scripts that apply this scheme automatically to new files (extends
  the existing Hazel-rule automation described in `para-structure.md`).

## Phase 6 — Live Cutover (requires your explicit approval, per host)

- Deploy Quadlet units to Nexus first (proxy + public services), then sOs.
- Run old (Docker/Traefik) and new (Podman/nginx) side by side only as long as needed
  to verify, then decommission Docker and Traefik packages from both hosts.
- Rotate any TLS certs/DNS as needed for the nginx+certbot handoff.
- This phase is entirely gated behind `06-OPS/approvals/POLICY.md` ("public exposure,"
  "container deployment") — I'll prepare the exact commands/units for your review but
  won't execute against live infrastructure without your go-ahead each step.

## Phase 7 — Ongoing Guardrails

- Guardrail script from Phase 4 stays permanently wired into pre-commit / CI.
- `02-CONTAINERS/<service>/README.md` becomes the source of truth per service instead
  of "Files (Planned)" stubs — update as part of any future service change.
- Quarterly repo audit (same method as Phase 0) to confirm zero drift back toward
  Docker/Traefik/Caddy.

---

## Suggested Timeline

Assuming part-time, one-person effort: Phases 0-1 this week, Phase 2 next week,
Phase 3 spread over ~2 weeks (one service at a time), Phase 4-5 in the following
week, Phase 6 whenever you're ready to schedule a maintenance window per host,
Phase 7 ongoing indefinitely. Total repo-side work (Phases 0-5): **~4-5 weeks**
part-time. Live cutover (Phase 6) timing is yours to set.
