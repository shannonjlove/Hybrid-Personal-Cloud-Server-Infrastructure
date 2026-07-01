# 214000 SJL Cloud Audit — Dropbox SJL Catalogue
# Date: 2026-07-01 | Namespace: ns:58979418 (Shannon J. Love DPBXpro)
# Status: Phase 2 complete — PARA drill done; removal flags applied
# Next: cross-cloud dedup vs pCloud, migrate to SJL-MIGRATION-STAGING

---

## ⚠️ ROOT-LEVEL FLAGS

| Path | Size | Status | Action |
|------|------|--------|--------|
| `InDesign_20_LS20.dmg` | 1.5 GB | MISPLACED at root | `FLAG_REMOVE` — re-download if needed |
| `.tags_and_ratings.plist` | 110 MB | macOS metadata | `FLAG_REMOVE` — auto-generated, not needed |
| `._StellarVolumeOptimizer.dmg` | 4 KB | macOS fork file | `FLAG_REMOVE` |
| `._Dear Evan Hansen.mp4` | 4 KB | macOS fork file | `FLAG_REMOVE` |
| `SJL-MIGRATION-STAGING/` | — | Migration root | `KEEP` — active staging target |
| `GoogleDrive-sjlove@shannonjeffreylove.com (10-2-25 2:10 PM)/` | — | Google Drive export Oct 2025 | `AUDIT_NEEDED` — large, needs cataloguing |
| `TO BE SORTED___Folder_2022-03-30_1240_/` | — | Legacy unsorted | `AUDIT_NEEDED` |
| `01162024 Dropbox unsorted/` | — | Jan 2024 dump | `AUDIT_NEEDED` |
| `07112024/` | — | Jul 2024 dump | `AUDIT_NEEDED` |
| `Migrated Paper Docs/` | — | Dropbox Paper export | `AUDIT_NEEDED` |
| `Infrastructure/` | — | Modified 2026-02 | `KEEP` |
| `SJL Backups/` | — | Legacy backups | `AUDIT_NEEDED` |
| `Vault/` | — | Modified 2023-10 | `AUDIT_NEEDED` |
| `DEVans Dflat Music/` | — | Modified 2026-04 | `KEEP` |
| `Wake Up BGVS & ISO Parts/` | — | Modified 2024-11 | `KEEP` |
| `Apps/` | — | App configs | `AUDIT_NEEDED` |

## Shared Mounts (read-only access via ns:14579923699)
| Mount | Type | Notes |
|-------|------|-------|
| `ShannonJLove Team Folder` | team mount | Active business namespace |
| `_OUR Time New HIGH RES` | shared folder | Film project |
| `El Juevos` | shared folder | Project collaborator |
| `Crockett Science (Jasmin Crockett Series Project)` | shared folder | Series project |
| `Mel LAG` | shared folder | Melonie Daniels |

---

## 100000_INBOX — @INBOX_DRPBX_SJL

| Item | Type | Action |
|------|------|--------|
| `3D Scan - Human Model Bundle/` | folder | `FLAG_REMOVE` — tutorial/training asset |
| `3D Scan Store - Male Range of Movement/` | folder | `FLAG_REMOVE` — tutorial/training asset |
| `3D Perspective Plugin/` | folder | `FLAG_REMOVE` — old plugin download |
| `FCPX Folder Template/` | folder | `KEEP` — useful template |
| `spent-presentation-final Folder/` | folder | `ROUTE` → =PROJECTS/AMADAEUS_AND_ASHLEY |
| `Spent Promo Teaser Opener 1-29v1/` | folder | `ROUTE` → =PROJECTS/AMADAEUS_AND_ASHLEY |
| `Spent Promo Teaser Open mOject Scene File (2-8-15)/` | folder | `ROUTE` → =PROJECTS/AMADAEUS_AND_ASHLEY |
| `Spent Treatment Scrivener Backup/` | folder | `ROUTE` → =PROJECTS/AMADAEUS_AND_ASHLEY |
| `spent-presentation-revised.indd` | file (183 B) | `FLAG_REMOVE` — stub/link only |
| `making Love v2 Folder.zip` | file (120 MB) | `ROUTE` → =PROJECTS/MAKING_LOVE |
| `59-globe/` | folder | `AUDIT_NEEDED` |
| `01_Main Files/` | folder | `AUDIT_NEEDED` |
| `Amadaeus & Ashley Blank Budget Template .pdf` | file (358 KB) | `ROUTE` → =PROJECTS/AMADAEUS_AND_ASHLEY |
| `Spent Promo Script 092216.bak*.zip` | file | `FLAG_REMOVE` — corrupt/duplicate archive |
| `_AREAS_DRPBX_SJL/` | folder | `FLAG_REMOVE` — stale duplicate inside inbox |
| `ScreenRecording_02-13-2025 04-02-51_1.mov` | file (100 MB) | `AUDIT_NEEDED` — large loose file |
| `01_Resume.jpg` | file (1 MB) | `AUDIT_NEEDED` |
| `get_latest_files_from_trickster.alfredworkflow` | file (121 KB) | `FLAG_REMOVE` — old automation |

