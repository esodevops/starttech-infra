# Infrastructure Architecture

## Overview

The StartTech infrastructure is built on AWS using Terraform for Infrastructure as Code (IaC).

## Components

- **VPC, Subnets, Security Groups**
- **EC2 Instances** (backend)
- **S3 & CloudFront** (frontend hosting)
- **NAT Gateway**
- **MongoDB Atlas** (managed database)
- **CloudWatch** (monitoring)

## Security

- IAM least-privilege policies for CI/CD
- Secure network segmentation
- Automated secret propagation

## CI/CD and Integration

- GitHub Actions for infrastructure deployment and automation
- Cross-repo secret propagation: Outputs from Terraform (e.g., backend URL, S3 bucket) are synced to the application repo as GitHub secrets for use in app deployment.
- MongoDB Atlas allowlist automation: CI workflow uses Atlas API keys (stored as secrets) to update the IP Access List with the current NAT Gateway IP and remove old ones automatically.
- Docker image flow: Backend Docker images are built and pushed to Docker Hub by the application repo, then pulled by EC2 instances using credentials from secrets.

## Diagrams

- (Add diagrams as needed)
