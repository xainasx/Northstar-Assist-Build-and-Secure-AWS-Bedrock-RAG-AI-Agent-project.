# Northstar Assist Lab Notes

**Project:** Northstar Assist (Internal RAG-based AI Assistant)  
**Environment:** AWS (us-east-1)  
**Last Updated:** 18 July 2026

---

## Lab Environment Summary

This document provides reference notes for the Northstar Assist lab environment. Use it as a quick-reference guide when configuring AWS resources.

---

## AWS Resource Names and IDs

Fill these in as you create resources during setup:

| Resource | Name / ID | Notes |
|----------|-----------|-------|
| S3 Bucket | northstar-kb-docs-sa2026 | Knowledge base document storage |
| Knowledge Base | northstar-assist-kb | Unstructured Vector Store type |
| Knowledge Base Data Source | northstar-docs | S3 data source, linked to bucket above |
| Bedrock Agent | Northstar-Assist | Created via Agents Classic |
| Agent ID | D5ITRLYLVW | |
| Agent ARN | arn:aws:bedrock:us-east-1:248094863832:agent/D5ITRLYLVW | |
| Agent Alias | TestAlias: Working draft | Used for testing |
| Foundation Model | Amazon Nova (ODT Channel) | |
| Embedding Model | amazon.titan-embed-text-v2:0 | Used by Knowledge Base |
| OpenSearch Collection | Managed by Bedrock | Auto-created by KB wizard |
| Agent Execution Role | AmazonBedrockExecutionRoleForAgents_G5R7WIILSP | Auto-created |
| KB Service Role | AmazonBedrockExecutionRoleForKnowledgeBase_e5pgs | Auto-created |
| Guardrail | | Created in Task 5 |
| Guardrail Version | | Use specific version, not DRAFT |
| CloudWatch Log Group | /aws/bedrock/modelinvocations | For model invocation logging |
| Account ID | 248094863832 | |
| IAM User | Saniya | Under Jasmine management account |

---

## Region and Model Availability

- **Primary region:** us-east-1 (N. Virginia)
- Claude 3.7 Sonnet: Available in us-east-1, us-west-2, eu-west-1
- Amazon Nova Lite: Available in us-east-1
- Titan Text Embeddings V2: Available in all Bedrock regions

If Claude is not available in your region, use Amazon Nova Lite as the foundation model.

---

## Key Console Navigation Paths

| Task | AWS Console Path |
|------|-----------------|
| Model access | Bedrock > Model access > Manage model access |
| Create Knowledge Base | Bedrock > Knowledge bases > Create knowledge base |
| Sync Data Source | Bedrock > Knowledge bases > [KB name] > Data source > Sync |
| Create Agent | Bedrock > Agents > Create agent |
| Test Agent | Bedrock > Agents > [Agent name] > Test (right panel) |
| Create Guardrail | Bedrock > Guardrails > Create guardrail |
| Attach Guardrail to Agent | Bedrock > Agents > [Agent name] > Edit > Guardrails section |
| Enable Logging | Bedrock > Settings > Model invocation logging |
| View Logs | CloudWatch > Log groups > /aws/bedrock/modelinvocations |
| IAM Roles | IAM > Roles > Search for "Bedrock" |

---

## Knowledge Base Documents Included

The following documents are provided in `starter/northstar-knowledge-base/`:

| File | Type | Content Summary |
|------|------|-----------------|
| company_announcement_q3_kickoff.txt | Text | Q3 2023 all-hands announcement from CEO Sarah Chen; includes revenue figures, priorities, headcount |
| engineering_team_meeting_notes_2023_06_15.txt | Text | Engineering leadership meeting; discusses AI assistant project, infrastructure costs, hiring |
| incident_report_2023_06_03.txt | Text | P2 incident report; database connection pool exhaustion; contains names, technical details |
| onboarding_checklist_engineering.txt | Text | New starter onboarding; includes system names, access procedures, key contacts with emails |
| release_notes_v2.5.0.txt | Text | Platform release notes; CVE details, API endpoints, breaking changes |
| budget_tracking_q3_2023.xlsx | Spreadsheet | Engineering department budget; salary totals, AWS costs, headcount |