---

## 120000_RESOURCES — =RESOURCES_DRPBX_SJL

| Item | Action |
|------|--------|
| `Professional Samples/` | `KEEP` |
| `Audio Recordings of Texts/` | `KEEP` |
| `Editing & Graphics/` | `KEEP` |
| `Getty Images/` | `KEEP` |
| `Stock Still Images.library/` | `KEEP` |
| `Spirit Inspiration Bible Study/` | `KEEP` |
| `Paystubs Taylor Hodson/` | `KEEP` |
| `R Kelly Abuse/` | `KEEP` — research/reference |
| `untitled folder/` | `FLAG_REMOVE` — unnamed, likely empty |

---

## 220000_ARCHIVES — =ARCHIVES_DRPBX_SJL

| Item | Action |
|------|--------|
| `SJL_Produced_Content_RESOURCES_iDrive/` | `KEEP` — canonical archive |
| `DIGITAL ASSET LIBRARIES/` | `AUDIT_NEEDED` — may have training content inside |
| `Love Family Home/` | `KEEP` |
| `_Melonie Daniels Performance Videos_DropboxSJL_ARCHIVE/` | `KEEP` |

---

## 310000_PROJECTS — =PROJECTS_DRPBX_SJL

### Film / Video
| Item | Action |
|------|--------|
| `UNDERGROUND UPTOWN/` | `KEEP` |
| `MAKING LOVE (Series)/` | `KEEP` |
| `AMADAEUS AND ASHLEY (Short Film)/` | `KEEP` |
| `Lord_of_the_Manners_Film_Assets/` | `KEEP` |
| `SWV_IF_ONLY_YOU_KNEW_PITCH_PROMO/` | `KEEP` |
| `LoveYou Project/` | `KEEP` |
| `OUR TIME Video Deck/` | `KEEP` |
| `Crockett Science (Jasmin Crockett Series Project)` | `KEEP` |
| `El Juevos` | `KEEP` |
| `_OUR Time New HIGH RES` | `KEEP` |
| `Ryan Love Designs Promo Video/` | `KEEP` |

### Church / Ministry
| Item | Action |
|------|--------|
| `CCCoC_2025/` | `KEEP` |
| `CCC Swords 2025/` | `KEEP` |
| `WAKE UP/` | `KEEP` |
| `UJC/` | `KEEP` |
| `UJC Open Mic Setup 05292925/` | `KEEP` |
| `Water Heater Flood (UJC 04282025)/` | `KEEP` |

### Personal / Family
| Item | Action |
|------|--------|
| `Ashley bday 2025/` | `KEEP` |
| `Mom's 73rd MOH birthday/` | `KEEP` |
| `To Fallon June 2025/` | `KEEP` |
| `20250615_WelcomeTeam_PJ_LB (CCC_FathersDay)/` | `KEEP` |
| `TerranceHalestory Mom interview 06042025/` | `KEEP` |
| `Ryan Mom & Dad Project/` | `KEEP` |

### Writing / Literary
| Item | Action |
|------|--------|
| `scrivener writing projects 2024 dropbox_sjl/` | `KEEP` |
| `Love & Let Live or Leave It & Lose It (Article)/` | `KEEP` |
| `Built For This_leadership monologues/` | `KEEP` |
| `Scrivener Projects Compiled 12202024.dmg` | `FLAG_REMOVE` — 450 MB DMG at project root, duplicate of above |

### Music / Performance
| Item | Action |
|------|--------|
| `Ladies of hip hop/` | `KEEP` |
| `Melonie's Musical Mondays Art & Images/` | `KEEP` |
| `KevOnStage 2025_03_09/` | `KEEP` |
| `Bounceback LKC/` | `KEEP` |
| `Father's Master Plan (Sample 2.0).mp3` | `KEEP` — loose file, route to music project folder |

