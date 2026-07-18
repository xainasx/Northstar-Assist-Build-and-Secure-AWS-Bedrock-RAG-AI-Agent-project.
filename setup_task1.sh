#!/bin/bash
# =============================================================================
# Northstar Assist — Task 1 Setup Script
# =============================================================================
# This script automates the AWS resource creation for Task 1:
#   1. Creates an S3 bucket and uploads knowledge base documents
#   2. Creates a Bedrock Knowledge Base with OpenSearch Serverless vector store
#   3. Syncs the data source
#   4. Creates a Bedrock Agent connected to the Knowledge Base
#   5. Tests the agent with sample prompts
#
# PREREQUISITES:
#   - AWS CLI v2 installed and configured (aws configure)
#   - Foundation model access enabled in Bedrock console for:
#       * Anthropic Claude 3.7 Sonnet
#       * Amazon Titan Text Embeddings V2
#   - jq installed (brew install jq)
#
# USAGE:
#   chmod +x setup_task1.sh
#   ./setup_task1.sh
#
# NOTE: Model access MUST be enabled manually in the console first.
#       Go to: Bedrock > Model access > Manage model access > Enable both models
# =============================================================================

set -e

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION — Update these values
# ─────────────────────────────────────────────────────────────────────────────
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
BUCKET_NAME="northstar-kb-documents-${ACCOUNT_ID}-$(date +%Y%m%d)"
KB_NAME="northstar-assist-kb"
AGENT_NAME="Northstar-Assist"
EMBEDDING_MODEL_ARN="arn:aws:bedrock:${REGION}::foundation-model/amazon.titan-embed-text-v2:0"
FOUNDATION_MODEL_ID="anthropic.claude-3-7-sonnet-20250219-v1:0"
DOCS_PATH="$(dirname "$0")/starter/northstar-knowledge-base/txt"

echo "============================================="
echo "Northstar Assist — Task 1 Setup"
echo "============================================="
echo "Account ID:  $ACCOUNT_ID"
echo "Region:      $REGION"
echo "Bucket:      $BUCKET_NAME"
echo "============================================="
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Create S3 Bucket and Upload Documents
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 1: Creating S3 bucket and uploading documents..."

# Create bucket (us-east-1 does not use LocationConstraint)
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region $REGION 2>/dev/null; then
    echo "    Bucket $BUCKET_NAME already exists. Skipping creation."
else
    aws s3 mb "s3://${BUCKET_NAME}" --region $REGION
    echo "    Created bucket: $BUCKET_NAME"
fi

# Upload documents
echo "    Uploading knowledge base documents..."
aws s3 cp "$DOCS_PATH/" "s3://${BUCKET_NAME}/" --recursive --region $REGION
echo "    Documents uploaded."
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Create IAM Role for Knowledge Base
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 2: Creating IAM role for Knowledge Base..."

KB_ROLE_NAME="AmazonBedrockExecutionRoleForKB_northstar"

# Trust policy
KB_TRUST_POLICY=$(cat <<EOF
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
          "aws:SourceAccount": "${ACCOUNT_ID}"
        }
      }
    }
  ]
}
EOF
)

# Check if role exists
if aws iam get-role --role-name "$KB_ROLE_NAME" 2>/dev/null; then
    echo "    Role $KB_ROLE_NAME already exists. Skipping."
else
    aws iam create-role \
        --role-name "$KB_ROLE_NAME" \
        --assume-role-policy-document "$KB_TRUST_POLICY" \
        --description "Execution role for Northstar Assist Knowledge Base"
    echo "    Created role: $KB_ROLE_NAME"
fi

KB_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${KB_ROLE_NAME}"

# Attach permissions policy
KB_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ReadAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    },
    {
      "Sid": "InvokeEmbeddingModel",
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "${EMBEDDING_MODEL_ARN}"
    },
    {
      "Sid": "OpenSearchServerlessAccess",
      "Effect": "Allow",
      "Action": "aoss:APIAccessAll",
      "Resource": "arn:aws:aoss:${REGION}:${ACCOUNT_ID}:collection/*"
    }
  ]
}
EOF
)

aws iam put-role-policy \
    --role-name "$KB_ROLE_NAME" \
    --policy-name "NorthstarKBPolicy" \
    --policy-document "$KB_POLICY"

echo "    Attached permissions policy."

# Wait for IAM propagation
echo "    Waiting 10 seconds for IAM propagation..."
sleep 10
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Create Knowledge Base
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 3: Creating Bedrock Knowledge Base..."

