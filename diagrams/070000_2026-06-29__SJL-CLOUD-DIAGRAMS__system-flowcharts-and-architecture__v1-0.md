# SJL SOVEREIGN CLOUD — SYSTEM DIAGRAMS
## Mermaid Flowcharts & Architecture v1.0

| Field | Value |
|---|---|
| DOCID | SJL-CLOUD-DIAGRAMS-001 |
| Version | v1-0 |
| Date | 2026-06-29 |
| PARA | 070000_SYSTEM-AUTOMATION |
| Renders in | GitHub, BookStack (Mermaid plugin), Obsidian |

---

## DIAGRAM 1 — Overall System Architecture

```mermaid
graph TB
    subgraph INTERNET["PUBLIC INTERNET"]
        USER[User / Browser]
        MOBILE[Mobile / iOS]
    end

    subgraph NEXUS["NEXUS — Hostinger VPS (72.61.74.250)"]
        NPM["🔀 Nginx Proxy Manager\nsjl-npm\nPorts 80 / 443 / 81"]

        subgraph EDGE["sjl-edge network"]
            BS["📚 BookStack\n127.0.0.1:6875"]
            PP["📄 PaperParrot\n127.0.0.1:8000"]
            N8N["⚙️ n8n\n127.0.0.1:5678"]
            UK["📊 Uptime Kuma\n127.0.0.1:3001"]
            PORT["🐳 Portainer\n127.0.0.1:9443"]
        end

        subgraph BSNET["bookstack.network (internal)"]
            BSDB["🗄️ BookStack DB\nMariaDB 11"]
        end

        subgraph PPNET["paperparrot.network (internal)"]
            PPDB["🗄️ PaperParrot DB\nPostgreSQL 15"]
            PPREDIS["⚡ Redis 7"]
            PPAI["🤖 PaperParrot-AI\nTS:3000"]
        end

        subgraph MCPNET["mcp-fleet.network (internal)"]
            MCP1["☁️ MCP: pCloud\n:7701"]
            MCP2["☁️ MCP: B2\n:7702"]
            MCP3["☁️ MCP: MediaFire\n:7703"]
            MCP4["☁️ MCP: MEGA\n:7704"]
            MCP5["☁️ MCP: GDrive\n:7705"]
            MCP6["☁️ MCP: iDrive E2\n:8025"]
            MCP7["☁️ MCP: rclone\n:8026"]
        end

        TS_NEX["🔐 Tailscale\n100.115.66.75"]
    end

    subgraph SOS["sOs — Oracle ARM64 (100.67.229.94)"]
        TS_SOS["🔐 Tailscale\n100.67.229.94"]
        N8NW["⚙️ n8n Worker\nqueue mode"]
        OCR["👁️ OCR/Vision Worker\nARM64"]
    end

    subgraph CLOUD["CLOUD STORAGE"]
        IDRIVE["📦 iDrive E2\n11 PARA buckets"]
        B2["📦 Backblaze B2"]
        PCLOUD["📦 pCloud"]
        GDRIVE["📦 Google Drive"]
    end

    USER -->|HTTPS| NPM
    MOBILE -->|HTTPS| NPM
    MOBILE -->|Tailscale| TS_NEX

    NPM --> BS
    NPM --> PP
    NPM --> N8N
    NPM --> UK

    BS <--> BSDB
    PP <--> PPDB
    PP <--> PPREDIS
    PP <--> PPAI

    TS_NEX <-->|Tailscale mesh| TS_SOS
    N8N <-->|queue via Tailscale| N8NW
    N8NW --> OCR

    MCP6 <--> IDRIVE
    MCP2 <--> B2
    MCP1 <--> PCLOUD
    MCP5 <--> GDRIVE
    MCP7 <-->|rclone| IDRIVE
```

---

## DIAGRAM 2 — File Ingest Complete Workflow

