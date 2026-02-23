# Terraform Code Challenge

## Overview

This repository contains Terraform configuration to deploy an application on **Google Cloud Platform (GCP)**. The infrastructure includes:

- A VPC network with application and database subnets
- A GKE cluster with a managed node pool
- Cloud Run v2 services (API and frontend)
- Cloud Scheduler jobs for nightly report generation
- A Cloud SQL database instance
- A Cloud Storage bucket for static assets
- Dedicated service accounts per component

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ GCP Project                                                         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ VPC Network                                                  │   │
│  │                                                              │   │
│  │  ┌─────────────────────────────┐  ┌──────────────────────┐   │   │
│  │  │ App Subnet (10.0.1.0/24)    │  │ DB Subnet            │   │   │
│  │  │                             │  │ (10.0.2.0/24)        │   │   │
│  │  │  ┌───────────────────────┐  │  │                      │   │   │
│  │  │  │                       │  │  │  ┌────────────────┐  │   │   │
│  │  │  │      GKE Cluster      │  │  │  │   Cloud SQL    │  │   │   │
│  │  │  │                       │  │  │  │                │  │   │   │
│  │  │  └───────────────────────┘  │  │  └────────────────┘  │   │   │
│  │  └─────────────────────────────┘  └──────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────┐                                   │
│  │ Cloud Run                    │                                   │
│  │                              │◄── Cloud Scheduler                │
│  │  ┌──────────┐  ┌──────────┐  │                                   │
│  │  │ Frontend │◄─► API      │──┼──► Cloud SQL                      │
│  │  └──────────┘  └──────────┘  │                                   │
│  └──────────────────────────────┘                                   │
│                                                                     │
│  ┌──────────────────┐                                               │
│  │ Cloud Storage    │                                               │
│  │ (Reports/Assets) │                                               │
│  └──────────────────┘                                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**However, the configuration contains several issues that prevent it from being successfully planned or applied.** Your task is to identify and fix all of the issues using Terraform's built-in tooling and code review.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) v1.8.0 or later installed locally
- No GCP credentials or project are required

## Instructions

Use Terraform's built-in tooling to systematically identify and resolve the issues in this configuration. Follow this workflow:

### Step 1 — Format

Run `terraform fmt` to detect formatting and syntax errors.

```bash
terraform fmt
```

Fix any errors reported, then re-run `terraform fmt` until it succeeds.

### Step 2 — Initialize

Run `terraform init` to download the required providers.

```bash
terraform init
```

### Step 3 — Validate

Run `terraform validate` to check the configuration for internal consistency, dependency issues, and correctness against the provider schema.

```bash
terraform validate
```

Terraform may stop at the first error it encounters. After fixing each issue, re-run `terraform validate` to uncover subsequent errors. Repeat until validation passes.

### Step 4 — Improvements

Once the configuration is valid, implement the following improvements:

1.  **Remote State Configuration**
    - The current project uses local state. Update the configuration to use a **GCS backend** for remote state storage.
    - Ensure the configuration block is present (the actual bucket does not need to exist for this exercise).

2.  **Refactor into Module**
    - Move the **VPC/Networking** logic into a module.
    - Update the root `main.tf` to call this module.

3.  **Secrets Management**
    - Locate the **API** service definition in `main.tf`.
    - Observe that the `DB_PASSWORD` is currently hardcoded as a plain-text environment variable.
    - Update the code to reference a secret from **Google Secret Manager** instead.
    - Assume a secret named `db-password` already exists in the project and contains the correct value.