# Check if KB already exists
EXISTING_KB=$(aws bedrock-agent list-knowledge-bases --region $REGION \
    --query "knowledgeBaseSummaries[?name=='${KB_NAME}'].knowledgeBaseId" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_KB" ] && [ "$EXISTING_KB" != "None" ]; then
    KB_ID="$EXISTING_KB"
    echo "    Knowledge Base already exists: $KB_ID"
else
    KB_RESPONSE=$(aws bedrock-agent create-knowledge-base \
        --name "$KB_NAME" \
        --description "Internal documents knowledge base for Northstar Assist" \
        --role-arn "$KB_ROLE_ARN" \
        --knowledge-base-configuration '{
            "type": "VECTOR",
            "vectorKnowledgeBaseConfiguration": {
                "embeddingModelArn": "'"${EMBEDDING_MODEL_ARN}"'"
            }
        }' \
        --storage-configuration '{
            "type": "OPENSEARCH_SERVERLESS",
            "opensearchServerlessConfiguration": {
                "collectionArn": "auto",
                "vectorIndexName": "bedrock-knowledge-base-default-index",
                "fieldMapping": {
                    "vectorField": "bedrock-knowledge-base-default-vector",
                    "textField": "AMAZON_BEDROCK_TEXT_CHUNK",
                    "metadataField": "AMAZON_BEDROCK_METADATA"
                }
            }
        }' \
        --region $REGION 2>&1)

    # If the auto OpenSearch creation doesn't work via CLI, provide console instructions
    if echo "$KB_RESPONSE" | grep -q "knowledgeBaseId"; then
        KB_ID=$(echo "$KB_RESPONSE" | jq -r '.knowledgeBase.knowledgeBaseId')
        echo "    Created Knowledge Base: $KB_ID"
    else
        echo ""
        echo "    ⚠️  Knowledge Base creation via CLI requires OpenSearch Serverless setup."
        echo "    The easiest path is to create it in the console:"
        echo ""
        echo "    1. Go to: https://console.aws.amazon.com/bedrock/home?region=${REGION}#/knowledge-bases/create"
        echo "    2. Name: ${KB_NAME}"
        echo "    3. S3 URI: s3://${BUCKET_NAME}"
        echo "    4. Embedding model: Titan Text Embeddings V2"
        echo "    5. Vector store: Quick create (OpenSearch Serverless)"
        echo "    6. Click Create"
        echo ""
        echo "    After creating, run this to get the KB ID:"
        echo "    aws bedrock-agent list-knowledge-bases --region ${REGION}"
        echo ""
        echo "    Then set KB_ID and re-run from Step 4."
        echo ""
        read -p "    Enter your Knowledge Base ID (or press Enter to exit): " KB_ID
        if [ -z "$KB_ID" ]; then
            echo "    Exiting. Re-run after creating KB in console."
            exit 0
        fi
    fi
fi

echo "    Knowledge Base ID: $KB_ID"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: Create and Sync Data Source
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 4: Creating and syncing data source..."

# Check for existing data source
EXISTING_DS=$(aws bedrock-agent list-data-sources \
    --knowledge-base-id "$KB_ID" \
    --region $REGION \
    --query "dataSourceSummaries[0].dataSourceId" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_DS" ] && [ "$EXISTING_DS" != "None" ]; then
    DS_ID="$EXISTING_DS"
    echo "    Data source already exists: $DS_ID"
else
    DS_RESPONSE=$(aws bedrock-agent create-data-source \
        --knowledge-base-id "$KB_ID" \
        --name "northstar-documents" \
        --data-source-configuration '{
            "type": "S3",
            "s3Configuration": {
                "bucketArn": "arn:aws:s3:::'"${BUCKET_NAME}"'"
            }
        }' \
        --region $REGION)

    DS_ID=$(echo "$DS_RESPONSE" | jq -r '.dataSource.dataSourceId')
    echo "    Created data source: $DS_ID"
fi

# Sync the data source
echo "    Starting data source sync..."
aws bedrock-agent start-ingestion-job \
    --knowledge-base-id "$KB_ID" \
    --data-source-id "$DS_ID" \
    --region $REGION

echo "    Sync started. Waiting for completion..."

# Poll for sync completion (timeout after 5 minutes)
SYNC_TIMEOUT=300
SYNC_ELAPSED=0
while [ $SYNC_ELAPSED -lt $SYNC_TIMEOUT ]; do
    SYNC_STATUS=$(aws bedrock-agent list-ingestion-jobs \
        --knowledge-base-id "$KB_ID" \
        --data-source-id "$DS_ID" \
        --region $REGION \
        --query "ingestionJobSummaries[0].status" \
        --output text 2>/dev/null || echo "IN_PROGRESS")

    if [ "$SYNC_STATUS" = "COMPLETE" ]; then
        echo "    Data source sync complete."
        break
    elif [ "$SYNC_STATUS" = "FAILED" ]; then
        echo "    ⚠️  Sync failed. Check the console for details."
        break
    fi

    sleep 10
    SYNC_ELAPSED=$((SYNC_ELAPSED + 10))
    echo "    Still syncing... (${SYNC_ELAPSED}s elapsed, status: ${SYNC_STATUS})"
done
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: Create IAM Role for Agent
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 5: Creating IAM role for Bedrock Agent..."

AGENT_ROLE_NAME="AmazonBedrockExecutionRoleForAgents_northstar"

AGENT_TRUST_POLICY=$(cat <<EOF
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
          "aws:SourceAccount": "${ACCOUNT_ID}"
        }
      }
    }
  ]
}
EOF
)

