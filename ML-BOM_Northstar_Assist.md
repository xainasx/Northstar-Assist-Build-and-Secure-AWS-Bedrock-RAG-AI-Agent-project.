# ML-BOM: Northstar Assist AI Asset Inventory

**Project:** Northstar Assist (Internal RAG-based AI Assistant)  
**Organisation:** Northstar Technologies  
**Prepared by:** AI Security Engineer  
**Date:** 18 July 2026  
**Version:** 1.0  
**Classification:** Internal, Confidential

---

## 1. System Overview

Northstar Assist is a retrieval-augmented generation (RAG) system deployed on AWS using Amazon Bedrock. The system accepts natural language questions from Northstar employees, retrieves relevant context from an internal knowledge base, and generates grounded answers using a large language model.

**Request flow:**

1. Employee submits a natural language question via the agent interface.
2. The Bedrock Agent receives the input and determines retrieval is needed.
3. The agent queries the Knowledge Base, which uses Amazon Titan Text Embeddings V2 to embed the query.
4. OpenSearch Serverless performs a vector similarity search against pre-indexed document chunks.
5. Retrieved document chunks are injected into the model context alongside the user prompt.
6. Claude 3.7 Sonnet generates a response grounded in the retrieved context.
7. The response passes through Bedrock Guardrails (input/output filters) before being returned to the user.

**Distinct security failure modes by component:**

| Component | Failure Mode |
|-----------|-------------|
| Foundation Model (Claude 3.7 Sonnet) | Prompt injection, hallucination, data leakage via memorisation, refusal bypass |
| Embedding Model (Titan V2) | Adversarial embedding manipulation, semantic drift causing incorrect retrieval |
| Knowledge Base (S3 documents) | Indirect prompt injection via poisoned documents, stale/incorrect information |
| Vector Store (OpenSearch Serverless) | Unauthorised access to indexed content, index corruption |
| IAM Roles | Over-privileged access enabling lateral movement, credential exposure |
| Bedrock Agent | Instruction override, tool misuse, context window manipulation |

---

## 2. AI Component Inventory

### 2.1 Foundation Model

| Field | Value |
|-------|-------|
| **Component Name** | Claude 3.7 Sonnet |
| **Provider** | Anthropic (accessed via Amazon Bedrock) |
| **Model Type** | Large Language Model (LLM), decoder-only transformer |
| **Architecture** | Transformer-based autoregressive language model |
| **Model ID (Bedrock)** | anthropic.claude-3-7-sonnet-20250219-v1:0 |
| **Intended Use** | Generate natural language answers to employee questions, grounded in retrieved internal documents |
| **Input Format** | Text (natural language prompt with retrieved context) |
| **Output Format** | Text (natural language response) |
| **Context Window** | 200,000 tokens |
| **Training Data** | Not fully disclosed by Anthropic. Trained on a mixture of publicly available internet text, licensed datasets, and human feedback. Exact composition, cut-off date, and inclusion/exclusion criteria are not publicly documented. **This is a finding: training data provenance is opaque.** |
| **Known Limitations** | May hallucinate plausible but incorrect information; susceptible to prompt injection; cannot guarantee factual accuracy; may refuse legitimate queries if they superficially resemble harmful requests; no real-time knowledge |
| **Licensing** | Commercial use via AWS Bedrock service agreement; Anthropic's Acceptable Use Policy applies |
| **Version Pinning** | Pinned to specific model version via Bedrock model ID to avoid unexpected behaviour changes |

### 2.2 Embedding Model

| Field | Value |
|-------|-------|
| **Component Name** | Amazon Titan Text Embeddings V2 |
| **Provider** | Amazon (first-party Bedrock model) |
| **Model Type** | Text embedding model (encoder-only transformer) |
| **Architecture** | Encoder-only transformer producing fixed-dimensional dense vector representations |
| **Model ID (Bedrock)** | amazon.titan-embed-text-v2:0 |
| **Intended Use** | Convert text (document chunks and user queries) into vector embeddings for semantic similarity search |
| **Input Format** | Text (up to 8,192 tokens) |
| **Output Format** | Dense vector (1,024 dimensions by default; configurable to 256, 512, or 1,024) |
| **Training Data** | Not fully disclosed by Amazon. Trained on a broad corpus of text data. Exact composition not publicly documented. **Finding: training data provenance is partially opaque, though Amazon indicates it was trained on diverse multilingual text.** |
| **Known Limitations** | Embedding quality degrades for highly specialised jargon not represented in training data; adversarial inputs can produce misleading similarity scores; no semantic understanding of document structure |
| **Note** | This is NOT a generative model. It produces numerical vectors, not text. It cannot be directly "prompt injected" but can be manipulated through adversarial text to alter retrieval results. |

### 2.3 Knowledge Base Data Source

| Field | Value |
|-------|-------|
| **Component Name** | Northstar Internal Documents (Knowledge Base Source) |
| **Storage Service** | Amazon S3 |
| **Bucket Name** | northstar-kb-documents-[unique-id] |
| **Region** | us-east-1 |
| **Document Types** | .txt, .xlsx |
| **Document Count** | 6 documents (5 text, 1 spreadsheet) |
| **Content Classification** | Internal, Confidential (contains employee names, email addresses, budget figures, infrastructure details, security incident details) |
| **Data Sensitivity** | Medium-High. Documents contain: PII (names, emails), financial data (budgets, salaries), security information (incident details, infrastructure topology), internal process details |
| **Update Frequency** | Manual upload and sync; no automated ingestion pipeline |
| **Access Control** | S3 bucket policy restricting access to Knowledge Base service role |
| **Risks** | Indirect prompt injection if malicious content is uploaded; stale information if documents are not updated; sensitive data exposure through retrieval |

