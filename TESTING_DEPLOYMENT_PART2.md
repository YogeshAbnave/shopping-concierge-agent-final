# Testing & Deployment Interview Guide - Part 2
## CI/CD, Secrets Management, and Production Operations

---

## 3. CI/CD Pipeline Architecture

### Q6: "Describe your CI/CD pipeline from commit to production."

**What the interviewer is testing:**
- CI/CD best practices
- Automated testing integration
- Deployment automation
- Quality gates

**Strong Answer:**

"I implemented a multi-stage CI/CD pipeline with automated testing and quality gates:

**Pipeline Architecture:**

```
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: Code Commit (GitHub)                               │
│   ├── Developer pushes to feature branch                    │
│   ├── Webhook triggers GitHub Actions                       │
│   └── Time: <1 second                                       │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 2: Build & Unit Tests                                 │
│   ├── Checkout code                                         │
│   ├── Install dependencies (pip, npm)                       │
│   ├── Run linters (pylint, eslint)                          │
│   ├── Run unit tests (pytest)                               │
│   ├── Generate coverage report                              │
│   └── Time: 3-5 minutes                                     │
│   Quality Gate: 80% coverage, 0 lint errors                 │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 3: Security Scanning                                  │
│   ├── Dependency check (safety, npm audit)                  │
│   ├── SAST scan (CodeQL)                                    │
│   ├── Container scan (Trivy)                                │
│   ├── Secret detection (git-secrets)                        │
│   └── Time: 2-3 minutes                                     │
│   Quality Gate: 0 critical vulnerabilities                  │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 4: Build Docker Images                                │
│   ├── Build multi-arch images (ARM64, x86)                  │
│   ├── Tag with commit SHA                                   │
│   ├── Push to ECR                                           │
│   └── Time: 5-7 minutes                                     │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 5: Deploy to Dev                                      │
│   ├── CDK deploy (dev environment)                          │
│   ├── Run smoke tests                                       │
│   ├── Validate health checks                                │
│   └── Time: 3-4 minutes                                     │
│   Quality Gate: All smoke tests pass                        │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 6: Integration Tests                                  │
│   ├── Run integration test suite                            │
│   ├── Test service-to-service communication                 │
│   ├── Test database operations                              │
│   ├── Test external API integration                         │
│   └── Time: 5-7 minutes                                     │
│   Quality Gate: 100% integration tests pass                 │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 7: Deploy to Staging                                  │
│   ├── CDK deploy (staging environment)                      │
│   ├── Run E2E tests                                         │
│   ├── Run load tests (10x normal traffic)                   │
│   ├── Validate performance metrics                          │
│   └── Time: 10-15 minutes                                   │
│   Quality Gate: E2E tests pass, latency <2s                 │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 8: Manual Approval (Production)                       │
│   ├── Product owner review                                  │
│   ├── Release notes generated                               │
│   ├── Rollback plan documented                              │
│   └── Time: Variable (human approval)                       │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 9: Deploy to Production                               │
│   ├── Blue/Green deployment                                 │
│   ├── Gradual traffic shift (10% → 50% → 100%)              │
│   ├── Monitor error rates and latency                       │
│   ├── Automatic rollback if error rate >1%                  │
│   └── Time: 15-20 minutes                                   │
│   Quality Gate: Error rate <0.5%, latency <2s               │
└─────────────────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 10: Post-Deployment Validation                        │
│   ├── Smoke tests in production                             │
│   ├── Monitor CloudWatch metrics                            │
│   ├── Verify X-Ray traces                                   │
│   ├── Check error logs                                      │
│   └── Time: 5-10 minutes                                    │
└─────────────────────────────────────────────────────────────┘

Total Time: 45-60 minutes (commit to production)
```

**GitHub Actions Workflow:**