```mermaid
flowchart TD
    %% Intake sources
    subgraph SOURCES["FILE INTAKE SOURCES"]
        S1["📱 iOS Share Sheet\n(NeoServer / Files)"]
        S2["💻 macOS Drop\n(sftp / WebDAV)"]
        S3["🌐 n8n Workflow\n(automated)"]
        S4["📧 Email Attach\n(n8n receiver)"]
        S5["🔗 FetchWarden\n(planned — 742000)"]
        S6["⬆️ Direct Upload\n(PaperParrot UI)"]
    end

    subgraph INBOX["010000 INBOX — /srv/sjl/010000_INBOX/"]
        DROP["📥 Drop Zone\n(any subdir)"]
        CONSUME["🗂️ 010300_PAPERLESS-CONSUME\n(PaperParrot auto-consume)"]
    end

    %% FileWarden Pipeline
    subgraph FW["FILEWARDEN v2 DAEMON — 12-Stage Pipeline"]
        FW1["1️⃣ DISCOVER\ninotify / fanotify watch\non approved roots"]
        FW2["2️⃣ STABILIZE\nWait for write quiescence\n(file not changing for 2s)"]
        FW3["3️⃣ IDENTIFY\ncalculate_hash() → SHA256\nassign_docid() → SJL-CLOUD-NNNN"]
        FW4["4️⃣ ANALYZE\nextract_metadata()\nrun_ocr() → text + confidence\nrun_vision() → objects + NSFW score"]
        FW5["5️⃣ VERSION\nsnapshot_previous()\nincrement_version(old_sha, new_sha)"]
        FW6["6️⃣ DIFF\nDiffForge.generate_diff()\n→ .sidecars/DOCID/diffs/"]
        FW7["7️⃣ RENAME\nApply canonical filename:\n[PPPPPP]_YYYY-MM-DD__DOCID__title__vN-N__sha8.ext"]
        FW8["8️⃣ SIDECAR ⚠️ FATAL\nwrite_sidecar(docid, full_record)\n→ .sidecars/DOCID/provenance.json\nXMP-sjl embed + xattr"]
        FW9["9️⃣ HOOK\nHookVault.register(docid, path)\n→ async retry if unreachable"]
        FW10["🔟 MIRROR\nrclone copy → iDrive E2\nVerify remote SHA256 checksum\nMust pass before continuing"]
        FW11["1️⃣1️⃣ REGISTER ⚠️ FATAL\nupdate_registry(docid, transaction)\n→ Mirror Registry (PostgreSQL)"]
        FW12["1️⃣2️⃣ PUBLISH\nBookStack API → append running record\nPaperParrot consume → archive"]
    end

    %% Decision nodes
    HASHFAIL{{"Hash\nfailed?"}}
    NSFW{{"NSFW\n> 0.7?"}}
    CONFIDENCE{{"OCR/vision\nlow confidence?"}}
    COLLISION{{"Filename\ncollision?"}}
    SIDECARFAIL{{"Sidecar\nwrite failed?"}}
    REGFAIL{{"Registry\nwrite failed?"}}
    DRIFTCHECK{{"SHA changed\nwithout approved\nevent?"}}

    %% Terminal states
    QUARANTINE["🔴 090000_QUARANTINE\nAwaiting manual review"]
    INBOX_REVIEW["🟡 010000_INBOX\nLow-confidence review queue"]
    ABORT["❌ TRANSACTION ABORTED\nFile remains at pre-rename path\nError logged to audit trail"]
    STASH["🎬 ServicePrimary = stash\n(private media routing)"]
    COMPLETE["✅ GOVERNED FILE\nIn PARA tree\niDrive E2 mirrored\nMirror Registry registered\nBookStack updated\nPaperParrot archived"]

    %% Intake flow
    S1 & S2 & S3 & S4 & S5 --> DROP
    S6 --> CONSUME
    CONSUME --> PP_DIRECT["PaperParrot processes\ndirectly (OCR + tag)"]

    DROP --> FW1
    FW1 --> FW2
    FW2 --> FW3
    FW3 --> HASHFAIL
    HASHFAIL -->|Yes| QUARANTINE
    HASHFAIL -->|No| FW4

    FW4 --> NSFW
    NSFW -->|Score > 0.7| STASH
    STASH --> FW5
    NSFW -->|Score ≤ 0.7| CONFIDENCE
    CONFIDENCE -->|Low| INBOX_REVIEW
    CONFIDENCE -->|OK| FW5

    FW5 --> DRIFTCHECK
    DRIFTCHECK -->|Drift detected| QUARANTINE
    DRIFTCHECK -->|OK| FW6

    FW6 --> FW7
    FW7 --> COLLISION
    COLLISION -->|Yes| QUARANTINE
    COLLISION -->|No| FW8

    FW8 --> SIDECARFAIL
    SIDECARFAIL -->|Yes - FATAL| ABORT
    SIDECARFAIL -->|No| FW9

    FW9 --> FW10
    FW10 --> FW11
    FW11 --> REGFAIL
    REGFAIL -->|Yes - FATAL| ABORT
    REGFAIL -->|No| FW12

    FW12 --> COMPLETE

    %% Styling
    classDef fatal fill:#cc3a21,color:#fff,stroke:#991a0a
    classDef warn fill:#f5a623,color:#000,stroke:#c47800
    classDef ok fill:#16a765,color:#fff,stroke:#0d7a48
    classDef stage fill:#3c78d8,color:#fff,stroke:#1a56b0
    classDef decision fill:#8e63ce,color:#fff,stroke:#6b3fb0

    class FW8,FW11 fatal
    class QUARANTINE,INBOX_REVIEW,ABORT warn
    class COMPLETE ok
    class FW1,FW2,FW3,FW4,FW5,FW6,FW7,FW9,FW10,FW12 stage
    class HASHFAIL,NSFW,CONFIDENCE,COLLISION,SIDECARFAIL,REGFAIL,DRIFTCHECK decision
```

