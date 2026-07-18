# Monitoring Plan and Incident Response Playbook: Northstar Assist

**Project:** Northstar Assist (Internal RAG-based AI Assistant)  
**Prepared by:** AI Security Engineer  
**Date:** 18 July 2026  
**Version:** 1.0  
**Classification:** Internal, Confidential

---

## Part 1: Monitoring Plan

### 1.1 Overview

This monitoring plan defines the logs, metrics, and alerts necessary to observe Northstar Assist's behaviour in production. It goes beyond standard infrastructure health metrics to include AI-specific signals that detect misuse, drift, and security events unique to a RAG-based agent system.

### 1.2 Logging Configuration

#### Model Invocation Logging

| Field | Value |
|-------|-------|
| **Service** | Amazon Bedrock Model Invocation Logging |
| **Log Destination** | CloudWatch Logs |
| **Log Group** | /aws/bedrock/modelinvocations |
| **Retention** | 90 days (adjustable based on compliance requirements) |
| **Content Logged** | Input prompts, output responses, model ID, token counts, latency, request metadata |
| **Sensitive Data** | Enable input/output logging for security monitoring; restrict log access to Security and SRE teams via IAM |

**How to enable:**
1. Navigate to **Bedrock > Settings > Model invocation logging**
2. Select CloudWatch Logs as destination
3. Choose or create log group `/aws/bedrock/modelinvocations`
4. Enable both input and output data logging
5. Configure the IAM role for log delivery

#### Guardrail Logging

| Field | Value |
|-------|-------|
| **Source** | Bedrock Guardrail trace data |
| **Content** | Guardrail intervention events: which filter triggered, the action taken (BLOCKED, ANONYMISED), the content category |
| **Access** | Available in agent trace output and CloudWatch when model invocation logging is enabled |

#### CloudTrail (API-level Audit)

| Field | Value |
|-------|-------|
| **Events** | All Bedrock API calls (InvokeModel, InvokeAgent, Retrieve, CreateAgent, UpdateAgent, etc.) |
| **Purpose** | Detect administrative changes to agent configuration, unauthorised API calls, IAM anomalies |
| **Retention** | 365 days (S3 bucket with lifecycle policy) |

---

### 1.3 Metrics and Signals

#### Standard Infrastructure Metrics

| Metric | Source | Purpose | Threshold |
|--------|--------|---------|-----------|
| Agent invocation count | CloudWatch (Bedrock) | Track usage volume | Baseline + alert on >200% spike |
| Invocation latency (P95) | CloudWatch (Bedrock) | Detect performance degradation | Alert if P95 > 10 seconds |
| Throttling events | CloudWatch (Bedrock) | Detect capacity issues | Alert if > 5 per minute |
| S3 access events | CloudTrail | Detect unauthorised KB document access | Alert on non-service-role access |

#### AI-Specific Metrics

| Metric | Source | Purpose | Threshold |
|--------|--------|---------|-----------|
| **Guardrail PROMPT_ATTACK interventions** | Guardrail trace logs | Detect active injection attempts | Alert: > 5 per hour from single session |
| **Guardrail topic policy blocks** | Guardrail trace logs | Detect misuse patterns (repeated off-topic queries) | Alert: > 10 per hour from single session |
| **PII detection events** | Guardrail trace logs | Monitor for sensitive data in responses | Alert: > 20 per day (indicates KB content issue) |
| **Zero-retrieval responses** | Agent trace (knowledge base results) | Detect queries where no KB chunks were retrieved; high hallucination risk | Alert: > 30% of queries in a 1-hour window |
| **Token count anomalies** | Model invocation logs (input/output token counts) | Detect context manipulation or excessively long sessions | Alert: single response > 4,000 tokens (3x normal average) |
| **Grounding check failures** | Guardrail trace logs | Detect ungrounded/hallucinated responses | Alert: > 10% failure rate in 1-hour window |
| **Session length anomalies** | Agent session metadata | Detect automated or abusive sessions | Alert: > 50 turns in single session |
| **Unique user session count** | Agent invocation metadata | Track adoption and detect bot-like access patterns | Monitor trend; alert on > 500% spike |