```yaml
# .github/workflows/deploy.yml
name: Deploy TradeIQ

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: tradeiq

jobs:
  # Stage 1: Build & Test
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.13'
      
      - name: Install dependencies
        run: |
          pip install -r concierge_agent/mcp_cart_tools/requirements.txt
          pip install pytest pytest-cov pytest-mock
      
      - name: Run linters
        run: |
          pip install pylint
          pylint concierge_agent/mcp_cart_tools/*.py
      
      - name: Run unit tests
        run: |
          pytest tests/unit --cov=concierge_agent --cov-report=xml --cov-report=term
      
      - name: Check coverage
        run: |
          COVERAGE=$(python -c "import xml.etree.ElementTree as ET; tree = ET.parse('coverage.xml'); print(tree.getroot().attrib['line-rate'])")
          if (( $(echo "$COVERAGE < 0.80" | bc -l) )); then
            echo "Coverage $COVERAGE is below 80%"
            exit 1
          fi
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
  
  # Stage 2: Security Scanning
  security-scan:
    runs-on: ubuntu-latest
    needs: build-and-test
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Run dependency check
        run: |
          pip install safety
          safety check --json
      
      - name: Run SAST scan
        uses: github/codeql-action/analyze@v2
        with:
          languages: python, javascript
      
      - name: Run container scan
        run: |
          docker build -t tradeiq:latest ./concierge_agent/mcp_cart_tools
          docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image tradeiq:latest
      
      - name: Check for secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
  
  # Stage 3: Build Docker Images
  build-images:
    runs-on: ubuntu-latest
    needs: [build-and-test, security-scan]
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push Docker images
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          # Build shopping agent
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:shopping-$IMAGE_TAG \
            ./concierge_agent/mcp_shopping_tools
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:shopping-$IMAGE_TAG
          
          # Build cart manager
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:cart-$IMAGE_TAG \
            ./concierge_agent/mcp_cart_tools
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:cart-$IMAGE_TAG
          
          # Build supervisor agent
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:supervisor-$IMAGE_TAG \
            ./concierge_agent/supervisor_agent
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:supervisor-$IMAGE_TAG
  
  # Stage 4: Deploy to Dev
  deploy-dev:
    runs-on: ubuntu-latest
    needs: build-images
    if: github.ref == 'refs/heads/develop'
    environment: development
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy infrastructure
        run: |
          cd infrastructure/mcp-servers
          npm install
          cdk deploy --all --require-approval never \
            --context environment=dev \
            --context imageTag=${{ github.sha }}
      
      - name: Run smoke tests
        run: |
          ./scripts/smoke-tests.sh dev
      
      - name: Validate deployment
        run: |
          ./scripts/validate-deployment.sh dev
  
  # Stage 5: Integration Tests
  integration-tests:
    runs-on: ubuntu-latest
    needs: deploy-dev
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Run integration tests
        env:
          TEST_ENV: dev
        run: |
          pytest tests/integration -v --maxfail=1
  
  # Stage 6: Deploy to Staging
  deploy-staging:
    runs-on: ubuntu-latest
    needs: integration-tests
    if: github.ref == 'refs/heads/main'
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy infrastructure
        run: |
          cd infrastructure/mcp-servers
          npm install
          cdk deploy --all --require-approval never \
            --context environment=staging \
            --context imageTag=${{ github.sha }}
      
      - name: Run E2E tests
        run: |
          pytest tests/e2e -v --maxfail=1
      
      - name: Run load tests
        run: |
          ./scripts/load-test.sh staging
  
  # Stage 7: Deploy to Production
  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy infrastructure (Blue/Green)
        run: |
          cd infrastructure/mcp-servers
          npm install
          cdk deploy --all --require-approval never \
            --context environment=production \
            --context imageTag=${{ github.sha }} \
            --context deploymentStrategy=blue-green
      
      - name: Gradual traffic shift
        run: |
          ./scripts/gradual-traffic-shift.sh production
      
      - name: Monitor deployment
        run: |
          ./scripts/monitor-deployment.sh production
      
      - name: Post-deployment validation
        run: |
          ./scripts/validate-deployment.sh production
      
      - name: Notify team
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Production deployment completed'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

**Quality Gates:**

```python
# scripts/quality-gates.py
import sys
import json

def check_coverage(coverage_file):
    """Enforce 80% code coverage"""
    with open(coverage_file) as f:
        coverage = json.load(f)
    
    line_rate = coverage['totals']['line_rate']
    
    if line_rate < 0.80:
        print(f"❌ Coverage {line_rate:.1%} is below 80%")
        sys.exit(1)
    
    print(f"✅ Coverage {line_rate:.1%} meets requirement")