---

## DIAGRAM 3 — Six-Layer Metadata Authority

```mermaid
graph BT
    subgraph RECOVERY["Last-resort recovery only"]
        L6["Layer 6: Cloud Object + Manifest\niDrive E2 bucket\nRemote checksum verified\nNever queried as live DB"]
    end

    subgraph AUTHORITATIVE["★ AUTHORITATIVE ★"]
        L5["Layer 5: Mirror Registry\nPostgreSQL on Nexus\nSingle source of truth\nMust succeed on every transaction"]
    end

    subgraph PORTABLE["Portable records"]
        L4["Layer 4: Sidecar JSON\n.sidecars/DOCID/provenance.json\nMANDATORY for every governed file\nPortable with file move"]
    end

    subgraph LOCAL["Local acceleration"]
        L3["Layer 3: xattr\nuser.sjl.docid / user.sjl.para / etc.\nLocal filesystem only\nReconstructable from Layer 4+5"]
    end

    subgraph EMBEDDED["Embedded in file"]
        L2["Layer 2: XMP-sjl + EXIF\nEmbedded in PDF / DOCX / image\nPortable with file copy\nWrite when format supports it"]
    end

    subgraph MINIMUM["Minimum recovery"]
        L1["Layer 1: Canonical Filename\n070000_2026-06-29__DOCID__title__v1-0__sha8.ext\nAlways present\nHuman-readable recovery baseline"]
    end

    L1 -->|"Superseded by"| L2
    L2 -->|"Superseded by"| L3
    L3 -->|"Superseded by"| L4
    L4 -->|"Superseded by"| L5
    L5 -->|"Disaster recovery via"| L6

    classDef auth fill:#cc3a21,color:#fff,stroke:#991a0a
    classDef mandatory fill:#3c78d8,color:#fff,stroke:#1a56b0
    classDef portable fill:#16a765,color:#fff,stroke:#0d7a48
    classDef local fill:#8e63ce,color:#fff,stroke:#6b3fb0
    classDef embedded fill:#f5a623,color:#000,stroke:#c47800
    classDef minimum fill:#434343,color:#fff,stroke:#222

    class L5 auth
    class L4 mandatory
    class L6 portable
    class L3 local
    class L2 embedded
    class L1 minimum
```

---

## DIAGRAM 4 — Subdomain & NPM Routing Map

