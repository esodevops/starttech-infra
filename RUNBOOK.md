# Infrastructure Operations & Troubleshooting Runbook

## Common Operations

- **Deploy Infrastructure:** Use `deploy-infrastructure.sh` in `scripts/` or CI/CD pipeline.
- **Cleanup Infrastructure:** Use `cleanup-infrastructure.sh` in `scripts/`.
- **Monitor:** Review CloudWatch dashboards and alarms in `monitoring/`.

## Troubleshooting

- **Terraform Errors:**
  - Check logs and state in `terraform/`
  - Validate AWS credentials and permissions
- **Script Failures:**
  - Ensure required tools (jq, AWS CLI) are installed
  - Check script logs for error messages
- **Resource Issues:**
  - Use AWS Console for diagnostics
  - Review CloudWatch logs and alarms