if aws iam get-role --role-name "$AGENT_ROLE_NAME" 2>/dev/null; then
    echo "    Role $AGENT_ROLE_NAME already exists. Skipping."
else
    aws iam create-role \
        --role-name "$AGENT_ROLE_NAME" \
        --assume-role-policy-document "$AGENT_TRUST_POLICY" \
        --description "Execution role for Northstar Assist Bedrock Agent"
    echo "    Created role: $AGENT_ROLE_NAME"
fi

AGENT_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${AGENT_ROLE_NAME}"

# Agent permissions (least-privilege from Task 4)
AGENT_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "InvokeFoundationModel",
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "arn:aws:bedrock:${REGION}::foundation-model/${FOUNDATION_MODEL_ID}"
    },
    {
      "Sid": "RetrieveFromKB",
      "Effect": "Allow",
      "Action": "bedrock:Retrieve",
      "Resource": "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:knowledge-base/${KB_ID}"
    }
  ]
}
EOF
)

aws iam put-role-policy \
    --role-name "$AGENT_ROLE_NAME" \
    --policy-name "NorthstarAgentPolicy" \
    --policy-document "$AGENT_POLICY"

echo "    Attached agent permissions policy."
echo "    Waiting 10 seconds for IAM propagation..."
sleep 10
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6: Create the Bedrock Agent
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 6: Creating Bedrock Agent..."

AGENT_INSTRUCTION="You are Northstar Assist, an internal AI assistant for Northstar Technologies employees. Your role is to answer questions about company processes, policies, projects, and internal information using the knowledge base of internal documents provided to you.

Guidelines:
- Only answer questions using information from the retrieved documents. If the documents do not contain relevant information, say I do not have information about that in my current knowledge base.
- Be helpful, professional, and concise.
- Do not speculate or make up information not supported by the documents.
- Do not provide medical, legal, or financial advice.
- If asked about topics outside your knowledge base, politely redirect the user to the appropriate team or resource.
- Cite which document your answer comes from when possible."