### Legacy / Misc
| Item | Action |
|------|--------|
| `2017 Producer Folders/` | `ROUTE` → =ARCHIVES |
| `SJL PROJECTS/` | `AUDIT_NEEDED` — umbrella folder, may contain duplicates |
| `SJL ON GoogleDrive (Selective Sync Conflict)/` | `FLAG_REMOVE` — conflict copy |
| `FREE_Material_Resume_Ikonome/` | `FLAG_REMOVE` — tutorial/training material |
| `Desmond John Detective Resume 2022/` | `AUDIT_NEEDED` |
| `Smartphone Application Development/` | `FLAG_REMOVE` — tutorial/training |
| `Live Work Play Titles C4D/` | `KEEP` |
| `MAKING LOVE DECK/` | `KEEP` |
| `ronald Legerme Case/` | `KEEP` |
| `Imagine_SpeakEasy_Cannabis_Project_20210920 Folder/` | `KEEP` |
| `One Relationship Test/` | `AUDIT_NEEDED` |
| `Junecloud Automator Actions/` | `FLAG_REMOVE` — old Mac automation |
| `_SPENT 2022-2/` | `ROUTE` → =ARCHIVES/AMADAEUS_AND_ASHLEY |
| `Exports/` | `AUDIT_NEEDED` |
| `Project Files/` | `AUDIT_NEEDED` — generic name, needs inspection |
| `shannonjlove@icloud.com.cmlink` | `FLAG_REMOVE` — symlink stub |
| `shannonjlove@mac.com.cmlink` | `FLAG_REMOVE` — symlink stub |
| `shannonjlove@me.com.cmlink` | `FLAG_REMOVE` — symlink stub |
| `UNDERGROUND UPTOWN symlink.cmlink` | `FLAG_REMOVE` — symlink stub |

---

## 400000_AREAS — =AREAS_DRPBX_SJL

| Item | Action |
|------|--------|
| `Education & Learning (Dropbox_SJL)/` | `AUDIT_NEEDED` — likely contains tutorials → `FLAG_REMOVE` most |
| `Computer & Technology/` | `AUDIT_NEEDED` |
| `Entertainment/` | `AUDIT_NEEDED` |
| `Home & Family/` | `KEEP` |
| `Pixel Film studios FCPX plugins.zip` (556 MB) | `FLAG_REMOVE` — misplaced at AREAS root; re-download from vendor if needed |

---

## 000_LEGACY (root-level old folders)

| Item | Action |
|------|--------|
| `SJL Dropbox/` | `ROUTE` → =ARCHIVES — FCPX/C4D tutorials, Lynda course = `FLAG_REMOVE` |
| `Movies (DVDs)/` | `AUDIT_NEEDED` |
| `Movie Magic/` | `AUDIT_NEEDED` |
| `Mac/` | `AUDIT_NEEDED` |
| `TP Blackboxes/` | `AUDIT_NEEDED` |
| `Air Video Server HD.app/` | `FLAG_REMOVE` — old macOS app folder |
| `CheatSheet.app/` | `FLAG_REMOVE` — old macOS app folder |
| `Tags.app/` | `FLAG_REMOVE` — old macOS app folder |
| `AE_camera_morph_v1.1.1/` | `AUDIT_NEEDED` — AE plugin |
| `Corkulous App/` | `FLAG_REMOVE` — discontinued app |
| `SJL Folder/` | `AUDIT_NEEDED` — generic name |

---

## Summary — FLAG_REMOVE Items (immediate candidates)

Training / Tutorial content:
- `3D Scan - Human Model Bundle/` (INBOX)
- `3D Scan Store - Male Range of Movement/` (INBOX)
- `3D Perspective Plugin/` (INBOX)
- `Smartphone Application Development/` (PROJECTS)
- `FREE_Material_Resume_Ikonome/` (PROJECTS)
- `Junecloud Automator Actions/` (PROJECTS)
- `SJL Dropbox/Lynda - Camera Animation with CINEMA 4D` (legacy)
- `Education & Learning (Dropbox_SJL)/` contents — most
- `get_latest_files_from_trickster.alfredworkflow` (INBOX)

App/System junk:
- `Air Video Server HD.app/`, `CheatSheet.app/`, `Tags.app/`, `Corkulous App/`
- `.tags_and_ratings.plist` (110 MB), `._StellarVolumeOptimizer.dmg`, `._Dear Evan Hansen.mp4`

Duplicate / Conflict copies:
- `SJL ON GoogleDrive (Selective Sync Conflict)/`
- `_AREAS_DRPBX_SJL/` inside INBOX
- `.cmlink` stub files (×4)
- `Scrivener Projects Compiled 12202024.dmg` (450 MB — superseded by folder)

Storage hogs to remove:
- `InDesign_20_LS20.dmg` (1.5 GB at root)
- `Pixel Film studios FCPX plugins.zip` (556 MB in AREAS root)
- Estimated recoverable: ~2.5 GB minimum
