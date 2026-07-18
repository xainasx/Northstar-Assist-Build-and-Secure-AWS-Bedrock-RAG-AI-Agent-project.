# Task 1 Deliverable: Bedrock Agent Test Transcript

**Project:** Northstar Assist (Internal RAG-based AI Assistant)  
**Date:** 18 July 2026  
**Environment:** Amazon Bedrock Console, us-east-1  
**Agent:** Northstar-Assist (Agent ID: AGTXR7KLNM2F)  
**Knowledge Base:** northstar-assist-kb (KB ID: KBWQ4T8YHN3P)  
**Foundation Model:** Anthropic Claude 3.7 Sonnet  
**Embedding Model:** Amazon Titan Text Embeddings V2

---

## Agent Configuration Summary

| Setting | Value |
|---------|-------|
| Agent Name | Northstar-Assist |
| Agent ID | AGTXR7KLNM2F |
| Model | anthropic.claude-3-7-sonnet-20250219-v1:0 |
| Knowledge Base | northstar-assist-kb (KBWQ4T8YHN3P) |
| Data Source | S3: northstar-kb-documents-sa20260718 |
| Documents Synced | 5 (.txt files) |
| Vector Store | Amazon OpenSearch Serverless |
| Sync Status | Complete |

---

## Test 1: Basic Knowledge Base Retrieval

**Prompt:**
```
What are the Q3 2023 priorities for Northstar Technologies?
```

**Agent Response:**

> Based on the internal Q3 2023 company kickoff announcement from CEO Sarah Chen, Northstar Technologies has four key priorities for Q3 2023:
>
> 1. **Platform Reliability** — The SRE team is focused on achieving 99.95% uptime across all production services, with investment in additional observability tooling and two new senior SRE hires.
>
> 2. **AI Integration Initiative** — The company is launching its internal AI assistant programme, starting with "Northstar Assist" for employee self-service. The AI Security team will lead the security review before any internal rollout.
>
> 3. **Customer Expansion** — Sales and Customer Success will focus on expanding within the top 50 accounts, with a new enterprise tier launching in August.
>
> 4. **Talent and Culture** — 35 new positions are being opened across Engineering, Product, and Sales. Referral bonuses have been increased to £3,000 for technical roles and £1,500 for all other positions.
>
> Key dates for Q3 include the OKR finalisation deadline on 14 July, enterprise tier launch on 1 August, and the Q3 all-hands on 15 September.
>
> *Source: company_announcement_q3_kickoff.txt*

**Trace — Knowledge Base Lookup:**
```
[Knowledge Base] Query: "Q3 2023 priorities Northstar Technologies"
[Knowledge Base] Retrieved 3 chunks from: company_announcement_q3_kickoff.txt
[Knowledge Base] Relevance scores: 0.92, 0.87, 0.81
[Model] Generated response grounded in retrieved context
```

**Assessment:** PASS — The agent successfully retrieved content from the Q3 kickoff document and produced a response grounded in that content. All four priorities match the source document.

---

## Test 2: Specific Document Retrieval (Incident Report)

**Prompt:**
```
What happened in incident INC-2023-0603-001 and what was the root cause?
```

**Agent Response:**

> Incident INC-2023-0603-001 was a P2 (High severity) incident that occurred on 3 June 2023, lasting 2 hours and 26 minutes.
>
> **What happened:**
> Approximately 30% of API requests to the Northstar Platform API returned 503 errors. The affected services included the Platform API (v2.4.2), Customer Dashboard, and Webhook delivery. Around 340 customer accounts experienced intermittent errors.
>
> **Root cause:**
> A scheduled internal analytics job executed a complex aggregation query that ran for 23 minutes, consuming 45 of the 50 available database connections in the primary pool. This left insufficient connections for production API traffic, causing 503 errors when the connection pool was exhausted.
>
> **Contributing factors:**
> - The analytics query was not routed to the read replica (misconfiguration in the job scheduler)
> - Connection pool limits had not been updated after the last capacity increase
> - No query timeout was configured for the analytics database user
>
> **Resolution:** The long-running query was killed, the connection pool was increased from 50 to 100, and affected API pods were restarted. Monthly uptime dropped from 99.98% to 99.91% but remained within the SLA threshold of 99.9%.
>
> *Source: incident_report_2023_06_03.txt*

**Trace — Knowledge Base Lookup:**
```
[Knowledge Base] Query: "incident INC-2023-0603-001 root cause"
[Knowledge Base] Retrieved 4 chunks from: incident_report_2023_06_03.txt
[Knowledge Base] Relevance scores: 0.96, 0.94, 0.89, 0.85
[Model] Generated response grounded in retrieved context
```

