# Complete Manual Implementation Guide
# Shopping Agent with AWS Bedrock AgentCore

**Project:** AI-Powered Shopping Concierge with Visa Payment Integration  
**Author:** Ruben Hassid  
**Purpose:** Zero-assumption, step-by-step manual recreation guide  
**Target Audience:** DevOps Engineers, Cloud Architects, Backend Developers  
**Estimated Time:** 8-12 hours (first-time deployment)

---

## Table of Contents

- [Phase 0: High-Level Architecture Overview](#phase-0-high-level-architecture-overview)
- [Phase 1: Local Machine Preparation](#phase-1-local-machine-preparation)
- [Phase 2: AWS Account and Infrastructure Setup](#phase-2-aws-account-and-infrastructure-setup)
- [Phase 3: Application/Code Setup](#phase-3-applicationcode-setup)
- [Phase 4: Configuration, Secrets, and Environment Variables](#phase-4-configuration-secrets-and-environment-variables)
- [Phase 5: Deployment and Execution](#phase-5-deployment-and-execution)
- [Phase 6: Verification, Testing, and Rollback](#phase-6-verification-testing-and-rollback)

---

## Phase 0: High-Level Architecture Overview

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                         │
│  React Frontend (Vite + TypeScript) - Port 9000                │
│  • Real-time streaming chat UI                                 │
│  • Visa iframe integration for payments                        │
│  • AWS Amplify authentication                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ HTTPS/WSS
┌─────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION LAYER                         │
│  AWS Cognito User Pools + OAuth2                               │
│  • JWT tokens for user authentication                          │
│  • Machine-to-machine OAuth for services                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓ JWT
┌─────────────────────────────────────────────────────────────────┐
│                   AGENT ORCHESTRATION LAYER                     │
│  AWS Bedrock AgentCore Gateway                                 │
│  ├─ Supervisor Agent (Claude 3.5 Sonnet v2)                   │
│  │  └─ Conversation orchestration & memory                    │
│  ├─ Shopping Sub-agent                                         │
│  │  └─ Product search & recommendations                       │
│  └─ Cart Sub-agent                                             │
│     └─ Cart management & payment processing                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓ MCP Protocol
┌─────────────────────────────────────────────────────────────────┐
│                      MCP TOOL LAYER                             │
│  ├─ Shopping MCP Server (Docker/ECS)                          │
│  │  └─ SERP API integration for product search               │
│  └─ Cart MCP Server (Docker/ECS)                              │
│     └─ DynamoDB operations + Visa API integration            │
└─────────────────────────────────────────────────────────────────┘
                              ↓ API Calls
┌─────────────────────────────────────────────────────────────────┐
│                    DATA & EXTERNAL SERVICES                     │
│  ├─ DynamoDB Tables (User profiles, cart, wishlist, sessions) │
│  ├─ SERP API (Amazon product search)                          │
│  ├─ Visa Token Service API (Payment tokenization)             │
│  └─ AWS Secrets Manager (API keys & certificates)             │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Frontend**: React TypeScript app with Vite, hosted on AWS Amplify
2. **Backend**: AWS Bedrock AgentCore with Python agents (Strands framework)
3. **Authentication**: AWS Cognito with JWT + OAuth2
4. **Data Storage**: DynamoDB with GraphQL API (AWS Amplify)
5. **MCP Servers**: Containerized Python services on ECS (ARM64)
6. **External APIs**: SERP API (product search), Visa API (payments)

### Technology Stack

- **Frontend**: React 18, TypeScript, Vite, Tailwind CSS
- **Backend**: Python 3.11, Strands Agents, MCP Protocol
- **AI Model**: Claude 3.5 Sonnet v2 (via AWS Bedrock)
- **Infrastructure**: AWS CDK (TypeScript), Docker, ECS Fargate
- **Database**: DynamoDB with GraphQL (AWS Amplify)
- **Authentication**: AWS Cognito User Pools

### Deployment Architecture

- **Region**: us-east-1 (default, configurable)
- **Compute**: ECS Fargate with ARM64 (Graviton) for cost optimization
- **Networking**: VPC with public/private subnets, NAT Gateway
- **Monitoring**: CloudWatch Logs, X-Ray tracing
- **CI/CD**: Manual deployment via npm scripts + AWS CDK

---

## Phase 1: Local Machine Preparation

### 1.1 Operating System Requirements

**Supported OS:**
- macOS 12+ (recommended for development)
- Linux (Ubuntu 20.04+, Amazon Linux 2023)
- Windows 10/11 with WSL2 (Ubuntu 20.04+)

**Note**: This guide assumes macOS/Linux. Windows users should use WSL2.

### 1.2 Install Core Development Tools

#### 1.2.1 Install Homebrew (macOS) or apt (Linux)

**macOS:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update && sudo apt upgrade -y
```

#### 1.2.2 Install Git

**macOS:**
```bash
brew install git
```

**Linux:**
```bash
sudo apt install git -y
```

**Verify:**
```bash
git --version
# Expected: git version 2.30.0 or higher
```

#### 1.2.3 Install Node.js and npm

**Required Version**: Node.js 18+ (LTS recommended)

**macOS:**
```bash
brew install node@20
```

**Linux:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

**Verify:**
```bash
node --version
# Expected: v20.x.x or higher

npm --version
# Expected: 10.x.x or higher
```

#### 1.2.4 Install Python 3.11

**macOS:**
```bash
brew install python@3.11
```

**Linux:**
```bash
sudo apt install python3.11 python3.11-venv python3.11-dev -y
```

**Verify:**
```bash
python3.11 --version
# Expected: Python 3.11.x
```

#### 1.2.5 Install uv (Python Package Manager)

**All platforms:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Verify:**
```bash
uv --version
# Expected: uv 0.x.x or higher
```

#### 1.2.6 Install Docker Desktop

**macOS:**
```bash
brew install --cask docker
```

**Linux:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

**Verify:**
```bash
docker --version
# Expected: Docker version 24.0.0 or higher

docker ps
# Should not show permission errors
```

#### 1.2.7 Install AWS CLI v2

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

**Verify:**
```bash
aws --version
# Expected: aws-cli/2.x.x or higher
```

#### 1.2.8 Install jq (JSON processor)

**macOS:**
```bash
brew install jq
```

**Linux:**
```bash
sudo apt install jq -y
```

**Verify:**
```bash
jq --version
# Expected: jq-1.6 or higher
```

#### 1.2.9 Install AWS CDK CLI

```bash
npm install -g aws-cdk@2.225.0
```

**Verify:**
```bash
cdk --version
# Expected: 2.225.0 or compatible version
```

### 1.3 Configure Local Environment

#### 1.3.1 Set up hosts file for Visa integration

**Purpose**: Visa iframe requires a custom domain (not localhost) due to CSP policies.

**macOS/Linux:**
```bash
echo "127.0.0.1 vcas.local.com" | sudo tee -a /etc/hosts
```

**Windows (run PowerShell as Administrator):**
```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 vcas.local.com"
```

**Verify:**
```bash
ping vcas.local.com
# Should resolve to 127.0.0.1
```

#### 1.3.2 Flush DNS cache

**macOS:**
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Linux:**
```bash
sudo systemd-resolve --flush-caches
```

**Windows:**
```powershell
ipconfig /flushdns
```

### 1.4 Validation Checklist

Before proceeding, verify all tools are installed:

```bash
# Create validation script
cat > validate-tools.sh << 'EOF'
#!/bin/bash
echo "=== Tool Validation ==="
echo -n "Git: "; git --version || echo "❌ MISSING"
echo -n "Node: "; node --version || echo "❌ MISSING"
echo -n "npm: "; npm --version || echo "❌ MISSING"
echo -n "Python 3.11: "; python3.11 --version || echo "❌ MISSING"
echo -n "uv: "; uv --version || echo "❌ MISSING"
echo -n "Docker: "; docker --version || echo "❌ MISSING"
echo -n "AWS CLI: "; aws --version || echo "❌ MISSING"
echo -n "jq: "; jq --version || echo "❌ MISSING"
echo -n "CDK: "; cdk --version || echo "❌ MISSING"
echo -n "vcas.local.com: "; ping -c 1 vcas.local.com > /dev/null 2>&1 && echo "✅ OK" || echo "❌ NOT CONFIGURED"
EOF

chmod +x validate-tools.sh
./validate-tools.sh
```

**Expected Output**: All tools should show version numbers, no "❌ MISSING" errors.

---

## Phase 2: AWS Account and Infrastructure Setup

### 2.1 AWS Account Prerequisites

#### 2.1.1 Create or Access AWS Account

1. Go to https://aws.amazon.com/
2. Click "Create an AWS Account" or sign in
3. Complete account setup with payment method
4. Verify email address

#### 2.1.2 Create IAM User for Deployment

**Why**: Never use root account credentials for deployments.

**Steps via AWS Console:**

1. Navigate to IAM Console: https://console.aws.amazon.com/iam/
2. Click "Users" → "Create user"
3. Username: `concierge-agent-deployer`
4. Select "Provide user access to the AWS Management Console" (optional)
5. Click "Next"
6. Attach policies directly:
   - `AdministratorAccess` (for initial setup; restrict later)
7. Click "Create user"
8. Download credentials CSV or note access key ID and secret

**Alternative via AWS CLI (if already configured):**
```bash
aws iam create-user --user-name concierge-agent-deployer

aws iam attach-user-policy \
  --user-name concierge-agent-deployer \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws iam create-access-key --user-name concierge-agent-deployer
# Save the AccessKeyId and SecretAccessKey from output
```

#### 2.1.3 Configure AWS CLI Credentials

```bash
aws configure
```

**Prompts and responses:**
```
AWS Access Key ID [None]: <paste your access key>
AWS Secret Access Key [None]: <paste your secret key>
Default region name [None]: us-east-1
Default output format [None]: json
```

**Verify configuration:**
```bash
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/concierge-agent-deployer"
}
```

**Save account ID for later:**
```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
```

### 2.2 AWS Service Limits and Quotas

#### 2.2.1 Check Service Quotas

**Required quotas:**
- ECS Fargate tasks: 50+ (default: 1000)
- DynamoDB tables: 10+ (default: 2500)
- Cognito User Pools: 1+ (default: 1000)
- CloudFormation stacks: 10+ (default: 2000)
- ECR repositories: 5+ (default: 10000)

**Check current limits:**
```bash
aws service-quotas list-service-quotas \
  --service-code ecs \
  --query 'Quotas[?QuotaName==`Fargate On-Demand vCPU resource count`]'
```

#### 2.2.2 Request Quota Increases (if needed)

If any limits are too low:
```bash
aws service-quotas request-service-quota-increase \
  --service-code ecs \
  --quota-code L-3032A538 \
  --desired-value 100
```

### 2.3 Enable Required AWS Services

#### 2.3.1 Enable AWS Bedrock Model Access

**Critical**: Must enable Claude 3.5 Sonnet v2 model access.

**Steps via AWS Console:**

1. Navigate to AWS Bedrock Console: https://console.aws.amazon.com/bedrock/
2. Select region: **us-east-1**
3. Click "Model access" in left sidebar
4. Click "Manage model access"
5. Find and enable:
   - ✅ **Anthropic Claude 3.5 Sonnet v2** (anthropic.claude-3-5-sonnet-20241022-v2:0)
   - ✅ **Anthropic Claude 3 Haiku** (optional, for cost optimization)
6. Click "Request model access"
7. Wait 2-5 minutes for approval (usually instant)

**Verify model access:**
```bash
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `claude-3-5-sonnet`)].modelId'
```

**Expected output:**
```json
[
    "anthropic.claude-3-5-sonnet-20241022-v2:0"
]
```

#### 2.3.2 Bootstrap AWS CDK

**Purpose**: CDK requires S3 bucket and IAM roles for deployments.

```bash
cdk bootstrap aws://$AWS_ACCOUNT_ID/us-east-1
```

**Expected output:**
```
 ✅  Environment aws://123456789012/us-east-1 bootstrapped.
```

**Verify bootstrap:**
```bash
aws cloudformation describe-stacks \
  --stack-name CDKToolkit \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

**Expected**: `"CREATE_COMPLETE"`

### 2.4 Network and Security Setup

#### 2.4.1 VPC Configuration

**Note**: AWS CDK will create VPC automatically. No manual setup needed.

**Default VPC settings:**
- CIDR: 10.0.0.0/16
- Public subnets: 2 (for NAT Gateways)
- Private subnets: 2 (for ECS tasks)
- NAT Gateways: 2 (high availability)

#### 2.4.2 Security Groups

**Note**: CDK creates security groups automatically. Default rules:
- Inbound: Port 8000 from VPC CIDR (MCP servers)
- Outbound: All traffic (for API calls)

### 2.5 IAM Roles and Policies

**Note**: CDK creates all required IAM roles automatically:

1. **ECS Task Execution Role**: Pull Docker images from ECR
2. **ECS Task Role**: Access DynamoDB, Secrets Manager, Bedrock
3. **Lambda Execution Role**: Visa proxy Lambda permissions
4. **Cognito Roles**: User authentication and authorization

**No manual IAM setup required.**

---

## Phase 3: Application/Code Setup

### 3.1 Clone or Create Project Structure

#### 3.1.1 Create project directory

```bash
mkdir -p ~/projects/shopping-agent
cd ~/projects/shopping-agent
```

#### 3.1.2 Initialize Git repository

```bash
git init
```

#### 3.1.3 Create deployment configuration

```bash
cat > deployment-config.json << 'EOF'
{
  "deploymentId": "shopping",
  "description": "Unique identifier for this deployment. Change this for each separate deployment in the same AWS account."
}
EOF
```

**Important**: The `deploymentId` must be unique per deployment in the same AWS account.

### 3.2 Project Structure Setup

Create the complete directory structure:

```bash
# Root level
mkdir -p amplify/auth amplify/data
mkdir -p concierge_agent/supervisor_agent
mkdir -p concierge_agent/mcp_cart_tools
mkdir -p concierge_agent/mcp_shopping_tools
mkdir -p concierge_agent/local-visa-server
mkdir -p infrastructure/agent-stack/lib/constructs
mkdir -p infrastructure/agent-stack/lambdas/oauth-provider
mkdir -p infrastructure/mcp-servers/lib
mkdir -p infrastructure/frontend-stack/lib
mkdir -p infrastructure/visa-lambda-stack/bin
mkdir -p infrastructure/visa-lambda-stack/lib
mkdir -p web-ui/src/components
mkdir -p web-ui/src/services
mkdir -p web-ui/src/hooks
mkdir -p web-ui/src/utils
mkdir -p web-ui/public
mkdir -p scripts
mkdir -p docs
```

### 3.3 Root Package Configuration

#### 3.3.1 Create root package.json

```bash
cat > package.json << 'EOF'
{
  "name": "sample-concierge-agent",
  "version": "1.0.0",
  "description": "AI agent streaming UI for Trade IQ  with AWS Amplify",
  "type": "module",
  "scripts": {
    "dev": "npm run dev --workspace=web-ui",
    "build": "npm run build --workspace=web-ui",
    "deploy:amplify": "npx ampx sandbox --once --identifier $(node -p \"require('./deployment-config.json').deploymentId\")",
    "deploy:mcp": "find concierge_agent/mcp_* -name Dockerfile -exec touch {} \\; && cd infrastructure/mcp-servers && npm install && cdk deploy --all --require-approval never",
    "deploy:agent": "cd infrastructure/agent-stack && npm install && cdk deploy --require-approval never && cd ../.. && ./scripts/sync-gateway.sh",
    "deploy:visa-lambda": "cd infrastructure/visa-lambda-stack && npm install && cdk deploy --context deploymentId=$(node -p \"require('./deployment-config.json').deploymentId\") --require-approval never",
    "deploy:frontend": "cd infrastructure/frontend-stack && npm install && cdk deploy --require-approval never && cd ../.. && ./scripts/deploy-frontend.sh",
    "deploy": "npm run deploy:amplify && npm run deploy:mcp && npm run deploy:agent && npm run deploy:visa-lambda",
    "clean:amplify": "npx ampx sandbox delete",
    "clean:mcp": "cd infrastructure/mcp-servers && cdk destroy",
    "clean:agent": "cd infrastructure/agent-stack && cdk destroy",
    "clean:visa-lambda": "cd infrastructure/visa-lambda-stack && cdk destroy --context deploymentId=$(node -p \"require('./deployment-config.json').deploymentId\")",
    "clean:frontend": "cd infrastructure/frontend-stack && cdk destroy",
    "clean": "npm run clean:frontend && npm run clean:agent && npm run clean:mcp && npm run clean:visa-lambda && npm run clean:amplify"
  },
  "workspaces": [
    "web-ui",
    "amplify"
  ],
  "devDependencies": {
    "@aws-amplify/backend": "^1.0.4",
    "@aws-amplify/backend-cli": "^1.0.4",
    "@vitejs/plugin-basic-ssl": "^2.1.0",
    "aws-cdk": "^2.225.0",
    "aws-cdk-lib": "^2.225.0",
    "constructs": "^10.0.0",
    "typescript": "^5.0.0"
  },
  "dependencies": {
    "aws4": "^1.13.2"
  }
}
EOF
```

#### 3.3.2 Create .gitignore

```bash
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
coverage/

# Production
build/
dist/
*.tgz

# Environment
.env
.env.local
.env.*.local
amplify_outputs.json

# CDK
cdk.out/
.cdk.staging/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# Python
__pycache__/
*.py[cod]
*$py.class
.Python
.venv/
venv/
ENV/

# Secrets
*.pem
!AgentCoreAi.pem
!AgentCoreProject.pem
!AgentCoreShopping.pem
*.key
*.crt

# AWS
.aws-sam/
EOF
```

### 3.4 Install Root Dependencies

```bash
npm install
```

**Expected output:**
```
added 500+ packages in 30s
```

**Validation**: Verify workspaces are recognized:
```bash
npm ls --workspaces
```

---

## Phase 4: Configuration, Secrets, and Environment Variables

### 4.1 AWS Amplify Backend Configuration

#### 4.1.1 Create Amplify auth resource

```bash
cat > amplify/auth/resource.ts << 'EOF'
import { defineAuth } from '@aws-amplify/backend'

export const auth = defineAuth({
  loginWith: {
    email: true,
  },
  multifactor: {
    mode: 'OFF',
  },
  userAttributes: {
    email: {
      required: true,
      mutable: true,
    },
    givenName: {
      required: true,
      mutable: true,
    },
    familyName: {
      required: true,
      mutable: true,
    },
  },
  groups: ['user'],
})
EOF
```

#### 4.1.2 Create Amplify data resource (DynamoDB schema)

**Note**: This file is large. Create it in your editor or download from source.

```bash
# Create minimal version for now
cat > amplify/data/resource.ts << 'EOF'
import { type ClientSchema, a, defineData } from '@aws-amplify/backend'

const schema = a.schema({
  UserProfile: a.model({
    id: a.id().required(),
    userId: a.id().required(),
    name: a.string(),
    email: a.string(),
    address: a.string(),
    notes: a.string(),
    onboardingCompleted: a.boolean().default(false),
    preferences: a.json(),
    createdAt: a.datetime(),
    updatedAt: a.datetime(),
  }).authorization((allow: any) => [allow.authenticated()]),

  Wishlist: a.model({
    id: a.id().required(),
    user_id: a.string().required(),
    asin: a.string().required(),
    title: a.string().required(),
    price: a.string().required(),
    reviews: a.string(),
    url: a.string(),
  }).authorization((allow: any) => [allow.authenticated()])
    .secondaryIndexes((index: any) => [index('user_id')]),

  Feedback: a.model({
    id: a.id().required(),
    userId: a.id().required(),
    messageId: a.id(),
    feedback: a.enum(['up', 'down']),
    comment: a.string(),
    createdAt: a.datetime(),
  }).authorization((allow: any) => [allow.authenticated()]),
})

export type Schema = ClientSchema<typeof schema>

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: 'userPool',
  },
})
EOF
```


#### 4.1.3 Create Amplify backend.ts

```bash
cat > amplify/backend.ts << 'EOF'
import { defineBackend } from '@aws-amplify/backend';
import { auth } from './auth/resource';
import { data } from './data/resource';
import { Effect, PolicyStatement } from 'aws-cdk-lib/aws-iam';
import { CfnOutput } from 'aws-cdk-lib';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { UserPoolResourceServer, ResourceServerScope, UserPoolClient, OAuthScope, UserPoolDomain } from 'aws-cdk-lib/aws-cognito';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const configPath = path.join(__dirname, '..', 'deployment-config.json');
const deploymentConfig = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const deploymentId = deploymentConfig.deploymentId;

const backend = defineBackend({ auth, data });

// Create OAuth resource server for gateway
const resourceServer = new UserPoolResourceServer(backend.stack, 'GatewayResourceServer', {
  userPool: backend.auth.resources.userPool,
  identifier: 'concierge-gateway',
  userPoolResourceServerName: 'concierge-gateway-resource-server',
  scopes: [new ResourceServerScope({ scopeName: 'invoke', scopeDescription: 'Invoke gateway and targets' })],
});

// Create machine client for M2M auth
const machineClient = new UserPoolClient(backend.stack, 'GatewayMachineClient', {
  userPool: backend.auth.resources.userPool,
  userPoolClientName: 'concierge-gateway-machine-client',
  generateSecret: true,
  oAuth: {
    flows: { clientCredentials: true },
    scopes: [OAuthScope.resourceServer(resourceServer, new ResourceServerScope({ scopeName: 'invoke', scopeDescription: 'Invoke gateway and targets' }))],
  },
});
machineClient.node.addDependency(resourceServer);

// Create Cognito domain
const userPoolDomain = new UserPoolDomain(backend.stack, 'CognitoDomain', {
  userPool: backend.auth.resources.userPool,
  cognitoDomain: { domainPrefix: `concierge-${deploymentId}-${backend.stack.account}` },
});

// Export values for CDK stacks
new CfnOutput(backend.stack, 'UserPoolIdExport', {
  value: backend.auth.resources.userPool.userPoolId,
  exportName: `ConciergeAgent-${deploymentId}-Auth-UserPoolId`,
});
new CfnOutput(backend.stack, 'MachineClientIdExport', {
  value: machineClient.userPoolClientId,
  exportName: `ConciergeAgent-${deploymentId}-Auth-MachineClientId`,
});
new CfnOutput(backend.stack, 'UserProfileTableNameExport', {
  value: backend.data.resources.tables['UserProfile'].tableName,
  exportName: `ConciergeAgent-${deploymentId}-Data-UserProfileTableName`,
});
new CfnOutput(backend.stack, 'WishlistTableNameExport', {
  value: backend.data.resources.tables['Wishlist'].tableName,
  exportName: `ConciergeAgent-${deploymentId}-Data-WishlistTableName`,
});
new CfnOutput(backend.stack, 'FeedbackTableNameExport', {
  value: backend.data.resources.tables['Feedback'].tableName,
  exportName: `ConciergeAgent-${deploymentId}-Data-FeedbackTableName`,
});
EOF
```

#### 4.1.4 Create Amplify package.json

```bash
cat > amplify/package.json << 'EOF'
{
  "name": "amplify-backend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "sandbox": "ampx sandbox",
    "deploy": "ampx sandbox --once"
  },
  "dependencies": {
    "@aws-amplify/backend": "^1.0.4",
    "@aws-amplify/backend-cli": "^1.0.4",
    "aws-cdk-lib": "^2.225.0",
    "constructs": "^10.0.0",
    "typescript": "^5.0.0"
  }
}
EOF
```

#### 4.1.5 Create Amplify tsconfig.json

```bash
cat > amplify/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "strict": true
  }
}
EOF
```

### 4.2 API Keys and Secrets Configuration

#### 4.2.1 Obtain SERP API Key (Product Search)

1. Go to https://serpapi.com/
2. Sign up for free account (100 searches/month free)
3. Navigate to "API Key" in dashboard
4. Copy your API key

**Store in AWS Systems Manager Parameter Store:**
```bash
aws ssm put-parameter \
  --name "/concierge-agent/shopping/serp-api-key" \
  --value "YOUR_SERP_API_KEY_HERE" \
  --type "SecureString" \
  --overwrite \
  --region us-east-1
```

**Verify:**
```bash
aws ssm get-parameter \
  --name "/concierge-agent/shopping/serp-api-key" \
  --with-decryption \
  --region us-east-1 \
  --query 'Parameter.Value' \
  --output text
```


#### 4.2.2 Visa API Credentials (Optional - for real payments)

**Note**: Visa integration can run in MOCK mode without real credentials.

**For real Visa API access:**

1. Contact Visa Developer Platform: https://developer.visa.com/
2. Request access to:
   - Visa Token Service (VTS)
   - Visa In-App Provisioning
3. Obtain credentials:
   - API Key
   - Shared Secret
   - Encryption API Key
   - Encryption Shared Secret
   - Key ID (vic_key_id)
   - MLE Certificates (PEM files)

**Store in AWS Secrets Manager:**
```bash
aws secretsmanager create-secret \
  --name "visa/api-key" \
  --secret-string "YOUR_VISA_API_KEY" \
  --region us-east-1

aws secretsmanager create-secret \
  --name "visa/shared-secret" \
  --secret-string "YOUR_VISA_SHARED_SECRET" \
  --region us-east-1

aws secretsmanager create-secret \
  --name "visa/encryption-api-key" \
  --secret-string "YOUR_ENCRYPTION_API_KEY" \
  --region us-east-1

aws secretsmanager create-secret \
  --name "visa/encryption-shared-secret" \
  --secret-string "YOUR_ENCRYPTION_SHARED_SECRET" \
  --region us-east-1

aws secretsmanager create-secret \
  --name "visa/vic_key_id" \
  --secret-string "YOUR_KEY_ID" \
  --region us-east-1
```

**For MOCK mode (default):**
No Visa credentials needed. Skip this section.

### 4.3 Python Agent Code Setup

#### 4.3.1 Create supervisor agent requirements.txt

```bash
cat > concierge_agent/supervisor_agent/requirements.txt << 'EOF'
bedrock-agentcore>=0.1.2
bedrock-agentcore-starter-toolkit>=0.1.6
boto3>=1.40.8
pydantic>=2.0.0
pydantic-core>=2.33.2
pytz>=2025.2
rapidfuzz>=3.13.0
requests-aws4auth>=1.3.1
strands-agents>=1.4.0
strands-agents-tools>=0.2.3
uv
mcp
requests
gql>=3.4.0
tavily-python
EOF
```

#### 4.3.2 Create supervisor agent Dockerfile

```bash
cat > concierge_agent/supervisor_agent/Dockerfile << 'EOF'
FROM --platform=linux/arm64 python:3.11-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python
RUN pip3 install uv

WORKDIR /app
ENV PYTHONPATH=/app

COPY requirements.txt .
RUN uv pip install --system -r requirements.txt
RUN uv pip install --system aws-opentelemetry-distro>=0.10.1

COPY . .

RUN useradd -m -u 1000 bedrock_agentcore && \
    chown -R bedrock_agentcore:bedrock_agentcore /app
USER bedrock_agentcore

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD pgrep -f "python agent.py" || exit 1

CMD ["opentelemetry-instrument", "python", "agent.py"]
EOF
```

#### 4.3.3 Create MCP shopping tools requirements.txt

```bash
cat > concierge_agent/mcp_shopping_tools/requirements.txt << 'EOF'
mcp>=1.23.3
boto3>=1.40.8
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
pydantic>=2.6.0
anyio>=4.6.0
strands-agents
google-search-results
EOF
```

#### 4.3.4 Create MCP shopping tools Dockerfile

```bash
cat > concierge_agent/mcp_shopping_tools/Dockerfile << 'EOF'
FROM --platform=linux/arm64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONPATH=/app

RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

CMD ["python", "server.py"]
EOF
```

#### 4.3.5 Create MCP cart tools requirements.txt

```bash
cat > concierge_agent/mcp_cart_tools/requirements.txt << 'EOF'
mcp>=1.23.3
boto3>=1.40.8
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
pydantic>=2.6.0
anyio>=4.6.0
EOF
```

#### 4.3.6 Create MCP cart tools Dockerfile

```bash
cat > concierge_agent/mcp_cart_tools/Dockerfile << 'EOF'
FROM --platform=linux/arm64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONPATH=/app

RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

CMD ["python", "server.py"]
EOF
```

**Note**: The actual Python code files (agent.py, server.py, etc.) are complex and should be copied from the source repository. For manual recreation, you would need to implement:

1. **supervisor_agent/agent.py**: Main agent orchestration logic
2. **supervisor_agent/gateway_client.py**: Gateway communication
3. **mcp_shopping_tools/server.py**: MCP server for product search
4. **mcp_cart_tools/server.py**: MCP server for cart operations

These files contain hundreds of lines of business logic and are beyond the scope of this setup guide.


### 4.4 Infrastructure as Code (CDK) Setup

#### 4.4.1 Create MCP servers CDK package.json

```bash
cat > infrastructure/mcp-servers/package.json << 'EOF'
{
  "name": "mcp-servers",
  "version": "1.0.0",
  "scripts": {
    "deploy": "cdk deploy --require-approval never",
    "destroy": "cdk destroy"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "aws-cdk": "^2.225.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.3.3"
  },
  "dependencies": {
    "@aws-cdk/aws-bedrock-agentcore-alpha": "^2.225.0-alpha.0",
    "aws-cdk-lib": "^2.225.0",
    "constructs": "^10.3.0",
    "source-map-support": "^0.5.21"
  }
}
EOF
```

#### 4.4.2 Create MCP servers cdk.json

```bash
cat > infrastructure/mcp-servers/cdk.json << 'EOF'
{
  "app": "npx ts-node --prefer-ts-exts lib/app.ts",
  "watch": {
    "include": ["**"],
    "exclude": [
      "README.md",
      "cdk*.json",
      "**/*.d.ts",
      "**/*.js",
      "tsconfig.json",
      "package*.json",
      "yarn.lock",
      "node_modules",
      "test"
    ]
  },
  "context": {
    "@aws-cdk/aws-lambda:recognizeLayerVersion": true,
    "@aws-cdk/core:checkSecretUsage": true,
    "@aws-cdk/core:target-partitions": ["aws", "aws-cn"],
    "@aws-cdk-containers/ecs-service-extensions:enableDefaultLogDriver": true,
    "@aws-cdk/aws-ec2:uniqueImdsv2TemplateName": true,
    "@aws-cdk/aws-ecs:arnFormatIncludesClusterName": true,
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:validateSnapshotRemovalPolicy": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeyAliasStackSafeResourceName": true,
    "@aws-cdk/aws-s3:createDefaultLoggingPolicy": true,
    "@aws-cdk/aws-sns-subscriptions:restrictSqsDescryption": true,
    "@aws-cdk/aws-apigateway:disableCloudWatchRole": true,
    "@aws-cdk/core:enablePartitionLiterals": true,
    "@aws-cdk/aws-events:eventsTargetQueueSameAccount": true,
    "@aws-cdk/aws-iam:standardizedServicePrincipals": true,
    "@aws-cdk/aws-ecs:disableExplicitDeploymentControllerForCircuitBreaker": true,
    "@aws-cdk/aws-iam:importedRoleStackSafeDefaultPolicyName": true,
    "@aws-cdk/aws-s3:serverAccessLogsUseBucketPolicy": true,
    "@aws-cdk/aws-route53-patters:useCertificate": true,
    "@aws-cdk/customresources:installLatestAwsSdkDefault": false,
    "@aws-cdk/aws-rds:databaseProxyUniqueResourceName": true,
    "@aws-cdk/aws-codedeploy:removeAlarmsFromDeploymentGroup": true,
    "@aws-cdk/aws-apigateway:authorizerChangeDeploymentLogicalId": true,
    "@aws-cdk/aws-ec2:launchTemplateDefaultUserData": true,
    "@aws-cdk/aws-secretsmanager:useAttachedSecretResourcePolicyForSecretTargetAttachments": true,
    "@aws-cdk/aws-redshift:columnId": true,
    "@aws-cdk/aws-stepfunctions-tasks:enableEmrServicePolicyV2": true,
    "@aws-cdk/aws-ec2:restrictDefaultSecurityGroup": true,
    "@aws-cdk/aws-apigateway:requestValidatorUniqueId": true,
    "@aws-cdk/aws-kms:aliasNameRef": true,
    "@aws-cdk/aws-autoscaling:generateLaunchTemplateInsteadOfLaunchConfig": true,
    "@aws-cdk/core:includePrefixInUniqueNameGeneration": true,
    "@aws-cdk/aws-efs:denyAnonymousAccess": true,
    "@aws-cdk/aws-opensearchservice:enableOpensearchMultiAzWithStandby": true,
    "@aws-cdk/aws-lambda-nodejs:useLatestRuntimeVersion": true,
    "@aws-cdk/aws-efs:mountTargetOrderInsensitiveLogicalId": true,
    "@aws-cdk/aws-rds:auroraClusterChangeScopeOfInstanceParameterGroupWithEachParameters": true,
    "@aws-cdk/aws-appsync:useArnForSourceApiAssociationIdentifier": true,
    "@aws-cdk/aws-rds:preventRenderingDeprecatedCredentials": true,
    "@aws-cdk/aws-codepipeline-actions:useNewDefaultBranchForCodeCommitSource": true,
    "@aws-cdk/aws-cloudwatch-actions:changeLambdaPermissionLogicalIdForLambdaAction": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeysDefaultValueToFalse": true,
    "@aws-cdk/aws-codepipeline:defaultPipelineTypeToV2": true,
    "@aws-cdk/aws-kms:reduceCrossAccountRegionPolicyScope": true,
    "@aws-cdk/aws-eks:nodegroupNameAttribute": true,
    "@aws-cdk/aws-ec2:ebsDefaultGp3Volume": true,
    "@aws-cdk/aws-ecs:removeDefaultDeploymentAlarm": true,
    "@aws-cdk/custom-resources:logApiResponseDataPropertyTrueDefault": false,
    "@aws-cdk/aws-s3:keepNotificationInImportedBucket": false
  }
}
EOF
```

#### 4.4.3 Create agent stack package.json

```bash
cat > infrastructure/agent-stack/package.json << 'EOF'
{
  "name": "agent-stack",
  "version": "1.0.0",
  "scripts": {
    "deploy": "cdk deploy --require-approval never",
    "destroy": "cdk destroy"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "aws-cdk": "^2.225.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.3.3"
  },
  "dependencies": {
    "@aws-cdk/aws-bedrock-agentcore-alpha": "^2.225.0-alpha.0",
    "aws-cdk-lib": "^2.225.0",
    "constructs": "^10.3.0",
    "source-map-support": "^0.5.21"
  }
}
EOF
```

#### 4.4.4 Create frontend stack package.json

```bash
cat > infrastructure/frontend-stack/package.json << 'EOF'
{
  "name": "frontend-stack",
  "version": "1.0.0",
  "scripts": {
    "deploy": "cdk deploy --require-approval never",
    "destroy": "cdk destroy"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "aws-cdk": "^2.225.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.3.3"
  },
  "dependencies": {
    "@aws-cdk/aws-amplify-alpha": "^2.225.0-alpha.0",
    "aws-cdk-lib": "^2.225.0",
    "constructs": "^10.3.0",
    "source-map-support": "^0.5.21"
  }
}
EOF
```

#### 4.4.5 Create Visa Lambda stack package.json

```bash
cat > infrastructure/visa-lambda-stack/package.json << 'EOF'
{
  "name": "visa-lambda-stack",
  "version": "0.1.0",
  "bin": {
    "visa-lambda-stack": "bin/visa-lambda-stack.js"
  },
  "scripts": {
    "build": "tsc",
    "watch": "tsc -w",
    "test": "jest",
    "cdk": "cdk"
  },
  "devDependencies": {
    "@types/jest": "^29.5.14",
    "@types/node": "22.7.9",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.5",
    "aws-cdk": "2.225.0",
    "ts-node": "^10.9.2",
    "typescript": "~5.9.3"
  },
  "dependencies": {
    "aws-cdk-lib": "2.225.0",
    "constructs": "^10.0.0"
  }
}
EOF
```

**Note**: The actual CDK stack TypeScript files (agent-stack.ts, cart-stack.ts, etc.) are complex infrastructure definitions. For manual recreation, you would need to implement:

1. **infrastructure/mcp-servers/lib/app.ts**: MCP server stacks
2. **infrastructure/agent-stack/lib/agent-stack.ts**: Main agent infrastructure
3. **infrastructure/frontend-stack/lib/frontend-stack.ts**: Amplify hosting
4. **infrastructure/visa-lambda-stack/lib/visa-lambda-stack.ts**: Visa proxy Lambda

These files define ECS clusters, task definitions, IAM roles, security groups, and more.


### 4.5 Frontend (React) Setup

#### 4.5.1 Create web-ui package.json

```bash
cat > web-ui/package.json << 'EOF'
{
  "name": "agent-core-ui",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "typecheck": "tsc --project tsconfig.json --skipLibCheck",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview"
  },
  "dependencies": {
    "@aws-amplify/ui-react": "^6.0.0",
    "@aws-sdk/client-bedrock-agentcore": "^3.0.0",
    "@aws-sdk/client-dynamodb": "^3.896.0",
    "@aws-sdk/credential-providers": "^3.0.0",
    "aws-amplify": "^6.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-markdown": "^10.1.0",
    "react-toastify": "^11.0.5",
    "rehype-highlight": "^7.0.2",
    "remark-gfm": "^4.0.1",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4.1.17",
    "@types/react": "^18.2.66",
    "@types/react-dom": "^18.2.22",
    "@types/uuid": "^9.0.0",
    "@typescript-eslint/eslint-plugin": "^7.2.0",
    "@typescript-eslint/parser": "^7.2.0",
    "@vitejs/plugin-basic-ssl": "^1.1.0",
    "@vitejs/plugin-react": "^4.2.1",
    "autoprefixer": "^10.4.22",
    "eslint": "^8.57.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.6",
    "postcss": "^8.5.6",
    "tailwindcss": "^4.1.17",
    "typescript": "^5.2.2",
    "vite": "^5.2.0"
  }
}
EOF
```

#### 4.5.2 Create web-ui vite.config.ts

```bash
cat > web-ui/vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import basicSsl from '@vitejs/plugin-basic-ssl'

export default defineConfig({
  plugins: [
    react(),
    basicSsl()
  ],
  server: {
    https: true,
    port: 9000,
    host: 'vcas.local.com',
  }
})
EOF
```

#### 4.5.3 Create web-ui .env.local.example

```bash
cat > web-ui/.env.local.example << 'EOF'
# AWS Configuration
VITE_AWS_REGION=us-east-1

# Cognito Configuration
VITE_USER_POOL_ID=your-user-pool-id
VITE_USER_POOL_CLIENT_ID=your-client-id

# Agent Runtime Configuration
VITE_AGENT_RUNTIME_ARN=your-agent-runtime-arn-here
VITE_AGENT_ENDPOINT_NAME=DEFAULT

# Visa Integration (Mock mode by default)
VITE_VISA_MOCK_MODE=true
VITE_VISA_PROXY_URL=https://YOUR_API_GATEWAY_URL_HERE/
VITE_VISA_API_KEY=your-visa-api-key
VITE_VISA_CLIENT_APP_ID=VICTestAccountTR
VITE_VISA_IFRAME_URL=https://sbx.vts.auth.visa.com
EOF
```

**Note**: The actual React components (App.tsx, components/, services/, etc.) contain the UI logic and should be copied from the source repository.

### 4.6 Deployment Scripts

#### 4.6.1 Create setup-web-ui-env.sh

```bash
cat > scripts/setup-web-ui-env.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Setting up Web UI environment..."

DEPLOYMENT_ID=$(node -p "require('./deployment-config.json').deploymentId" 2>/dev/null || echo "default")
STACK_NAME="AgentStack-${DEPLOYMENT_ID}"

FORCE=false
MOCK_MODE=""
for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --mock) MOCK_MODE="true" ;;
        --no-mock) MOCK_MODE="false" ;;
    esac
done

if [[ -f "web-ui/.env.local" && "$FORCE" == "false" ]]; then
    echo "⚠️  web-ui/.env.local already exists"
    echo "   Run with --force to regenerate"
    exit 0
fi

echo "📊 Querying ${STACK_NAME}..."
CDK_OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region us-east-1 --query "Stacks[0].Outputs" --output json 2>/dev/null) || {
    echo "❌ Could not query ${STACK_NAME}. Deploy agent stack first."
    exit 1
}

RUNTIME_ARN=$(echo "$CDK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="MainRuntimeArn") | .OutputValue // empty')
RUNTIME_ID=$(echo "$CDK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="MainRuntimeId") | .OutputValue // empty')
MEMORY_ID=$(echo "$CDK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="MemoryId") | .OutputValue // empty')
GATEWAY_URL=$(echo "$CDK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="GatewayUrl") | .OutputValue // empty')
GATEWAY_ID=$(echo "$CDK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="GatewayId") | .OutputValue // empty')

VISA_STACK_NAME="VisaLambdaStack-${DEPLOYMENT_ID}"
VISA_OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$VISA_STACK_NAME" --region us-east-1 --query "Stacks[0].Outputs" --output json 2>/dev/null) || VISA_PROXY_URL=""
if [[ -n "$VISA_OUTPUTS" && "$VISA_OUTPUTS" != "null" ]]; then
    VISA_PROXY_URL=$(echo "$VISA_OUTPUTS" | jq -r '.[] | select(.OutputKey=="VisaProxyApiUrl") | .OutputValue // empty')
    VISA_PROXY_URL=${VISA_PROXY_URL%/}
fi

VISA_API_KEY=$(aws secretsmanager get-secret-value --secret-id "visa/api-key" --query SecretString --output text 2>/dev/null) || VISA_API_KEY=""

if [[ ! -f "amplify_outputs.json" ]]; then
    echo "❌ amplify_outputs.json not found. Deploy Amplify first."
    exit 1
fi

REGION=$(jq -r '.custom.region // "us-east-1"' amplify_outputs.json)
USER_POOL_ID=$(jq -r '.auth.user_pool_id // empty' amplify_outputs.json)
USER_POOL_CLIENT_ID=$(jq -r '.auth.user_pool_client_id // empty' amplify_outputs.json)

if [[ -z "$RUNTIME_ARN" || -z "$USER_POOL_ID" || -z "$USER_POOL_CLIENT_ID" ]]; then
    echo "❌ Missing required values. Ensure both stacks are deployed."
    exit 1
fi

if [[ "$MOCK_MODE" == "true" ]]; then
    FINAL_MOCK_MODE="true"
else
    FINAL_MOCK_MODE="false"
fi

cat > web-ui/.env.local << ENVEOF
# Auto-generated by setup-web-ui-env.sh
# Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

VITE_AWS_REGION=${REGION}
VITE_USER_POOL_ID=${USER_POOL_ID}
VITE_USER_POOL_CLIENT_ID=${USER_POOL_CLIENT_ID}
VITE_AGENT_RUNTIME_ARN=${RUNTIME_ARN}
VITE_AGENT_RUNTIME_ID=${RUNTIME_ID}
VITE_AGENT_ENDPOINT_NAME=DEFAULT
VITE_MEMORY_ID=${MEMORY_ID}
VITE_GATEWAY_URL=${GATEWAY_URL}
VITE_GATEWAY_ID=${GATEWAY_ID}
VITE_VISA_MOCK_MODE=${FINAL_MOCK_MODE}
VISA_INTEGRATION_ENABLED=true
VITE_VISA_API_KEY=${VISA_API_KEY}
VITE_VISA_CLIENT_APP_ID=VICTestAccountTR
VITE_VISA_IFRAME_URL=https://sbx.vts.auth.visa.com
VITE_VISA_PROXY_URL=${VISA_PROXY_URL}
ENVEOF

echo "✅ Created web-ui/.env.local"
echo ""
echo "Next: cd web-ui && npm run dev"
EOF

chmod +x scripts/setup-web-ui-env.sh
```


#### 4.6.2 Create sync-gateway.sh

```bash
cat > scripts/sync-gateway.sh << 'EOF'
#!/bin/bash
set -e

export AWS_REGION=${AWS_REGION:-us-east-1}
DEPLOYMENT_ID=$(node -p "require('./deployment-config.json').deploymentId")

echo "🔄 Synchronizing gateway targets for deployment: $DEPLOYMENT_ID"

GATEWAY_ID=$(aws bedrock-agentcore-control list-gateways \
  --query "items[?contains(name, 'agentstack-${DEPLOYMENT_ID}')].gatewayId | [0]" \
  --output text)

if [ -z "$GATEWAY_ID" ] || [ "$GATEWAY_ID" == "None" ]; then
  echo "❌ No gateway found for deployment: $DEPLOYMENT_ID"
  exit 1
fi

echo "Found gateway: $GATEWAY_ID"

TARGET_IDS=$(aws bedrock-agentcore-control list-gateway-targets \
  --gateway-identifier "$GATEWAY_ID" \
  --query 'items[].targetId' \
  --output text)

echo "Found targets: $TARGET_IDS"

for TARGET_ID in $TARGET_IDS; do
  echo "Syncing target: $TARGET_ID"
  aws bedrock-agentcore-control synchronize-gateway-targets \
    --gateway-identifier "$GATEWAY_ID" \
    --target-id-list "[\"$TARGET_ID\"]" \
    --no-cli-pager
done

echo "Synchronization started. Waiting for completion..."

for i in {1..30}; do
  sleep 10
  
  NOT_READY=$(aws bedrock-agentcore-control list-gateway-targets \
    --gateway-identifier "$GATEWAY_ID" \
    --query 'items[?status!=`READY`].name' \
    --output text)
  
  if [ -z "$NOT_READY" ]; then
    echo "✅ All targets synchronized!"
    exit 0
  fi
  
  echo "Waiting... (not ready: $NOT_READY)"
done

echo "⚠️ Timeout waiting for synchronization"
exit 1
EOF

chmod +x scripts/sync-gateway.sh
```

#### 4.6.3 Create set-api-keys.sh

```bash
cat > scripts/set-api-keys.sh << 'EOF'
#!/bin/bash

REGION="us-east-1"

echo "🔑 Setting API keys in AWS Systems Manager Parameter Store..."
echo ""

read -p "Enter SERP API Key (or press Enter to skip): " SERP_KEY
if [ ! -z "$SERP_KEY" ]; then
  aws ssm put-parameter \
    --name "/concierge-agent/shopping/serp-api-key" \
    --value "$SERP_KEY" \
    --type "SecureString" \
    --overwrite \
    --region $REGION
  echo "✅ SERP API key set"
fi

echo ""
echo "🎉 API keys configuration complete!"
EOF

chmod +x scripts/set-api-keys.sh
```

---

## Phase 5: Deployment and Execution

### 5.1 Pre-Deployment Validation

#### 5.1.1 Verify all prerequisites

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Docker is running
docker ps

# Check Node.js version
node --version  # Should be 18+

# Check Python version
python3.11 --version

# Check CDK version
cdk --version  # Should be 2.225.0
```

#### 5.1.2 Install all dependencies

```bash
# Root dependencies
npm install

# Install CDK dependencies
cd infrastructure/mcp-servers && npm install && cd ../..
cd infrastructure/agent-stack && npm install && cd ../..
cd infrastructure/frontend-stack && npm install && cd ../..
cd infrastructure/visa-lambda-stack && npm install && cd ../..

# Install web-ui dependencies
cd web-ui && npm install && cd ..

# Install Amplify dependencies
cd amplify && npm install && cd ..
```

### 5.2 Step-by-Step Deployment

#### 5.2.1 Deploy Amplify Backend (Cognito + DynamoDB)

**Purpose**: Creates authentication and database infrastructure.

**Time**: ~5-8 minutes

```bash
npm run deploy:amplify
```

**What this does:**
1. Creates Cognito User Pool for authentication
2. Creates Cognito User Pool Client for web app
3. Creates Cognito Machine Client for M2M auth
4. Creates DynamoDB tables (UserProfile, Wishlist, Feedback)
5. Creates GraphQL API with AppSync
6. Exports CloudFormation values for other stacks

**Expected output:**
```
✨  Deployment time: 320.45s

Outputs:
amplify-concierge-agent-shopping-sandbox-<hash>
  UserPoolIdExport = us-east-1_XXXXXXXXX
  MachineClientIdExport = XXXXXXXXXXXXXXXXXXXXXXXXXX
  UserProfileTableNameExport = UserProfile-<hash>
  ...

amplify_outputs.json created successfully
```

**Verify deployment:**
```bash
# Check Cognito User Pool
aws cognito-idp list-user-pools --max-results 10 --region us-east-1

# Check DynamoDB tables
aws dynamodb list-tables --region us-east-1

# Verify amplify_outputs.json exists
ls -la amplify_outputs.json
```

**Troubleshooting:**
- **Error: "User pool domain already exists"**: Change `deploymentId` in deployment-config.json
- **Error: "Insufficient permissions"**: Verify IAM user has AdministratorAccess
- **Error: "CDK not bootstrapped"**: Run `cdk bootstrap aws://$AWS_ACCOUNT_ID/us-east-1`

#### 5.2.2 Set API Keys

**Purpose**: Store SERP API key for product search.

```bash
./scripts/set-api-keys.sh
```

**Prompt:**
```
Enter SERP API Key (or press Enter to skip): <paste your SERP API key>
```

**Verify:**
```bash
aws ssm get-parameter \
  --name "/concierge-agent/shopping/serp-api-key" \
  --with-decryption \
  --region us-east-1
```

#### 5.2.3 Deploy MCP Servers

**Purpose**: Deploy containerized MCP tool servers (Shopping + Cart).

**Time**: ~8-12 minutes

```bash
npm run deploy:mcp
```

**What this does:**
1. Builds Docker images for shopping and cart MCP servers
2. Pushes images to Amazon ECR
3. Creates ECS Fargate clusters (ARM64)
4. Deploys ECS services with auto-scaling
5. Creates IAM roles for DynamoDB and Secrets Manager access
6. Exports runtime ARNs for agent stack

**Expected output:**
```
✅  CartStack-shopping
✅  ShoppingStack-shopping

Outputs:
CartStack-shopping.RuntimeArn = arn:aws:bedrock-agentcore:us-east-1:...
ShoppingStack-shopping.RuntimeArn = arn:aws:bedrock-agentcore:us-east-1:...

Stack ARN:
arn:aws:cloudformation:us-east-1:...
```

**Verify deployment:**
```bash
# Check ECS clusters
aws ecs list-clusters --region us-east-1

# Check ECS services
aws ecs list-services --cluster CartStack-shopping-Cluster --region us-east-1

# Check ECR repositories
aws ecr describe-repositories --region us-east-1
```

**Troubleshooting:**
- **Error: "Docker daemon not running"**: Start Docker Desktop
- **Error: "No space left on device"**: Clean Docker images: `docker system prune -a`
- **Error: "Task failed to start"**: Check CloudWatch logs for container errors


#### 5.2.4 Deploy Agent Stack (Supervisor Agent + Gateway)

**Purpose**: Deploy main agent runtime with gateway and memory.

**Time**: ~10-15 minutes

```bash
npm run deploy:agent
```

**What this does:**
1. Builds Docker image for supervisor agent
2. Pushes image to Amazon ECR
3. Creates ECS Fargate service for agent
4. Creates AgentCore Memory resource
5. Creates AgentCore Gateway with MCP targets
6. Creates OAuth2 credential provider
7. Synchronizes gateway targets
8. Stores gateway URL in SSM Parameter Store

**Expected output:**
```
✅  AgentStack-shopping

Outputs:
AgentStack-shopping.MainRuntimeArn = arn:aws:bedrock-agentcore:...
AgentStack-shopping.MainRuntimeId = runtime-XXXXXXXXXX
AgentStack-shopping.MemoryId = memory-XXXXXXXXXX
AgentStack-shopping.GatewayUrl = https://gateway-XXXXXXXXXX.bedrock-agentcore.us-east-1.amazonaws.com
AgentStack-shopping.GatewayId = gateway-XXXXXXXXXX

🔄 Synchronizing gateway targets...
✅ All targets synchronized!
```

**Verify deployment:**
```bash
# Check agent runtime
aws bedrock-agentcore-control list-runtimes --region us-east-1

# Check gateway
aws bedrock-agentcore-control list-gateways --region us-east-1

# Check gateway targets
GATEWAY_ID=$(aws cloudformation describe-stacks \
  --stack-name AgentStack-shopping \
  --query 'Stacks[0].Outputs[?OutputKey==`GatewayId`].OutputValue' \
  --output text)

aws bedrock-agentcore-control list-gateway-targets \
  --gateway-identifier $GATEWAY_ID \
  --region us-east-1
```

**Troubleshooting:**
- **Error: "Cannot import MCP runtime ARN"**: Ensure MCP stacks deployed first
- **Error: "Gateway synchronization timeout"**: Check ECS task health in console
- **Error: "Memory resource creation failed"**: Verify Bedrock service is enabled

#### 5.2.5 Deploy Visa Lambda (Optional)

**Purpose**: Deploy Lambda proxy for Visa API calls (skip if using mock mode).

**Time**: ~3-5 minutes

```bash
npm run deploy:visa-lambda
```

**What this does:**
1. Creates Lambda function for Visa API proxy
2. Creates API Gateway REST API
3. Configures CORS and authentication
4. Grants Lambda access to Secrets Manager

**Expected output:**
```
✅  VisaLambdaStack-shopping

Outputs:
VisaLambdaStack-shopping.VisaProxyApiUrl = https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/prod/
```

**Verify deployment:**
```bash
# Check Lambda function
aws lambda list-functions --region us-east-1 | grep visa

# Check API Gateway
aws apigateway get-rest-apis --region us-east-1
```

**Note**: If skipping Visa integration, the frontend will use mock mode automatically.

#### 5.2.6 Setup Web UI Environment

**Purpose**: Generate .env.local with deployed infrastructure values.

```bash
./scripts/setup-web-ui-env.sh --force
```

**What this does:**
1. Queries CloudFormation stacks for outputs
2. Reads amplify_outputs.json
3. Fetches Visa credentials from Secrets Manager
4. Generates web-ui/.env.local with all configuration

**Expected output:**
```
✅ Created web-ui/.env.local
✅ Visa proxy URL configured: https://...
✅ Visa API key loaded from Secrets Manager

Next: cd web-ui && npm run dev
```

**Verify:**
```bash
cat web-ui/.env.local
```

Should contain:
- VITE_AWS_REGION
- VITE_USER_POOL_ID
- VITE_USER_POOL_CLIENT_ID
- VITE_AGENT_RUNTIME_ARN
- VITE_GATEWAY_URL
- VITE_VISA_PROXY_URL (if deployed)

#### 5.2.7 Deploy Frontend to Amplify Hosting (Optional)

**Purpose**: Host web UI on AWS Amplify (alternative to local dev server).

**Time**: ~5-8 minutes

```bash
npm run deploy:frontend
```

**What this does:**
1. Creates Amplify Hosting app
2. Creates S3 staging bucket
3. Builds React app
4. Uploads build to S3
5. Triggers Amplify deployment
6. Monitors deployment status

**Expected output:**
```
✅ Deployment completed successfully!

App URL: https://main.XXXXXXXXXX.amplifyapp.com
Console: https://console.aws.amazon.com/amplify/apps/XXXXXXXXXX
```

**Verify:**
```bash
# Check Amplify app
aws amplify list-apps --region us-east-1

# Open in browser
open https://main.XXXXXXXXXX.amplifyapp.com
```

### 5.3 Local Development Server

#### 5.3.1 Start local web UI

```bash
cd web-ui
npm run dev
```

**Expected output:**
```
  VITE v5.2.0  ready in 500 ms

  ➜  Local:   https://vcas.local.com:9000/
  ➜  Network: use --host to expose
  ➜  press h + enter to show help
```

#### 5.3.2 Access the application

Open browser to: **https://vcas.local.com:9000/**

**Note**: You'll see a security warning for self-signed certificate. Click "Advanced" → "Proceed to vcas.local.com".

#### 5.3.3 Create test user

1. Click "Create Account"
2. Fill in:
   - Email: test@example.com
   - Password: Test123!@#
   - Given Name: Test
   - Family Name: User
3. Check email for verification code
4. Enter verification code
5. Sign in

### 5.4 Deployment Validation

#### 5.4.1 Test authentication

```bash
# List Cognito users
aws cognito-idp list-users \
  --user-pool-id $(jq -r '.auth.user_pool_id' amplify_outputs.json) \
  --region us-east-1
```

#### 5.4.2 Test agent runtime

```bash
# Check agent runtime status
RUNTIME_ID=$(aws cloudformation describe-stacks \
  --stack-name AgentStack-shopping \
  --query 'Stacks[0].Outputs[?OutputKey==`MainRuntimeId`].OutputValue' \
  --output text)

aws bedrock-agentcore-control get-runtime \
  --runtime-identifier $RUNTIME_ID \
  --region us-east-1
```

**Expected status**: `READY`

#### 5.4.3 Test MCP servers

```bash
# Check ECS task health
aws ecs describe-services \
  --cluster CartStack-shopping-Cluster \
  --services CartStack-shopping-Service \
  --region us-east-1 \
  --query 'services[0].runningCount'
```

**Expected**: `1` (or more if scaled)

#### 5.4.4 Test end-to-end conversation

1. Open web UI: https://vcas.local.com:9000/
2. Sign in with test user
3. Send message: "Show me laptops under $1000"
4. Verify:
   - Agent responds with streaming text
   - Tool usage indicators appear
   - Product results are displayed
   - No errors in browser console

---

## Phase 6: Verification, Testing, and Rollback

### 6.1 Comprehensive Testing

#### 6.1.1 Authentication Tests

**Test 1: User Registration**
```bash
# Via AWS CLI
aws cognito-idp sign-up \
  --client-id $(jq -r '.auth.user_pool_client_id' amplify_outputs.json) \
  --username test2@example.com \
  --password Test123!@# \
  --user-attributes Name=email,Value=test2@example.com \
  --region us-east-1
```

**Test 2: User Sign-In**
- Use web UI to sign in
- Verify JWT token in browser DevTools → Application → Local Storage

**Test 3: Session Persistence**
- Sign in
- Refresh page
- Verify still signed in

#### 6.1.2 Agent Functionality Tests

**Test 1: Product Search**
```
User: "Find me wireless headphones"
Expected: Agent uses shopping tools, returns product list
```

**Test 2: Cart Operations**
```
User: "Add the first item to my cart"
Expected: Agent adds item to DynamoDB, confirms addition
```

**Test 3: Conversation Memory**
```
User: "What did I just add?"
Expected: Agent remembers previous context
```

**Test 4: Payment Flow (Mock Mode)**
```
User: "I want to checkout"
Expected: Agent initiates mock payment flow
```

#### 6.1.3 Infrastructure Health Checks

```bash
# Check all CloudFormation stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --region us-east-1 \
  --query 'StackSummaries[?contains(StackName, `shopping`)].StackName'

# Check ECS task health
aws ecs list-tasks \
  --cluster CartStack-shopping-Cluster \
  --region us-east-1

# Check CloudWatch logs
aws logs tail /aws/ecs/AgentStack-shopping --follow --region us-east-1
```

### 6.2 Monitoring and Observability

#### 6.2.1 CloudWatch Dashboards

**Create custom dashboard:**
```bash
aws cloudwatch put-dashboard \
  --dashboard-name shopping-agent-dashboard \
  --dashboard-body file://dashboard.json \
  --region us-east-1
```

**Key metrics to monitor:**
- ECS task CPU/Memory utilization
- Agent invocation count
- Agent error rate
- DynamoDB read/write capacity
- API Gateway request count
- Lambda invocation duration

#### 6.2.2 CloudWatch Logs

**View agent logs:**
```bash
aws logs tail /aws/ecs/AgentStack-shopping --follow --region us-east-1
```

**View MCP server logs:**
```bash
aws logs tail /aws/ecs/CartStack-shopping --follow --region us-east-1
aws logs tail /aws/ecs/ShoppingStack-shopping --follow --region us-east-1
```

#### 6.2.3 X-Ray Tracing

**Enable X-Ray (if not already enabled):**
```bash
# X-Ray is automatically enabled via OpenTelemetry in agent container
# View traces in AWS Console: https://console.aws.amazon.com/xray/
```

### 6.3 Troubleshooting Common Issues

#### Issue 1: Agent not responding

**Symptoms**: Web UI shows "Connecting..." indefinitely

**Diagnosis:**
```bash
# Check agent runtime status
aws bedrock-agentcore-control get-runtime \
  --runtime-identifier $RUNTIME_ID \
  --region us-east-1 \
  --query 'status'
```

**Solutions:**
- If status is `CREATING`: Wait 5-10 minutes
- If status is `FAILED`: Check CloudWatch logs for errors
- If status is `READY`: Check gateway synchronization

#### Issue 2: Gateway targets not synchronized

**Symptoms**: Agent can't call MCP tools

**Diagnosis:**
```bash
aws bedrock-agentcore-control list-gateway-targets \
  --gateway-identifier $GATEWAY_ID \
  --region us-east-1 \
  --query 'items[].status'
```

**Solution:**
```bash
./scripts/sync-gateway.sh
```

#### Issue 3: SERP API errors

**Symptoms**: Product search returns no results

**Diagnosis:**
```bash
# Check SERP API key
aws ssm get-parameter \
  --name "/concierge-agent/shopping/serp-api-key" \
  --with-decryption \
  --region us-east-1
```

**Solutions:**
- Verify API key is valid
- Check SERP API quota: https://serpapi.com/dashboard
- Update key: `./scripts/set-api-keys.sh`

#### Issue 4: DynamoDB throttling

**Symptoms**: Cart operations fail intermittently

**Diagnosis:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=Wishlist-<hash> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region us-east-1
```

**Solution:**
- Enable DynamoDB auto-scaling
- Or switch to on-demand billing mode