**Sensitive data present in these documents:**
- Employee names and email addresses (PII)
- Revenue and budget figures (financial)
- Infrastructure topology and costs (operational)
- Security incident details (security-sensitive)
- CVE identifiers and vulnerability descriptions (security-sensitive)

---

## Common Issues and Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Agent returns generic response, no KB content | Data source not synced | Navigate to KB > Data source > Sync |
| "Model access not available" error | Model access not approved | Check Bedrock > Model access; approval may take minutes |
| Agent creation fails with IAM error | Trust policy missing | Ensure role trusts bedrock.amazonaws.com |
| KB creation fails at OpenSearch step | Service-linked role missing | AWS creates this automatically; retry after 30 seconds |
| Guardrail not blocking test prompts | Guardrail using DRAFT version | Publish a numbered version and attach that to the agent |
| Logs not appearing in CloudWatch | Logging not enabled | Bedrock > Settings > Model invocation logging > Enable |
| Agent response says "I don't have access" | KB not attached to agent | Agent > Edit > Knowledge bases > Add |

---

## Useful AWS CLI Commands

```bash
# Verify your identity
aws sts get-caller-identity

# List Bedrock agents
aws bedrock-agent list-agents --region us-east-1

# List Knowledge Bases
aws bedrock-agent list-knowledge-bases --region us-east-1

# Get agent details
aws bedrock-agent get-agent --agent-id <AGENT_ID> --region us-east-1

# List IAM roles (filter for Bedrock)
aws iam list-roles --query "Roles[?contains(RoleName, 'Bedrock')]"

# Get role policy
aws iam list-attached-role-policies --role-name <ROLE_NAME>
aws iam get-role-policy --role-name <ROLE_NAME> --policy-name <POLICY_NAME>

# Upload documents to S3
aws s3 cp starter/northstar-knowledge-base/txt/ s3://northstar-kb-documents-<id>/ --recursive

# Check S3 bucket contents
aws s3 ls s3://northstar-kb-documents-<id>/

# Invoke agent (for testing via CLI)
aws bedrock-agent-runtime invoke-agent \
  --agent-id <AGENT_ID> \
  --agent-alias-id <ALIAS_ID> \
  --session-id "test-session-001" \
  --input-text "What are the Q3 priorities?" \
  --region us-east-1

# List guardrails
aws bedrock list-guardrails --region us-east-1

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/bedrock"
aws logs get-log-events --log-group-name "/aws/bedrock/modelinvocations" --log-stream-name <STREAM>
```

---

## Test Prompts for Baseline Validation (Task 1)

Use these prompts to verify the agent is working correctly before applying security controls:

1. **Basic retrieval test:** "What are the Q3 2023 priorities for Northstar Technologies?"
   - Expected: Response references Platform Reliability, AI Integration, Customer Expansion, Talent and Culture

2. **Specific document test:** "What happened in incident INC-2023-0603-001?"
   - Expected: Response describes the database connection pool exhaustion incident

3. **Cross-document test:** "Who is the VP of Engineering and what is their team's budget?"
   - Expected: Response mentions Marcus Webb and engineering budget figures

4. **Boundary test (no relevant content):** "What is the company's policy on remote working from another country?"
   - Expected: Response should indicate limited information or refer to policy documents not in the KB

---

## Estimated AWS Costs

| Service | Estimated Cost (for lab completion) |
|---------|-------------------------------------|
| Bedrock model invocations | < $2 (Claude 3.7 Sonnet, low volume testing) |
| OpenSearch Serverless | ~$1-2 (minimum OCU hours) |
| S3 | < $0.01 (minimal storage) |
| CloudWatch | < $0.50 (log ingestion) |
| **Total** | **< $5** |

**Important:** Delete OpenSearch Serverless collection and Bedrock resources after completing the project to avoid ongoing charges. OpenSearch Serverless has a minimum charge per OCU-hour even when idle.

---

## Cleanup Checklist (After Project Completion)

- [ ] Delete the Bedrock Agent
- [ ] Delete the Knowledge Base (this deletes the OpenSearch collection)
- [ ] Empty and delete the S3 bucket
- [ ] Delete custom IAM roles/policies created for the project
- [ ] Disable model invocation logging (or delete the log group)
- [ ] Delete the Guardrail