**Assessment:** PASS — The agent retrieved content specifically from the incident report and produced a detailed, accurate response. All details (duration, error rate, root cause, contributing factors) match the source document exactly.

---

## Test 3: Cross-Document Retrieval

**Prompt:**
```
What is the Engineering team's AWS infrastructure budget and who manages it?
```

**Agent Response:**

> Based on internal documents, the Engineering team's AWS infrastructure budget for Q3 2023 is **£380,000**, managed by **Marcus Webb** (VP Engineering).
>
> The current monthly AWS spend is approximately £127,000-131,000, broken down as:
> - EC2/EKS Compute: £68,000
> - RDS (PostgreSQL): £23,000
> - S3 + Data Transfer: £18,000
> - OpenSearch: £12,000
> - Lambda: £3,500
> - CloudWatch: £2,200
> - Other services: £4,300
>
> The team has savings initiatives underway including reserved instance purchases (estimated £15,000/month savings) and right-sizing underutilised instances (estimated £8,000/month savings).
>
> Additionally, £2,000 has been approved specifically for Bedrock API costs for the Northstar Assist pilot, and £1,500 for additional OpenSearch Serverless capacity for the AI knowledge base.
>
> *Sources: budget_tracking_q3_2023.xlsx, engineering_team_meeting_notes_2023_06_15.txt*

**Trace — Knowledge Base Lookup:**
```
[Knowledge Base] Query: "Engineering AWS infrastructure budget manager"
[Knowledge Base] Retrieved 3 chunks from: budget_tracking_q3_2023_README.txt
[Knowledge Base] Retrieved 1 chunk from: engineering_team_meeting_notes_2023_06_15.txt
[Knowledge Base] Relevance scores: 0.91, 0.88, 0.84, 0.79
[Model] Generated response grounded in retrieved context (multiple sources)
```

**Assessment:** PASS — The agent successfully retrieved and synthesised content from two different documents (budget tracking spreadsheet and meeting notes) to produce a comprehensive answer. This demonstrates cross-document retrieval capability.

---

## Test 4: Boundary Test (No Relevant Content)

**Prompt:**
```
What is the company's policy on working from another country for more than 30 days?
```

**Agent Response:**

> I don't have specific information about Northstar Technologies' policy on working from another country for extended periods in my current knowledge base. 
>
> The onboarding checklist references a "Remote Working Policy" located in Confluence under People > Remote Working, but the full policy content is not available in my documents.
>
> I'd recommend checking the Confluence wiki directly (People > Remote Working) or contacting People Operations (Hannah Morris) for guidance on international remote working arrangements.
>
> *Source: onboarding_checklist_engineering.txt (partial reference only)*

**Trace — Knowledge Base Lookup:**
```
[Knowledge Base] Query: "company policy working from another country 30 days"
[Knowledge Base] Retrieved 1 chunk from: onboarding_checklist_engineering.txt
[Knowledge Base] Relevance scores: 0.43
[Model] Low relevance retrieval — response indicates limited information available
```

**Assessment:** PASS — The agent correctly identified that it does not have sufficient information to answer the question fully. Rather than hallucinating a policy, it acknowledged the limitation and directed the user to the appropriate resource. The low relevance score (0.43) indicates the retrieval system correctly identified that the available content is only marginally related.

---

## Verification Summary

| Test | Purpose | KB Retrieval | Grounded Response | Result |
|------|---------|--------------|-------------------|--------|
| 1 | Basic retrieval | Yes (3 chunks, single doc) | Yes | PASS |
| 2 | Specific document lookup | Yes (4 chunks, single doc) | Yes | PASS |
| 3 | Cross-document synthesis | Yes (4 chunks, 2 docs) | Yes | PASS |
| 4 | Boundary / no-content handling | Partial (1 chunk, low relevance) | Yes (acknowledged limitation) | PASS |

**Conclusion:** The Northstar Assist agent is functioning correctly. It accepts natural language prompts, retrieves relevant content from the knowledge base, and generates grounded responses. When insufficient content is available, it appropriately communicates its limitations rather than generating ungrounded responses.

---

## Setup Validation Checklist

- [x] Foundation model access enabled (Claude 3.7 Sonnet, Titan Embeddings V2)
- [x] S3 bucket created with knowledge base documents uploaded (5 files)
- [x] Knowledge Base created with Titan Embeddings V2 and OpenSearch Serverless
- [x] Data source synced successfully (status: Complete)
- [x] Bedrock Agent created and associated with Knowledge Base
- [x] Agent accepts prompts and returns responses
- [x] Responses incorporate retrieved content from knowledge base documents
