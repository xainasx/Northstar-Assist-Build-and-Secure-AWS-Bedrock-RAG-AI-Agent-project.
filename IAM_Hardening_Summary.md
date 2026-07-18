# IAM Hardening Summary: Northstar Assist

**Project:** Northstar Assist (Internal RAG-based AI Assistant)  
**Prepared by:** AI Security Engineer  
**Date:** 18 July 2026  
**Version:** 1.0  
**Classification:** Internal, Confidential

---

## 1. Overview

This document summarises the IAM review and hardening performed on the Northstar Assist system. The objective is to ensure all roles follow the principle of least privilege: each role should have only the minimum permissions required to perform its function, scoped to the specific resources it needs.

---

## 2. Roles Reviewed

| Role | Purpose | Created By |
|------|---------|------------|
| AmazonBedrockExecutionRoleForAgents_northstar | Agent execution: invoke model, query KB | Bedrock console (auto-created) |
| AmazonBedrockExecutionRoleForKnowledgeBase_northstar | KB operations: read S3, invoke embeddings, write to OpenSearch | Bedrock console (auto-created) |

---

## 3. Agent Execution Role: Before and After

### 3.1 Original Permissions (Before Hardening)

The default role created by the Bedrock console typically includes overly broad permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockAgentInvokeModel",
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "*"
    },
    {
      "Sid": "BedrockAgentRetrieve",
      "Effect": "Allow",
      "Action": "bedrock:Retrieve",
      "Resource": "*"
    }
  ]
}
```

**Trust Policy (unchanged):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "123456789012"
        },
        "ArnLike": {
          "aws:SourceArn": "arn:aws:bedrock:us-east-1:123456789012:agent/*"
        }
      }
    }
  ]
}
```

### 3.2 Issues Identified

| # | Issue | Risk |
|---|-------|------|
| 1 | `bedrock:InvokeModel` with `Resource: "*"` | Agent role can invoke ANY model in the account (including expensive or inappropriate models) |
| 2 | `bedrock:Retrieve` with `Resource: "*"` | Agent role can query ANY knowledge base in the account, not just Northstar Assist's KB |
| 3 | No condition keys restricting invocation context | Role could be used outside the intended agent if credentials were compromised |

**What an attacker could do with the original role:**
- Invoke any foundation model in the account (cost abuse, access to models not intended for this use case)
- Query any knowledge base in the account (access documents from other projects or teams)
- No resource-level boundary to contain lateral movement

### 3.3 Hardened Permissions (After)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "InvokeNorthstarModel",
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-7-sonnet-20250219-v1:0"
      ]
    },
    {
      "Sid": "RetrieveFromNorthstarKB",
      "Effect": "Allow",
      "Action": "bedrock:Retrieve",
      "Resource": [
        "arn:aws:bedrock:us-east-1:123456789012:knowledge-base/KB_NORTHSTAR_ID"
      ]
    }
  ]
}
```

### 3.4 Rationale for Changes

| Change | Rationale |
|--------|-----------|
| Scoped `InvokeModel` to specific model ARN | The agent only needs Claude 3.7 Sonnet. Restricting to this ARN prevents cost abuse (invoking expensive models) and limits blast radius if the role is compromised. |
| Scoped `Retrieve` to specific KB ARN | The agent should only access the Northstar Assist knowledge base. Wildcard access to all KBs would allow cross-project data access. |
| Removed wildcard resources entirely | Wildcards violate least-privilege and expand the attack surface unnecessarily. |

---

## 4. Knowledge Base Service Role: Before and After

### 4.1 Original Permissions (Before Hardening)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::*",
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Sid": "BedrockEmbeddings",
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "*"
    },
    {
      "Sid": "OpenSearchAccess",
      "Effect": "Allow",
      "Action": "aoss:APIAccessAll",
      "Resource": "*"
    }
  ]
}
```

### 4.2 Issues Identified

| # | Issue | Risk |
|---|-------|------|
| 1 | S3 access uses `arn:aws:s3:::*` (all buckets) | KB role can read objects from ANY S3 bucket in the account |
| 2 | `bedrock:InvokeModel` with `Resource: "*"` | Can invoke any model, not just the embedding model |
| 3 | `aoss:APIAccessAll` with `Resource: "*"` | Full access to all OpenSearch Serverless collections |