# Check if agent exists
EXISTING_AGENT=$(aws bedrock-agent list-agents --region $REGION \
    --query "agentSummaries[?agentName=='${AGENT_NAME}'].agentId" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_AGENT" ] && [ "$EXISTING_AGENT" != "None" ]; then
    AGENT_ID="$EXISTING_AGENT"
    echo "    Agent already exists: $AGENT_ID"
else
    AGENT_RESPONSE=$(aws bedrock-agent create-agent \
        --agent-name "$AGENT_NAME" \
        --description "Internal AI assistant for Northstar Technologies employees" \
        --agent-resource-role-arn "$AGENT_ROLE_ARN" \
        --foundation-model "$FOUNDATION_MODEL_ID" \
        --instruction "$AGENT_INSTRUCTION" \
        --region $REGION)

    AGENT_ID=$(echo "$AGENT_RESPONSE" | jq -r '.agent.agentId')
    echo "    Created agent: $AGENT_ID"
fi

echo "    Agent ID: $AGENT_ID"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 7: Associate Knowledge Base with Agent
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 7: Associating Knowledge Base with Agent..."

aws bedrock-agent associate-agent-knowledge-base \
    --agent-id "$AGENT_ID" \
    --agent-version "DRAFT" \
    --knowledge-base-id "$KB_ID" \
    --description "Northstar internal documents for employee questions" \
    --region $REGION 2>/dev/null || echo "    (Already associated or association in progress)"

echo "    Knowledge Base associated."
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 8: Prepare the Agent
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 8: Preparing agent..."

aws bedrock-agent prepare-agent \
    --agent-id "$AGENT_ID" \
    --region $REGION

echo "    Agent preparation started. Waiting 30 seconds..."
sleep 30

# Check status
AGENT_STATUS=$(aws bedrock-agent get-agent \
    --agent-id "$AGENT_ID" \
    --region $REGION \
    --query "agent.agentStatus" \
    --output text)

echo "    Agent status: $AGENT_STATUS"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 9: Create Agent Alias (needed for invocation)
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 9: Creating agent alias..."

ALIAS_RESPONSE=$(aws bedrock-agent create-agent-alias \
    --agent-id "$AGENT_ID" \
    --agent-alias-name "production" \
    --region $REGION 2>&1)

if echo "$ALIAS_RESPONSE" | grep -q "agentAliasId"; then
    ALIAS_ID=$(echo "$ALIAS_RESPONSE" | jq -r '.agentAlias.agentAliasId')
    echo "    Created alias: $ALIAS_ID"
else
    # Try to get existing alias
    ALIAS_ID=$(aws bedrock-agent list-agent-aliases \
        --agent-id "$AGENT_ID" \
        --region $REGION \
        --query "agentAliasSummaries[?agentAliasName=='production'].agentAliasId" \
        --output text 2>/dev/null || echo "")
    echo "    Using existing alias: $ALIAS_ID"
fi

echo ""
echo "    Waiting 15 seconds for alias to become active..."
sleep 15

# ─────────────────────────────────────────────────────────────────────────────
# STEP 10: Test the Agent
# ─────────────────────────────────────────────────────────────────────────────
echo ">>> Step 10: Testing the agent..."
echo ""
echo "─────────────────────────────────────────────"
echo "TEST 1: Q3 Priorities"
echo "─────────────────────────────────────────────"
echo "Prompt: What are the Q3 2023 priorities for Northstar Technologies?"
echo ""
echo "Response:"

aws bedrock-agent-runtime invoke-agent \
    --agent-id "$AGENT_ID" \
    --agent-alias-id "$ALIAS_ID" \
    --session-id "test-session-$(date +%s)" \
    --input-text "What are the Q3 2023 priorities for Northstar Technologies?" \
    --region $REGION \
    --output text 2>/dev/null || echo "    (If this fails, test in the Bedrock console instead)"

echo ""
echo "─────────────────────────────────────────────"
echo "TEST 2: Incident Report"
echo "─────────────────────────────────────────────"
echo "Prompt: What happened in incident INC-2023-0603-001 and what was the root cause?"
echo ""
echo "Response:"

aws bedrock-agent-runtime invoke-agent \
    --agent-id "$AGENT_ID" \
    --agent-alias-id "$ALIAS_ID" \
    --session-id "test-session-$(date +%s)" \
    --input-text "What happened in incident INC-2023-0603-001 and what was the root cause?" \
    --region $REGION \
    --output text 2>/dev/null || echo "    (If this fails, test in the Bedrock console instead)"

echo ""
echo ""
echo "============================================="
echo "SETUP COMPLETE"
echo "============================================="
echo ""
echo "Resources created:"
echo "  S3 Bucket:       $BUCKET_NAME"
echo "  Knowledge Base:  $KB_ID"
echo "  Data Source:     $DS_ID"
echo "  Agent:           $AGENT_ID"
echo "  Agent Alias:     $ALIAS_ID"
echo "  KB Role:         $KB_ROLE_NAME"
echo "  Agent Role:      $AGENT_ROLE_NAME"
echo ""
echo "Next steps:"
echo "  1. Go to the Bedrock console to test interactively:"
echo "     https://console.aws.amazon.com/bedrock/home?region=${REGION}#/agents/${AGENT_ID}"
echo "  2. Use the Test panel to submit prompts"
echo "  3. Screenshot the results for your Task 1 deliverable"
echo ""
echo "Update your deliverables with these IDs:"
echo "  - IAM_Hardening_Summary.md: Replace placeholder ARNs"
echo "  - Lab Notes: Fill in the resource table"
echo ""
echo "============================================="
echo "CLEANUP (run after project submission):"
echo "============================================="
echo "  aws bedrock-agent delete-agent-alias --agent-id $AGENT_ID --agent-alias-id $ALIAS_ID --region $REGION"
echo "  aws bedrock-agent delete-agent --agent-id $AGENT_ID --region $REGION"
echo "  aws bedrock-agent delete-knowledge-base --knowledge-base-id $KB_ID --region $REGION"
echo "  aws s3 rm s3://${BUCKET_NAME} --recursive && aws s3 rb s3://${BUCKET_NAME}"
echo "  aws iam delete-role-policy --role-name $KB_ROLE_NAME --policy-name NorthstarKBPolicy"
echo "  aws iam delete-role --role-name $KB_ROLE_NAME"
echo "  aws iam delete-role-policy --role-name $AGENT_ROLE_NAME --policy-name NorthstarAgentPolicy"
echo "  aws iam delete-role --role-name $AGENT_ROLE_NAME"
echo "============================================="