---

### 1.4 Alert Definitions

#### Alert 1: Prompt Injection Campaign (Primary Alert)

| Field | Value |
|-------|-------|
| **Signal** | PROMPT_ATTACK guardrail interventions |
| **Condition** | More than 5 PROMPT_ATTACK blocks within 1 hour from a single session ID |
| **Severity** | P3 (High) |
| **Notification** | PagerDuty alert to Security on-call; Slack notification to #security |
| **Rationale** | A single blocked injection attempt is expected (curiosity). Repeated attempts from one session indicate deliberate adversarial behaviour that warrants investigation. |
| **Response** | Follow Incident Response Playbook (Part 2 of this document) |

#### Alert 2: Mass Injection Signal

| Field | Value |
|-------|-------|
| **Signal** | PROMPT_ATTACK guardrail interventions |
| **Condition** | More than 20 PROMPT_ATTACK blocks within 1 hour across ALL sessions |
| **Severity** | P2 (Critical) |
| **Notification** | PagerDuty alert to Security on-call + SRE; Slack to #security and #incidents |
| **Rationale** | Broad-based injection attempts across multiple sessions suggest a coordinated attack or automated tool targeting the system. |
| **Response** | Consider temporary agent suspension; escalate to Security Lead |

#### Alert 3: Zero-Retrieval Anomaly

| Field | Value |
|-------|-------|
| **Signal** | Responses where knowledge base returns zero chunks |
| **Condition** | More than 30% of queries in a 1-hour window return zero retrieved chunks |
| **Severity** | P4 (Warning) |
| **Notification** | Slack to #engineering |
| **Rationale** | Could indicate KB sync failure, OpenSearch issue, or embedding drift. Also increases hallucination risk. |
| **Response** | Verify KB data source sync status; check OpenSearch collection health |

#### Alert 4: Token Count Spike

| Field | Value |
|-------|-------|
| **Signal** | Output token count per response |
| **Condition** | Single response exceeds 4,000 output tokens (baseline average: ~800 tokens) |
| **Severity** | P4 (Warning) |
| **Notification** | Logged for review; Slack to #security if repeated (> 3 in 1 hour) |
| **Rationale** | Abnormally long responses may indicate successful context manipulation or data exfiltration attempts where the model is being coerced into outputting large amounts of KB content. |

#### Alert 5: PII Exposure Spike

| Field | Value |
|-------|-------|
| **Signal** | PII detection/anonymisation events in output filter |
| **Condition** | More than 20 PII anonymisation events in a single day |
| **Severity** | P3 (High) |
| **Notification** | Slack to #security; daily digest to Data Protection Officer |
| **Rationale** | High PII detection rate indicates the KB contains more sensitive data than expected, or users are actively trying to extract personal information. |

---

### 1.5 CloudWatch Dashboard

Create a CloudWatch dashboard named `NorthstarAssist-Security` with the following widgets:

| Widget | Visualisation | Content |
|--------|---------------|---------|
| Invocations per hour | Line chart | Total agent invocations over time |
| Guardrail blocks by category | Stacked bar | PROMPT_ATTACK, topic blocks, content filter blocks |
| PII events | Line chart | PII anonymisation and block events over time |
| Response token distribution | Histogram | Output token counts (detect outliers) |
| Zero-retrieval rate | Line chart | % of queries with no KB results |
| Top blocked sessions | Table | Session IDs with most guardrail interventions (last 24h) |

---

### 1.6 Log Access Controls

