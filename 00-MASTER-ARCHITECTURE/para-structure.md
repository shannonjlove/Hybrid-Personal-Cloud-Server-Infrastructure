# PARA Structure

## Digital Organization Methodology

This infrastructure follows the PARA methodology (Projects, Areas, Resources, Archive) across all systems  from file storage to container organization to automation rules.

### PARA Categories

| Category | Definition | Examples |
|----------|-----------|----------|
| **Projects** | Active work with a deadline | Fellowship applications, TagBack development |
| **Areas** | Ongoing responsibilities | Server maintenance, cloud accounts, production work |
| **Resources** | Reference material | Technical docs, templates, scripts |
| **Archive** | Inactive/completed items | Past projects, deprecated configs |

### Application Across Systems

**File Storage**: Hazel rules (11 PARA-based) automatically route files into the correct category based on naming conventions and metadata.

**Naming Convention**: `YYYY-MM-DD_HH-MM_category-subcategory_description_UUID24.ext`

**Automation**: 8 shell scripts + LaunchAgents for scheduled PARA-based file routing and organization.

**Cloud Consolidation**: Reducing 6 cloud storage accounts to 2, organized by PARA structure.

### Tools

- **Hazel**: macOS file automation with PARA-based rules
- **DeltaWalker**: File comparison/merge for consolidation
- **Resilio Sync**: P2P sync between devices
- **Hookmark**: Deep linking with metadata tags

---
*Last updated: February 2026*
