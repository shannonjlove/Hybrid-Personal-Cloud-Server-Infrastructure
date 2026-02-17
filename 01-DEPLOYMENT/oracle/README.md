# Oracle Cloud sOs Instance Deployment

## Server Details
- OS: Ubuntu
- IP Address: 150.136.77.26
- Hostname: sOs
- Region: us-ashburn-1
- Tailscale IP: 100.67.229.94
- Primary SSH Key: oracle_rsa_new (RSA 4096)

## Deployment Files
This folder will contain the necessary configuration and deployment files for the Oracle Cloud sOs instance, including but not limited to:
- OCI CLI configuration templates
- Terraform definitions
- ARM capacity provisioning scripts
- Security list rules
- Tailscale setup configurations

> **Note:** No real credentials or sensitive information should be stored in this repository.

## Quick Connect Commands

### Connect via Tailscale
```bash
ssh ubuntu@100.67.229.94
```

### Connect via Direct IP
```bash
ssh ubuntu@150.136.77.26
```

## Additional Notes
- Ensure your Tailscale client is authorized and connected for Tailscale access.
- All deployment automation should be idempotent and secure.