def check_vulnerabilities(scan_file):
    """Enforce zero critical vulnerabilities"""
    with open(scan_file) as f:
        scan = json.load(f)
    
    critical = scan['summary']['critical']
    
    if critical > 0:
        print(f"❌ Found {critical} critical vulnerabilities")
        sys.exit(1)
    
    print(f"✅ No critical vulnerabilities found")

def check_performance(metrics_file):
    """Enforce performance SLA"""
    with open(metrics_file) as f:
        metrics = json.load(f)
    
    p95_latency = metrics['latency_p95']
    error_rate = metrics['error_rate']
    
    if p95_latency > 2.0:
        print(f"❌ P95 latency {p95_latency}s exceeds 2s SLA")
        sys.exit(1)
    
    if error_rate > 0.005:
        print(f"❌ Error rate {error_rate:.2%} exceeds 0.5% SLA")
        sys.exit(1)
    
    print(f"✅ Performance meets SLA")

if __name__ == '__main__':
    check_coverage('coverage.json')
    check_vulnerabilities('scan.json')
    check_performance('metrics.json')
```

**Deployment Metrics:**

```
Pipeline Success Rate: 98.5%
Average Pipeline Time: 52 minutes
Failed Deployments: 1.5%
Rollback Time: <2 minutes
Mean Time to Production: 1 hour (after approval)
```

**Why This Approach:**

1. **Automated Quality:** Quality gates prevent bad code from reaching production
2. **Fast Feedback:** Unit tests run in <5 minutes
3. **Confidence:** Multiple test layers catch different issues
4. **Safety:** Manual approval for production
5. **Rollback:** Automatic rollback on failure

**Results:**
- 98.5% deployment success rate
- Zero production incidents from untested code
- 52-minute average pipeline time
- Weekly production deployments"

---

### Q7: "How do you manage secrets and sensitive configuration?"

**What the interviewer is testing:**
- Security best practices
- Secrets management
- Configuration management
- Compliance awareness

**Strong Answer:**

"I use AWS Secrets Manager and Parameter Store with encryption and rotation:

**1. Secrets Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    Secrets Management                        │
├─────────────────────────────────────────────────────────────┤
│ AWS Secrets Manager (Sensitive Secrets)                     │
│   ├── Visa API credentials                                  │
│   ├── SERP API key                                          │
│   ├── Database passwords                                    │
│   ├── OAuth client secrets                                  │
│   └── Encryption: KMS (AES-256)                            │
│   └── Rotation: Automatic (90 days)                        │
│                                                              │
│ AWS Systems Manager Parameter Store (Configuration)         │
│   ├── Gateway URLs                                          │
│   ├── Feature flags                                         │
│   ├── Environment config                                    │
│   └── Encryption: KMS (optional)                           │
│                                                              │
│ Environment Variables (Non-Sensitive)                       │
│   ├── AWS_REGION                                            │
│   ├── DEPLOYMENT_ID                                         │
│   ├── LOG_LEVEL                                             │
│   └── No encryption needed                                  │
└─────────────────────────────────────────────────────────────┘
```

**2. Secrets Manager Implementation**

```python
# concierge_agent/mcp_cart_tools/secrets.py
import boto3
import json
from functools import lru_cache

class SecretsManager:
    def __init__(self):
        self.client = boto3.client('secretsmanager')
        self.cache = {}
    
    @lru_cache(maxsize=128)
    def get_secret(self, secret_name: str) -> dict:
        """
        Get secret from AWS Secrets Manager with caching
        
        Args:
            secret_name: Name of the secret
        
        Returns:
            Dictionary with secret values
        """
        try:
            response = self.client.get_secret_value(
                SecretId=secret_name
            )
            
            # Parse JSON secret
            if 'SecretString' in response:
                return json.loads(response['SecretString'])
            else:
                # Binary secret
                return response['SecretBinary']
        
        except Exception as e:
            logger.error(f"Failed to get secret {secret_name}: {e}")
            raise
    
    def get_visa_credentials(self) -> dict:
        """Get Visa API credentials"""
        return self.get_secret('visa-api-credentials')
    
    def get_serp_api_key(self) -> str:
        """Get SERP API key"""
        secret = self.get_secret('serp-api-credentials')
        return secret['api_key']
    
    def get_database_password(self) -> str:
        """Get database password"""
        secret = self.get_secret('database-credentials')
        return secret['password']

# Singleton instance
secrets_manager = SecretsManager()

# Usage in application
visa_creds = secrets_manager.get_visa_credentials()
api_key = visa_creds['api_key']
```