```mermaid
graph LR
    subgraph DNS["Cloudflare DNS\n*.shannonjlove.cloud → 72.61.74.250"]
        A1["bookstack.shannonjlove.cloud"]
        A2["paperless.shannonjlove.cloud"]
        A3["n8n.shannonjlove.cloud"]
        A4["status.shannonjlove.cloud"]
        A5["admin.shannonjlove.cloud"]
        A6["agent.shannonjlove.cloud"]
        A7["mcp.shannonjlove.cloud"]
        A8["github-mcp.shannonjlove.cloud"]
        A9["paperless-ai.shannonjlove.cloud"]
    end

    subgraph NPM["NPM — Nginx Proxy Manager\nsjl-npm container\n80/443 host ports"]
        NPM_CORE["TLS Termination\nLet's Encrypt\nProxy Hosts"]
    end

    subgraph SERVICES["Upstream Services (all localhost)"]
        SVC1["BookStack :6875"]
        SVC2["PaperParrot :8000"]
        SVC3["n8n :5678"]
        SVC4["Uptime Kuma :3001"]
        SVC5["NPM Admin :81"]
        SVC6["AI Brain :8787"]
        SVC7["MCP Gateway :varies"]
        SVC8["GitHub MCP :varies"]
        SVC9["PaperParrot-AI\n100.115.66.75:3000\n(Tailscale ONLY)"]
    end

    A1 --> NPM_CORE --> SVC1
    A2 --> NPM_CORE --> SVC2
    A3 --> NPM_CORE --> SVC3
    A4 --> NPM_CORE --> SVC4
    A5 --> NPM_CORE --> SVC5
    A6 --> NPM_CORE --> SVC6
    A7 --> NPM_CORE --> SVC7
    A8 --> NPM_CORE --> SVC8
    A9 -->|"Tailscale\nClients ONLY"| SVC9

    classDef ts fill:#16a765,color:#fff,stroke:#0d7a48
    class A9,SVC9 ts
```

---

## DIAGRAM 5 — MCP Server Fleet Architecture

```mermaid
graph TB
    subgraph CLAUDE["Claude Code\n(operator workstation)"]
        CC["claude mcp add\n--transport http"]
    end

    subgraph NEXUS["Nexus localhost (127.0.0.1)"]
        subgraph MCPFLEET["mcp-fleet.network (internal bridge)"]
            MCP1["pCloud MCP\n:7701\nlocalhost/sjl/mcp-pcloud"]
            MCP2["Backblaze B2 MCP\n:7702"]
            MCP3["MediaFire MCP\n:7703"]
            MCP4["MEGA MCP\n:7704"]
            MCP5["Google Drive MCP\n:7705"]
            MCP6["iDrive E2 MCP\n:8025"]
            MCP7["rclone MCP\n:8026"]
        end
        SECRETS["🔐 /opt/secrets/\nmcp-*.env files\n(root-only, chmod 600)"]
    end

    subgraph CLOUDS["Cloud Storage Providers"]
        PCLOUD_C["pCloud"]
        B2_C["Backblaze B2"]
        MF_C["MediaFire"]
        MEGA_C["MEGA"]
        GD_C["Google Drive"]
        ID_C["iDrive E2\n(primary storage)"]
        RC_C["All remotes\n(via rclone)"]
    end

    CC -->|"HTTP /mcp"| MCP1
    CC -->|"HTTP /mcp"| MCP2
    CC -->|"HTTP /mcp"| MCP3
    CC -->|"HTTP /mcp"| MCP4
    CC -->|"HTTP /mcp"| MCP5
    CC -->|"HTTP /mcp"| MCP6
    CC -->|"HTTP /mcp"| MCP7

    SECRETS --> MCP1 & MCP2 & MCP3 & MCP4 & MCP5 & MCP6 & MCP7

    MCP1 <-->|"pCloud API"| PCLOUD_C
    MCP2 <-->|"S3 API"| B2_C
    MCP3 <-->|"MediaFire API"| MF_C
    MCP4 <-->|"MEGA SDK"| MEGA_C
    MCP5 <-->|"Google API"| GD_C
    MCP6 <-->|"S3 API"| ID_C
    MCP7 <-->|"rclone backends"| RC_C

    classDef mcp fill:#3c78d8,color:#fff,stroke:#1a56b0
    classDef cloud fill:#16a765,color:#fff,stroke:#0d7a48
    classDef secret fill:#cc3a21,color:#fff,stroke:#991a0a

    class MCP1,MCP2,MCP3,MCP4,MCP5,MCP6,MCP7 mcp
    class PCLOUD_C,B2_C,MF_C,MEGA_C,GD_C,ID_C,RC_C cloud
    class SECRETS secret
```

