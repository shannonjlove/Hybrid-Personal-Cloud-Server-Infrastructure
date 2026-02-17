# Secrets Management

Centralized management of credentials, API keys, and sensitive configuration.

## Principles

- **Never commit secrets** to version control
- Use environment variables and .env files (gitignored)
- Rotate credentials on a regular schedule
- Separate secrets per environment (dev/staging/prod)

## Files (Planned)

- .env.example templates (sanitized)
- Secret rotation scripts
- Vault integration configs
- SSH key management procedures

---
*CRITICAL: No real credentials, API keys, tokens, or private keys should ever be stored in this repository.*