**3. Secret Creation (CDK)**

```typescript
// infrastructure/agent-stack/lib/agent-stack.ts
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as kms from 'aws-cdk-lib/aws-kms';

// Create KMS key for encryption
const secretsKey = new kms.Key(this, 'SecretsKey', {
  description: 'KMS key for secrets encryption',
  enableKeyRotation: true,  // Automatic key rotation
  removalPolicy: cdk.RemovalPolicy.RETAIN  // Don't delete on stack deletion
});

// Create Visa API secret
const visaSecret = new secretsmanager.Secret(this, 'VisaSecret', {
  secretName: 'visa-api-credentials',
  description: 'Visa API credentials for payment processing',
  encryptionKey: secretsKey,
  generateSecretString: {
    secretStringTemplate: JSON.stringify({
      environment: 'production'
    }),
    generateStringKey: 'api_key',
    excludeCharacters: '"@/\\'
  }
});

// Automatic rotation (90 days)
visaSecret.addRotationSchedule('RotationSchedule', {
  automaticallyAfter: cdk.Duration.days(90),
  rotationLambda: rotationFunction
});

// Grant read access to ECS task role
visaSecret.grantRead(taskRole);

// Create SERP API secret
const serpSecret = new secretsmanager.Secret(this, 'SerpSecret', {
  secretName: 'serp-api-credentials',
  description: 'SERP API key for product search',
  encryptionKey: secretsKey
});

serpSecret.grantRead(taskRole);
```

**4. Secret Rotation Lambda**

```python
# infrastructure/agent-stack/lambdas/rotate-visa-secret/index.py
import boto3
import json

secrets_client = boto3.client('secretsmanager')
visa_client = VisaClient()

def lambda_handler(event, context):
    """
    Rotate Visa API credentials
    
    Steps:
    1. Create new API key in Visa portal
    2. Test new key
    3. Update secret
    4. Deprecate old key (after 7 days)
    """
    token = event['Token']
    step = event['Step']
    
    if step == 'createSecret':
        # Generate new API key
        new_key = visa_client.create_api_key()
        
        # Store new version
        secrets_client.put_secret_value(
            SecretId=event['SecretId'],
            ClientRequestToken=token,
            SecretString=json.dumps({
                'api_key': new_key,
                'created_at': datetime.utcnow().isoformat()
            }),
            VersionStages=['AWSPENDING']
        )
    
    elif step == 'setSecret':
        # Test new key
        current = secrets_client.get_secret_value(
            SecretId=event['SecretId'],
            VersionStage='AWSPENDING'
        )
        
        new_key = json.loads(current['SecretString'])['api_key']
        
        # Validate new key works
        if not visa_client.test_api_key(new_key):
            raise Exception("New API key validation failed")
    
    elif step == 'testSecret':
        # Additional validation
        pass
    
    elif step == 'finishSecret':
        # Move AWSCURRENT to new version
        secrets_client.update_secret_version_stage(
            SecretId=event['SecretId'],
            VersionStage='AWSCURRENT',
            MoveToVersionId=token,
            RemoveFromVersionId=event['CurrentVersion']
        )
        
        # Schedule old key deprecation
        old_key = event['OldSecretValue']['api_key']
        visa_client.schedule_key_deprecation(old_key, days=7)
    
    return {'statusCode': 200}
```

**5. Parameter Store for Configuration**