### 2.4 Vector Store

| Field | Value |
|-------|-------|
| **Component Name** | Amazon OpenSearch Serverless (Vector Search Collection) |
| **Provider** | AWS |
| **Purpose** | Store document embeddings and perform approximate nearest-neighbour (ANN) vector similarity search |
| **Index Type** | FAISS-based vector index (managed by OpenSearch Serverless) |
| **Dimensions** | 1,024 (matching Titan Embeddings V2 output) |
| **Access** | Managed internally by Bedrock Knowledge Base service; network policy restricts access |
| **Risks** | Unauthorised access to raw indexed content; index poisoning if source documents are compromised; collection deletion causing service outage |

### 2.5 Orchestration Service

| Field | Value |
|-------|-------|
| **Component Name** | Amazon Bedrock Agent |
| **Provider** | AWS |
| **Purpose** | Orchestrate the RAG flow: receive user input, invoke knowledge base retrieval, construct the augmented prompt, invoke the foundation model, return the response |
| **Agent ID** | [To be populated after deployment] |
| **Associated Knowledge Base** | [To be populated after deployment] |
| **Foundation Model** | Claude 3.7 Sonnet (configured in agent settings) |
| **Guardrails** | Bedrock Guardrails attached (see Task 5 deliverable) |
| **Session Management** | Bedrock-managed session state with configurable idle timeout |
| **Risks** | Instruction override via prompt injection; unintended tool invocation if action groups are added in future; session state manipulation |

---

## 3. IAM Roles and Trust Boundaries

### 3.1 Bedrock Agent Execution Role

| Field | Value |
|-------|-------|
| **Role Name** | AmazonBedrockExecutionRoleForAgents_[agent-id] |
| **Trusted Service** | bedrock.amazonaws.com |
| **Purpose** | Allows the Bedrock Agent to invoke the foundation model and query the knowledge base |
| **Required Permissions** | bedrock:InvokeModel (scoped to model ARN), bedrock:Retrieve (scoped to KB ARN) |
| **Risk if Compromised** | Attacker could invoke models or query knowledge base content outside normal application flow |

### 3.2 Knowledge Base Service Role

| Field | Value |
|-------|-------|
| **Role Name** | AmazonBedrockExecutionRoleForKnowledgeBase_[kb-id] |
| **Trusted Service** | bedrock.amazonaws.com |
| **Purpose** | Allows the Knowledge Base to read S3 documents, invoke the embedding model, and write to OpenSearch Serverless |
| **Required Permissions** | s3:GetObject (scoped to KB bucket), bedrock:InvokeModel (scoped to embedding model ARN), aoss:APIAccessAll (scoped to collection) |
| **Risk if Compromised** | Attacker could read all documents in the KB bucket, invoke embedding model for arbitrary text, access vector store data |

---

## 4. Data Flow and Trust Boundaries

```
┌─────────────────────────────────────────────────────────────────────┐
│ TRUST BOUNDARY 1: User Input (Untrusted)                            │
│                                                                     │
│   Employee ──── Natural Language Query ────►                        │
└─────────────────────────────────────────┬───────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│ TRUST BOUNDARY 2: Agent Orchestration (AWS-Managed)                 │
│                                                                     │
│   Bedrock Agent (receives input, orchestrates retrieval + generation)│
│   Guardrails applied here (input filter)                            │
└──────────┬──────────────────────────────┬───────────────────────────┘
           │                              │
           ▼                              ▼
┌──────────────────────┐    ┌─────────────────────────────────────────┐
│ TRUST BOUNDARY 3:    │    │ TRUST BOUNDARY 4: Knowledge Retrieval    │
│ Model Invocation     │    │ (Semi-Trusted)                           │
│                      │    │                                          │
│ Claude 3.7 Sonnet    │    │ S3 ► Titan Embeddings ► OpenSearch       │
│ (Anthropic-hosted    │    │ Retrieved chunks injected into context   │
│  via Bedrock)        │    │                                          │
└──────────┬───────────┘    └─────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────┐
│ TRUST BOUNDARY 5: Output (Guardrails applied, then returned)        │
│                                                                     │
│   Bedrock Guardrails (output filter) ────► Employee                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Findings and Recommendations

| # | Finding | Severity | Recommendation |
|---|---------|----------|----------------|
| 1 | Foundation model training data composition not disclosed by Anthropic | Medium | Document as accepted risk; monitor for unexpected model behaviours; maintain ability to switch models |
| 2 | Knowledge base contains PII and financial data | High | Implement data classification review before adding documents; apply PII detection in guardrails |
| 3 | Single IAM role used for both model invocation and KB retrieval | Medium | Verify least-privilege scoping (see Task 4) |
| 4 | No automated document scanning before S3 upload | Medium | Implement pre-upload review process to detect potential injection payloads |
| 5 | Embedding model training data partially opaque | Low | Accepted risk; Amazon-managed model with AWS support |

---

## 6. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 18 July 2026 | AI Security Engineer | Initial ML-BOM created |
