# ML-BOM Template: AI Asset Inventory

**Project:** [Project Name]  
**Organisation:** [Organisation Name]  
**Prepared by:** [Your Name / Role]  
**Date:** [Date]  
**Version:** [Version Number]  
**Classification:** [Document Classification]

---

## 1. System Overview

[Provide a high-level description of the AI system, including its purpose, how components work together, and their distinct security failure modes.]

**Request flow:**
[Describe the end-to-end flow of a request through the system.]

---

## 2. AI Component Inventory

### 2.1 Foundation Model

| Field | Value |
|-------|-------|
| **Component Name** | |
| **Provider** | |
| **Model Type** | |
| **Architecture** | |
| **Model ID** | |
| **Intended Use** | |
| **Input Format** | |
| **Output Format** | |
| **Context Window** | |
| **Training Data** | [Document what is known and what is NOT known. If the provider does not disclose training data, note this as a finding.] |
| **Known Limitations** | |
| **Licensing** | |

### 2.2 Embedding Model

| Field | Value |
|-------|-------|
| **Component Name** | |
| **Provider** | |
| **Model Type** | |
| **Architecture** | |
| **Model ID** | |
| **Intended Use** | |
| **Input Format** | |
| **Output Format** | [Note: This is an encoder model producing vectors, not a generation model.] |
| **Training Data** | [Document what is known and what is NOT known.] |
| **Known Limitations** | |

### 2.3 Knowledge Base Data Source

| Field | Value |
|-------|-------|
| **Component Name** | |
| **Storage Service** | |
| **Document Types** | |
| **Content Classification** | |
| **Data Sensitivity** | |
| **Update Frequency** | |
| **Risks** | |

### 2.4 Vector Store

| Field | Value |
|-------|-------|
| **Component Name** | |
| **Provider** | |
| **Purpose** | |
| **Risks** | |

### 2.5 Orchestration Service

| Field | Value |
|-------|-------|
| **Component Name** | |
| **Provider** | |
| **Purpose** | |
| **Risks** | |

---

## 3. IAM Roles and Trust Boundaries

[Document all IAM roles, their permissions, and what could happen if each role were compromised.]

---

## 4. Data Flow and Trust Boundaries

[Include a diagram or description of trust boundaries across the system.]

---

## 5. Findings and Recommendations

| # | Finding | Severity | Recommendation |
|---|---------|----------|----------------|
| 1 | | | |

---

## 6. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| | | | |