```python
# concierge_agent/config.py
import boto3
from functools import lru_cache

class ConfigManager:
    def __init__(self):
        self.ssm = boto3.client('ssm')
        self.deployment_id = os.getenv('DEPLOYMENT_ID', 'shopping')
    
    @lru_cache(maxsize=128)
    def get_parameter(self, param_name: str) -> str:
        """Get parameter from SSM Parameter Store"""
        full_name = f"/concierge-agent/{self.deployment_id}/{param_name}"
        
        response = self.ssm.get_parameter(
            Name=full_name,
            WithDecryption=True
        )
        
        return response['Parameter']['Value']
    
    def get_gateway_url(self) -> str:
        """Get AgentCore Gateway URL"""
        return self.get_parameter('gateway-url')
    
    def get_feature_flag(self, flag_name: str) -> bool:
        """Get feature flag value"""
        value = self.get_parameter(f'feature-flags/{flag_name}')
        return value.lower() == 'true'

# Usage
config = ConfigManager()
gateway_url = config.get_gateway_url()
use_visa_mock = config.get_feature_flag('use-visa-mock')
```

**6. Environment-Specific Secrets**

```bash
# scripts/set-secrets.sh
#!/bin/bash
set -e

ENVIRONMENT=$1  # dev, qa, staging, prod

if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: ./set-secrets.sh <environment>"
  exit 1
fi

# Set Visa API credentials
aws secretsmanager create-secret \
  --name "${ENVIRONMENT}-visa-api-credentials" \
  --description "Visa API credentials for ${ENVIRONMENT}" \
  --secret-string "{
    \"api_key\": \"${VISA_API_KEY}\",
    \"client_app_id\": \"${VISA_CLIENT_APP_ID}\",
    \"environment\": \"${ENVIRONMENT}\"
  }" \
  --kms-key-id alias/secrets-key

# Set SERP API key
aws secretsmanager create-secret \
  --name "${ENVIRONMENT}-serp-api-credentials" \
  --description "SERP API key for ${ENVIRONMENT}" \
  --secret-string "{
    \"api_key\": \"${SERP_API_KEY}\"
  }" \
  --kms-key-id alias/secrets-key

echo "✅ Secrets created for ${ENVIRONMENT}"
```

**7. Secret Access Audit**

```python
# scripts/audit-secret-access.py
import boto3
from datetime import datetime, timedelta

cloudtrail = boto3.client('cloudtrail')

def audit_secret_access(secret_name: str, days: int = 7):
    """
    Audit who accessed a secret in the last N days
    """
    start_time = datetime.utcnow() - timedelta(days=days)
    
    response = cloudtrail.lookup_events(
        LookupAttributes=[
            {
                'AttributeKey': 'ResourceName',
                'AttributeValue': secret_name
            }
        ],
        StartTime=start_time,
        MaxResults=1000
    )
    
    print(f"Secret Access Audit: {secret_name}")
    print(f"Period: Last {days} days")
    print("-" * 80)
    
    for event in response['Events']:
        username = event['Username']
        event_time = event['EventTime']
        event_name = event['EventName']
        source_ip = event.get('SourceIPAddress', 'N/A')
        
        print(f"{event_time} | {username} | {event_name} | {source_ip}")
    
    print(f"\nTotal accesses: {len(response['Events'])}")

# Run audit
audit_secret_access('visa-api-credentials', days=30)
```

**8. Secret Scanning in CI/CD**

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scanning

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Full history for scanning
      
      - name: Run TruffleHog
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
      
      - name: Run git-secrets
        run: |
          git clone https://github.com/awslabs/git-secrets.git
          cd git-secrets
          sudo make install
          cd ..
          git secrets --register-aws
          git secrets --scan
      
      - name: Fail on secrets found
        if: failure()
        run: |
          echo "❌ Secrets detected in code!"
          echo "Remove secrets and use AWS Secrets Manager instead"
          exit 1
```

**Best Practices:**

1. **Never commit secrets to Git**
2. **Use Secrets Manager for sensitive data**
3. **Use Parameter Store for configuration**
4. **Encrypt all secrets with KMS**
5. **Rotate secrets automatically (90 days)**
6. **Audit secret access (CloudTrail)**
7. **Scan for secrets in CI/CD**
8. **Use IAM roles (not access keys)**

**Results:**
- Zero secrets in Git history
- Automatic secret rotation (90 days)
- Encrypted at rest (KMS)
- Full audit trail (CloudTrail)
- PCI DSS compliant"