---

## DIAGRAM 6 — Quadlet Deployment via GNU Stow

```mermaid
flowchart LR
    subgraph GIT["Git Repository\nshannonjlove/hybrid-personal-cloud..."]
        REPO["Quadlet source files\n*.container *.network *.volume"]
    end

    subgraph STOW["GNU Stow Packages\n/srv/sjl/070000_SYSTEM-AUTOMATION/STOW/"]
        PKG_NEX["quadlets-nexus/\n└── etc/containers/systemd/\n    ├── npm.container\n    ├── bookstack.container\n    ├── ... (18 containers)\n    ├── ... (4 networks)\n    └── ... (18 volumes)"]
        PKG_SOS["quadlets-sos/\n└── etc/containers/systemd/\n    ├── tailscale.container\n    ├── n8n-worker.container\n    └── ocr-vision-worker.container"]
    end

    subgraph SYSTEMD["systemd Quadlet target\n/etc/containers/systemd/"]
        SYMLINKS["Symlinks created by stow -t /\n→ npm.container\n→ bookstack.container\n→ sjl-edge.network\n→ bookstack-data.volume\n→ ..."]
    end

    subgraph RUNNING["Running Services"]
        SVCS["sjl-npm.service\nsjl-bookstack.service\nsjl-paperparrot.service\n... (21 total)"]
    end

    GIT -->|"git pull / clone"| PKG_NEX & PKG_SOS
    PKG_NEX -->|"sudo stow -t / quadlets-nexus\n(creates symlinks)"| SYMLINKS
    PKG_SOS -->|"sudo stow -t / quadlets-sos\n(on sOs node)"| SYMLINKS
    SYMLINKS -->|"sudo systemctl daemon-reload\nsystemctl enable --now"| SVCS

    subgraph ROLLBACK["Rollback (one command)"]
        RB["sudo stow -D -t / quadlets-nexus\nsudo systemctl daemon-reload"]
    end

    SVCS -->|"stow -D to rollback"| RB

    classDef git fill:#434343,color:#fff,stroke:#222
    classDef stow fill:#8e63ce,color:#fff,stroke:#6b3fb0
    classDef systemd fill:#3c78d8,color:#fff,stroke:#1a56b0
    classDef running fill:#16a765,color:#fff,stroke:#0d7a48

    class GIT git
    class PKG_NEX,PKG_SOS stow
    class SYMLINKS systemd
    class SVCS running
```

---

## DIAGRAM 7 — HookVault Cross-System Links

```mermaid
graph TD
    subgraph FW["FileWarden Pipeline"]
        RENAME["rename stage\n→ new canonical path"]
        SIDECAR["sidecar stage★\n→ provenance.json"]
        HOOK_CALL["hook stage\nsjl-hook register/moved"]
    end

    subgraph HV["HookVault (port 8086)\nFastAPI + SQLite"]
        subgraph TABLES["Database Tables"]
            HOOKS["hooks\nhook_id | docid | path | service | url"]
            LINKS["hook_links\nfrom_docid | to_docid | link_type"]
            HISTORY["hook_path_history\ndocid | old_path | new_path | moved_at\n(APPEND-ONLY — never delete)"]
        end
        CLI["sjl-hook CLI\nregister | resolve | link\nbacklinks | moved | validate"]
    end

    subgraph CONSUMERS["HookVault Consumers"]
        BS_HOOK["BookStack\n→ resolves DOCID to current URL"]
        PP_HOOK["PaperParrot\n→ links Paperless ID to DOCID"]
        N8N_HOOK["n8n\n→ queries backlinks for automation"]
        CC_HOOK["Claude Code\n→ resolves DOCID to current path"]
    end

    RENAME -->|"moved event"| HOOK_CALL
    SIDECAR -->|"register event"| HOOK_CALL
    HOOK_CALL --> CLI
    CLI --> HOOKS
    CLI --> LINKS
    CLI -->|"every rename"| HISTORY

    HOOKS --> BS_HOOK & PP_HOOK & N8N_HOOK & CC_HOOK

    NOTE["💡 DOCID is permanent.\nPath changes — DOCID never does.\nAll consumers query by DOCID,\nnever by file path."]

    classDef fatal fill:#cc3a21,color:#fff,stroke:#991a0a
    classDef hv fill:#8e63ce,color:#fff,stroke:#6b3fb0
    classDef consumer fill:#16a765,color:#fff,stroke:#0d7a48

    class SIDECAR fatal
    class CLI,HOOKS,LINKS,HISTORY hv
    class BS_HOOK,PP_HOOK,N8N_HOOK,CC_HOOK consumer
```