**What an attacker could do with the original role:**
- Read any object in any S3 bucket in the account (data exfiltration across unrelated projects)
- Invoke any Bedrock model (cost abuse, potential misuse of generative models)
- Access any OpenSearch Serverless collection (read/write to other teams' vector stores)

### 4.3 Hardened Permissions (After)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ReadNorthstarKBBucket",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::northstar-kb-documents-UNIQUE_ID/*"
    },
    {
      "Sid": "S3ListNorthstarKBBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::northstar-kb-documents-UNIQUE_ID",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["*"]
        }
      }
    },
    {
      "Sid": "InvokeEmbeddingModelOnly",
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
    },
    {
      "Sid": "OpenSearchNorthstarCollection",
      "Effect": "Allow",
      "Action": "aoss:APIAccessAll",
      "Resource": "arn:aws:aoss:us-east-1:123456789012:collection/COLLECTION_ID"
    }
  ]
}
```

### 4.4 Rationale for Changes

| Change | Rationale |
|--------|-----------|
| Scoped S3 access to specific bucket ARN | The KB only needs to read from its own document bucket. Wildcard bucket access allows reading credentials, logs, or data from unrelated services. |
| Scoped `InvokeModel` to Titan Embeddings V2 only | The KB service only needs to generate embeddings. It should not be able to invoke Claude or other generative models. |
| Scoped OpenSearch access to specific collection ARN | The KB writes to one collection. Wildcard access would allow reading or corrupting other teams' vector data. |
| Separated GetObject and ListBucket into distinct statements | Follows AWS best practice for S3 permission clarity. |

---

## 5. Comparison: Attack Surface Before vs After

| Scenario | Before Hardening | After Hardening |
|----------|-----------------|-----------------|
| Compromised agent role invokes unrelated model | Possible (any model) | Blocked (only Claude 3.7 Sonnet allowed) |
| Compromised agent role queries another team's KB | Possible (any KB) | Blocked (only Northstar KB allowed) |
| Compromised KB role reads another team's S3 data | Possible (any bucket) | Blocked (only northstar-kb-documents bucket) |
| Compromised KB role invokes Claude for generation | Possible (any model) | Blocked (only Titan Embeddings allowed) |
| Compromised KB role accesses other OpenSearch collections | Possible (any collection) | Blocked (only Northstar collection) |
| Cost impact of credential compromise | Unlimited model invocations | Limited to specific model at controlled volume |

---

## 6. Additional IAM Recommendations

| # | Recommendation | Priority | Status |
|---|---------------|----------|--------|
| 1 | Enable CloudTrail logging for all IAM and Bedrock API calls | High | Enabled |
| 2 | Set a permissions boundary on both roles to prevent privilege escalation | Medium | Recommended |
| 3 | Enable AWS IAM Access Analyzer to detect unused permissions | Medium | Recommended |
| 4 | Review roles quarterly for permission drift | Low | Scheduled |
| 5 | Add condition key `aws:SourceArn` to KB role trust policy to restrict which KB can assume it | Medium | Recommended |
| 6 | Consider SCPs at the OU level to deny bedrock:* to all roles except known Bedrock service roles | Low | Future consideration |

---

## 7. How to Apply These Changes

### Via AWS Console:
1. Navigate to **IAM > Roles**
2. Search for "Bedrock" to find the agent and KB roles
3. Select the role > **Permissions** tab > click the policy name
4. Choose **Edit policy** > switch to JSON editor
5. Replace with the hardened policy above (substituting your actual resource ARNs)
6. **Review and save**

### Via AWS CLI:
```bash
# Get current policy (identify the policy name first)
aws iam list-role-policies --role-name AmazonBedrockExecutionRoleForAgents_northstar

# Update inline policy
aws iam put-role-policy \
  --role-name AmazonBedrockExecutionRoleForAgents_northstar \
  --policy-name BedrockAgentPolicy \
  --policy-document file://hardened-agent-policy.json

# Verify
aws iam get-role-policy \
  --role-name AmazonBedrockExecutionRoleForAgents_northstar \
  --policy-name BedrockAgentPolicy
```

---

## 8. Verification

After applying changes, verify the agent still functions:
1. Open the Bedrock Agent test console
2. Submit a query that requires KB retrieval (e.g., "What are the Q3 priorities?")
3. Confirm the response includes retrieved content
4. Check CloudTrail for any AccessDenied events (indicating over-restriction)

If the agent fails after hardening, check:
- Model ARN matches the exact model version configured in the agent
- KB ARN matches the knowledge base attached to the agent
- OpenSearch collection ID matches the one created by the KB wizard

---

## 9. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 18 July 2026 | AI Security Engineer | Initial IAM hardening review and implementation |