| Team | Access Level | Justification |
|------|-------------|---------------|
| Security | Full read (input + output logs) | Incident investigation, threat hunting |
| SRE | Metadata only (no input/output content) | Performance monitoring, capacity planning |
| Engineering (AI/ML) | Full read (input + output logs) | Model quality, retrieval tuning |
| Management | Dashboard view only | Adoption metrics, summary reports |
| All other teams | No access | Logs contain employee queries and internal content |

---

## Part 2: Incident Response Playbook

### Playbook: Suspected Prompt Injection Incident

**Playbook ID:** IR-AI-001  
**Trigger:** Alert 1 or Alert 2 fires (PROMPT_ATTACK threshold exceeded)  
**Owner:** Security Team (on-call)  
**Last Tested:** [Date of last tabletop exercise]  
**Audience:** On-call analyst with no prior AI incident experience

---

### Step 1: Acknowledge and Assess (0 to 5 minutes)

**Goal:** Confirm the alert is genuine and assess scope.

1. Acknowledge the PagerDuty/Slack alert.

2. Open the CloudWatch dashboard:
   - Console path: **CloudWatch > Dashboards > NorthstarAssist-Security**
   - Check the "Guardrail blocks by category" widget for the PROMPT_ATTACK spike

3. Identify the session(s) involved:
   ```bash
   # Query CloudWatch Logs for recent PROMPT_ATTACK events
   aws logs filter-log-events \
     --log-group-name "/aws/bedrock/modelinvocations" \
     --start-time $(date -d '1 hour ago' +%s000) \
     --filter-pattern "PROMPT_ATTACK" \
     --region us-east-1
   ```

4. Determine scope:
   - **Single session:** Likely one user testing boundaries or a targeted attack
   - **Multiple sessions:** Potential coordinated attack or automated tool
   - **All sessions:** Possible indirect injection from KB content (escalate immediately)