---

## DIAGRAM 8 — File Versioning Decision Flow

```mermaid
flowchart TD
    START["Incoming file event\n(stabilized path)"]

    EXISTING{{"Existing\nDOCID?"}}
    HASH_SAME{{"SHA-256\nidentical to\ncurrent version?"}}
    APPROVED{{"Change is an\napproved event?\n(operator action / workflow)"}}
    CHANGE_TYPE{{"Type of\ncontent change?"}}

    V_NONE["No version bump\nLog: no-op\nUpdate access timestamp only"]
    V_DRIFT["Flag: #drift\n→ 090000_QUARANTINE\nOperator review required"]
    V_PATCH["PATCH bump\nv1-0 → v1-1\n(metadata / typo / tag only)"]
    V_MINOR["MINOR bump\nv1-2 → v2-0\n(meaningful content change)"]
    V_MAJOR["MAJOR bump\nv2-0 → v3-0\n(new service / workflow)"]
    V_NEW["New DOCID assigned\nVersion starts at v1-0"]

    START --> EXISTING
    EXISTING -->|"No — new file"| V_NEW
    EXISTING -->|"Yes"| HASH_SAME
    HASH_SAME -->|"Yes — identical"| V_NONE
    HASH_SAME -->|"No — changed"| APPROVED
    APPROVED -->|"No — unexpected"| V_DRIFT
    APPROVED -->|"Yes"| CHANGE_TYPE
    CHANGE_TYPE -->|"Metadata / tag\ncleanup only"| V_PATCH
    CHANGE_TYPE -->|"Typo / formatting"| V_PATCH
    CHANGE_TYPE -->|"Meaningful content\nupdate"| V_MINOR
    CHANGE_TYPE -->|"New service or\nworkflow added"| V_MAJOR

    classDef drift fill:#cc3a21,color:#fff,stroke:#991a0a
    classDef patch fill:#f5a623,color:#000,stroke:#c47800
    classDef minor fill:#3c78d8,color:#fff,stroke:#1a56b0
    classDef major fill:#8e63ce,color:#fff,stroke:#6b3fb0
    classDef none fill:#666,color:#fff,stroke:#444
    classDef new fill:#16a765,color:#fff,stroke:#0d7a48

    class V_DRIFT drift
    class V_PATCH patch
    class V_MINOR minor
    class V_MAJOR major
    class V_NONE none
    class V_NEW new
```

---

## DIAGRAM 9 — n8n Automation Architecture (Nexus ↔ sOs)

