# Infrastructure GUI compatibility review

Date: 2026-10-31
Status: Proposed reference design; not a deployment record.

## Recommended layers

| Layer | Proposed choice | Operating rule |
|---|---|---|
| Launcher | Homer | Private, mobile-friendly links; no privileged socket or management credentials. |
| Host administration | Cockpit per host | Separate host sessions; authenticate to each host. |
| Podman visibility | cockpit-podman | Verify the service-owning user's rootless workloads are visible. |
| Lifecycle | Reviewed systemd/Quadlet definitions for Quadlet-managed services | Preserve the existing workload manager until a planned migration is validated. |
| Availability | Existing availability monitor | Check endpoints and heartbeats separately from functional readiness. |
| Metrics | Small Netdata pilot | Establish collection coverage, retention, resource budget, and access restrictions. |
| Workflow health | Sanitized read-only status feed | Show backlog, failed stages, stale observations, and recovery links. |

## Compatibility corrections

Cockpit's multi-machine feature is deprecated as of version 322. Use separate host links instead of depending on that feature.

Portainer's documented Podman support excludes official rootless support. Evaluate the installed OS/runtime combination before adopting it as the primary control plane.

Dockge documents Podman requirements, but its management model is Compose. Compose support does not establish Quadlet lifecycle compatibility. Evaluate additional tools only against a specific unmet requirement.

Homer connectivity checks do not establish complete service or workflow health. Keep management tokens out of browser-delivered configuration. Use a read-only backend or precomputed sanitized status for sensitive integrations.

Netdata parent aggregation is optional and distinct from Netdata Cloud. Configure private connectivity, source restrictions, authentication, and encryption.

## Operational sequence

1. Discover actual service host, runtime, service account, lifecycle manager, volumes, ingress, and backup policy.
2. Resolve conflicting documentation using observed configuration and approved release evidence.
3. Preserve existing working Compose stacks while reviewing a Quadlet target; avoid two managers controlling one service.
4. Pilot a launcher and monitoring without changing existing workloads.
5. Verify mobile access, unauthorized access rejection, stale-state behavior, and resource usage.
6. Release deployment artifacts through the approved executable registry with backup, rollback, and read-back checks.

This document does not establish current host roles, runtime state, or deployment approval. Keep private inventories and internal operational evidence in private repositories. Apply the existing approval policy before production changes.

## References

- [Cockpit feature documentation](https://cockpit-project.org/guide/latest/features.html)
- [Cockpit Podman](https://github.com/cockpit-project/cockpit-podman)
- [Portainer Podman requirements](https://docs.portainer.io/admin/environments/add/podman)
- [Dockge README](https://github.com/louislam/dockge/blob/master/README.md)
- [Homer configuration](https://github.com/bastienwirtz/homer/blob/main/docs/configuration.md)
- [Netdata parent-child configuration](https://learn.netdata.cloud/docs/netdata-parents/parent-child-configuration-reference)

References checked 2026-10-31. Product support statements must be rechecked at implementation.
