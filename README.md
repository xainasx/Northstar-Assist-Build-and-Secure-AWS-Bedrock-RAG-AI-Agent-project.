# Northstar Assist: AI Security Engineer Project

## Overview

This project covers the deployment, hardening, and validation of **Northstar Assist**, a retrieval-augmented generation (RAG) agent built on AWS Bedrock. The role is AI Security Engineer at Northstar Technologies, preparing the system for a secure production rollout.

## Project Structure

```
northstar-assist-security/
├── README.md                          # This file
├── starter/                           # Starter materials and templates
│   ├── ML-BOM_Template.md             # Blank template for AI asset inventory
│   ├── STRIDE-ML_Template.md          # Blank template for threat model
│   ├── Project Notes/
│   │   └── Northstar_Assist_Lab_Notes.md  # Lab reference (console paths, CLI commands, troubleshooting)
│   └── northstar-knowledge-base/
│       ├── txt/                        # Documents to upload to S3 for the Knowledge Base
│       │   ├── company_announcement_q3_kickoff.txt
│       │   ├── engineering_team_meeting_notes_2023_06_15.txt
│       │   ├── incident_report_2023_06_03.txt
│       │   ├── onboarding_checklist_engineering.txt
│       │   └── release_notes_v2.5.0.txt
│       └── xlsx/
│           └── budget_tracking_q3_2023_README.txt
└── deliverables/                       # Completed project deliverables
    ├── ML-BOM_Northstar_Assist.md      # Task 2: AI Asset Inventory
    ├── STRIDE-ML_Northstar_Assist.md   # Task 3: Threat Model
    ├── IAM_Hardening_Summary.md        # Task 4: Least-Privilege Access Controls
    ├── Safety_Controls_Description.md  # Task 5: Bedrock Guardrails Configuration
    ├── Monitoring_Plan_and_Incident_Response.md  # Task 6: Monitoring + IR Playbook
    └── Launch_Readiness_Report.md      # Task 7: Launch-Readiness Report
```

## Tasks

| Task | Description | Deliverable |
|------|-------------|-------------|
| 1 | Configure a Bedrock Agent with a Knowledge Base | Screenshot / test transcript (capture during live deployment) |
| 2 | Create an AI Asset Inventory (ML-BOM) | `deliverables/ML-BOM_Northstar_Assist.md` |
| 3 | Threat Model the Agent and Retrieval Flow | `deliverables/STRIDE-ML_Northstar_Assist.md` |
| 4 | Apply Least-Privilege Access Controls | `deliverables/IAM_Hardening_Summary.md` |
| 5 | Configure Safety and Response Controls | `deliverables/Safety_Controls_Description.md` |
| 6 | Define Monitoring and Incident Response Readiness | `deliverables/Monitoring_Plan_and_Incident_Response.md` |
| 7 | Validate Controls and Produce Launch-Readiness Report | `deliverables/Launch_Readiness_Report.md` |

## Prerequisites

- AWS account with Bedrock, S3, OpenSearch Serverless, CloudWatch, and IAM access
- Foundation model access enabled: Claude 3.7 Sonnet + Amazon Titan Text Embeddings V2
- AWS CLI configured (optional but recommended)

## Quick Start

1. Review `starter/Project Notes/Northstar_Assist_Lab_Notes.md` for setup guidance
2. Upload `starter/northstar-knowledge-base/txt/` files to your S3 bucket
3. Create the Knowledge Base and Agent in the Bedrock console
4. Work through Tasks 1 to 7 in order
5. Deliverables are pre-completed in `deliverables/` for reference

## Estimated AWS Cost

Under $5 if resources are cleaned up promptly after use. See Lab Notes for cleanup checklist.