5. Record your assessment in the incident channel (#incidents on Slack):
   - Time alert fired
   - Number of sessions affected
   - Number of PROMPT_ATTACK blocks in the window

---

### Step 2: Contain (5 to 15 minutes)

**Goal:** Stop ongoing harm while preserving evidence.

**If single session (targeted):**

6. Note the session ID from logs.

7. Determine if guardrails successfully blocked all attempts:
   ```bash
   # Check if any responses were returned (not blocked) during the suspicious session
   aws logs filter-log-events \
     --log-group-name "/aws/bedrock/modelinvocations" \
     --filter-pattern "\"sessionId\":\"SESSION_ID_HERE\"" \
     --region us-east-1
   ```

8. If all attempts were blocked: Monitor only. The controls are working.

9. If any attempts appear to have succeeded (response returned without guardrail intervention despite injection-style input): Escalate to Step 2b.

**If multiple sessions or suspected bypass (Step 2b):**

10. Consider disabling the agent temporarily:
    - Console path: **Bedrock > Agents > Northstar Assist**
    - Option A: Remove the agent alias (prevents new invocations)
    - Option B: Update the agent's system prompt to refuse all queries temporarily
    
    ```bash
    # List agent aliases
    aws bedrock-agent list-agent-aliases \
      --agent-id AGENT_ID \
      --region us-east-1
    
    # Delete alias to stop access (reversible by recreating)
    aws bedrock-agent delete-agent-alias \
      --agent-id AGENT_ID \
      --agent-alias-id ALIAS_ID \
      --region us-east-1
    ```

11. Notify the Security Lead and VP Engineering via Slack DM and phone if P2.

---

### Step 3: Investigate (15 to 60 minutes)

**Goal:** Understand what happened, what the attacker attempted, and whether any data was exposed.

12. Export the full session log for the suspicious session(s):
    ```bash
    aws logs filter-log-events \
      --log-group-name "/aws/bedrock/modelinvocations" \
      --filter-pattern "\"sessionId\":\"SESSION_ID_HERE\"" \
      --output json \
      --region us-east-1 > /tmp/incident_session_log.json
    ```

13. Review the session log for:
    - What prompts were submitted (look for injection patterns)
    - What responses were returned (did any contain sensitive data?)
    - What KB content was retrieved (was retrieval manipulated?)
    - Were any guardrail filters bypassed?

14. If indirect injection is suspected (injection content came from retrieved KB documents):
    - Identify which document chunk was retrieved
    - Check the S3 source document for malicious content
    ```bash
    # List recently modified objects in the KB bucket
    aws s3api list-objects-v2 \
      --bucket northstar-kb-documents-UNIQUE_ID \
      --query "Contents[?LastModified>='2026-07-17']" \
      --region us-east-1
    ```

15. Check CloudTrail for suspicious administrative actions:
    ```bash
    # Check for recent changes to the agent or KB
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=EventSource,AttributeValue=bedrock.amazonaws.com \
      --start-time $(date -d '24 hours ago' +%s) \
      --region us-east-1
    ```

16. Document findings in the incident channel with:
    - Attack technique used
    - Whether guardrails blocked or were bypassed
    - Any data exposed in responses
    - Source of injection (direct from user, or indirect from KB document)

---

### Step 4: Remediate (60 minutes to 24 hours)

**Goal:** Fix the vulnerability and restore safe service.

17. Based on findings, apply one or more of:

    | Finding | Remediation |
    |---------|-------------|
    | Known injection pattern bypassed filter | Add pattern to word filter; consider increasing PROMPT_ATTACK sensitivity |
    | Indirect injection from KB document | Remove/quarantine the document from S3; re-sync KB |
    | Guardrail bypass via novel technique | Report to AWS Support; add specific word filter as interim control |
    | Legitimate user testing (not malicious) | No technical change; communicate acceptable use policy |

18. If agent was suspended, restore service:
    ```bash
    # Recreate agent alias
    aws bedrock-agent create-agent-alias \
      --agent-id AGENT_ID \
      --agent-alias-name "production" \
      --region us-east-1
    ```

19. Verify the fix:
    - Submit the same injection prompt that triggered the incident
    - Confirm it is now blocked
    - Confirm normal queries still work

---

### Step 5: Post-Incident (24 to 72 hours)

**Goal:** Learn from the incident and improve defences.

20. Write an incident report (use standard Northstar incident template):
    - Timeline of events
    - Root cause
    - Impact assessment (data exposed, if any)
    - Remediation applied
    - Lessons learned

21. Update this playbook if gaps were identified.

22. Update the STRIDE-ML threat model if a new threat was identified.

23. Consider:
    - Do guardrail thresholds need adjustment?
    - Are there new word filter entries needed?
    - Does the document review process need strengthening?
    - Should monitoring thresholds be tightened?

24. Schedule a blameless post-incident review with: Security Lead, AI/ML Lead, SRE Lead.

---

### Escalation Matrix

| Condition | Escalate To | Method |
|-----------|-------------|--------|
| Single session, all blocked | No escalation (monitor) | Log in #security |
| Single session, partial bypass | Security Lead | Slack DM + phone |
| Multiple sessions | Security Lead + VP Engineering | PagerDuty P2 |
| Confirmed data exposure | Security Lead + DPO + Legal | PagerDuty P1 + phone |
| Suspected insider threat | Security Lead + VP Engineering + HR | Phone (private) |

---

### Quick Reference: Key Console Paths

| Action | Path |
|--------|------|
| View guardrail events | CloudWatch > Dashboards > NorthstarAssist-Security |
| View raw invocation logs | CloudWatch > Log groups > /aws/bedrock/modelinvocations |
| Suspend agent | Bedrock > Agents > Northstar Assist > Aliases > Delete |
| Check KB sync | Bedrock > Knowledge bases > [KB] > Data source > Status |
| Review IAM activity | CloudTrail > Event history > Filter: Event source = bedrock.amazonaws.com |
| Check S3 changes | S3 > northstar-kb-documents > Properties > Last modified |

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 18 July 2026 | AI Security Engineer | Initial monitoring plan and incident response playbook |