```mermaid
graph TB
    subgraph TRIGGERS["Workflow Triggers"]
        WH["Webhooks\n(external events)"]
        SCHED["Schedules\n(cron)"]
        WATCH["File watch events\n(FileWarden → n8n)"]
        API_T["API calls\n(Claude Code → n8n)"]
    end

    subgraph NEXUS_N8N["n8n Main — Nexus\nsjl-n8n :5678"]
        ORCHESTRATOR["Workflow Orchestrator\nRoute / schedule / dispatch"]
        REDIS_Q["Redis Queue\nsjl-paperparrot-redis\n(shared)"]
    end

    subgraph SOS_N8N["sOs — ARM64 Workers"]
        N8N_W["n8n Worker\nEXECUTIONS_MODE=queue\nsjl-n8n-worker"]
        OCR_W["OCR/Vision Worker\nlocalhost/sjl/ocr-vision-worker:latest-arm64"]
    end

    subgraph INTEGRATIONS["n8n Integrations"]
        PP_INT["PaperParrot API\nDocument tagging\nStatus updates"]
        BS_INT["BookStack API\nRunning record append"]
        HV_INT["HookVault CLI\nsjl-hook calls"]
        RCLONE_INT["rclone\nCloud sync triggers"]
        GH_INT["GitHub webhook\nDeploy automation"]
        UK_INT["Uptime Kuma API\nAlert routing"]
    end

    WH & SCHED & WATCH & API_T --> ORCHESTRATOR
    ORCHESTRATOR --> REDIS_Q
    REDIS_Q -->|"job dispatch via Tailscale"| N8N_W
    N8N_W --> OCR_W

    ORCHESTRATOR --> PP_INT & BS_INT & HV_INT & RCLONE_INT & GH_INT & UK_INT

    classDef nexus fill:#3c78d8,color:#fff,stroke:#1a56b0
    classDef sos fill:#16a765,color:#fff,stroke:#0d7a48
    classDef integration fill:#8e63ce,color:#fff,stroke:#6b3fb0

    class ORCHESTRATOR,REDIS_Q nexus
    class N8N_W,OCR_W sos
    class PP_INT,BS_INT,HV_INT,RCLONE_INT,GH_INT,UK_INT integration
```

---

## DIAGRAM 10 — PARA Six-Digit Classification Tree

```mermaid
graph LR
    ROOT["SJL PARA\n6-Digit System\n[P][C][SS][NN]"]

    P010000["010000\nINBOX\n#F5A623 Amber\nTransient intake"]
    P020000["020000\nPROJECTS\n#3C78D8 Blue\nActive work"]
    P030000["030000\nAREAS\n#16A765 Teal\nOngoing responsibilities"]
    P040000["040000\nRESOURCES\n#8E63CE Violet\nReference material"]
    P050000["050000\nARCHIVES\n#666666 Slate\nCompleted / retired"]
    P060000["060000\nPRIVATE MEDIA\n#CC3A21 Crimson\nPersonal photos/video"]
    P070000["070000\nSYSTEM AUTO\n#434343 Graphite\nInfra / configs"]
    P080000["080000\nAPP DATA\n#4A86E8 Cyan\nService exports"]
    P090000["090000\nQUARANTINE\n#E66550 Red\nPending review"]
    P742000["742000\nFETCHWARDEN\n(project family)\nAcquisition platform"]

    ROOT --> P010000 & P020000 & P030000 & P040000 & P050000
    ROOT --> P060000 & P070000 & P080000 & P090000 & P742000

    P010000 --> S010300["010300\nPAPERLESS-CONSUME\nAuto-ingest dir"]
    P070000 --> S070000A["071000\nFileWarden"]
    P070000 --> S070000B["072000\nHookVault"]
    P070000 --> S070000C["073000\nDiffForge"]
    P070000 --> S070000D["074000\nMirror Registry"]
    P070000 --> S070000E["079000\nAgent Context"]

    classDef inbox fill:#F5A623,color:#000,stroke:#c47800
    classDef projects fill:#3C78D8,color:#fff,stroke:#1a56b0
    classDef areas fill:#16A765,color:#fff,stroke:#0d7a48
    classDef resources fill:#8E63CE,color:#fff,stroke:#6b3fb0
    classDef archives fill:#666666,color:#fff,stroke:#444
    classDef media fill:#CC3A21,color:#fff,stroke:#991a0a
    classDef system fill:#434343,color:#fff,stroke:#222
    classDef appdata fill:#4A86E8,color:#fff,stroke:#1a56b0
    classDef quarantine fill:#E66550,color:#fff,stroke:#b03020
    classDef fetch fill:#888,color:#fff,stroke:#555

    class P010000,S010300 inbox
    class P020000 projects
    class P030000 areas
    class P040000 resources
    class P050000 archives
    class P060000 media
    class P070000,S070000A,S070000B,S070000C,S070000D,S070000E system
    class P080000 appdata
    class P090000 quarantine
    class P742000 fetch
```
