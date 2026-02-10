# Testing & Deployment - Quick Reference
## 1-Page Cheat Sheet for Technical Interviews

---

## 🧪 Testing Strategy

### Testing Pyramid
```
E2E Tests (5%) - Critical flows
Integration Tests (25%) - Service-to-service, DB, APIs
Unit Tests (60%) - Business logic, utilities
Contract Tests (10%) - API schemas, MCP protocol
```

### Key Metrics
- **Coverage:** 82% (target: 80%)
- **Test Execution:** <5 minutes (unit + integration)
- **CI/CD Success:** 98.5%
- **Production Bugs:** 0 from untested code

### Tools & Frameworks
- **Unit:** pytest, pytest-mock, pytest-cov
- **Integration:** moto (AWS mocking), testcontainers
- **Contract:** JSON Schema, VCR.py (HTTP recording)
- **E2E:** Selenium/Playwright, real AWS services

---

## 🚀 Serverless Architecture

### Why Serverless?
- **Cost:** Pay-per-use ($0.16/user)
- **Scalability:** 0 → 1000 req/s in <60 seconds
- **Operations:** Zero server management
- **Availability:** 99.95% (exceeds 99.9% SLA)

### Components
- **Compute:** ECS Fargate (ARM64), Lambda
- **Database:** DynamoDB (on-demand), DAX cache
- **API:** API Gateway, AppSync (GraphQL)
- **Auth:** Cognito (JWT + OAuth 2.0)
- **AI:** Bedrock AgentCore

### Trade-offs
✅ Operational simplicity  
✅ Automatic scaling  
✅ High availability  
❌ Higher cost at scale  
❌ Cold starts (mitigated)  
❌ Vendor lock-in (acceptable)

---

## 🏗️ Infrastructure as Code

### AWS CDK (TypeScript)
```
infrastructure/
├── mcp-servers/      # MCP runtime stacks
├── agent-stack/      # Supervisor agent
└── frontend-stack/   # Amplify hosting
```

### Deployment Order
1. Amplify Backend (Cognito, DynamoDB) - 3 min
2. MCP Servers (Shopping, Cart, Payment) - 60 sec
3. Agent Stack (Supervisor, Gateway) - 4 min
4. Frontend Stack (Amplify Hosting) - 3 min

**Total:** 11 minutes

### Key Features
- **Reusable constructs** (BaseMcpStack)
- **Cross-stack references** (CloudFormation exports)
- **Automatic rollback** (circuit breaker)
- **Multi-environment** (dev, qa, staging, prod)

---

## 🔄 CI/CD Pipeline

### Pipeline Stages (45-60 minutes)
```
1. Code Commit (GitHub) - <1 sec
2. Build & Unit Tests - 3-5 min
3. Security Scanning - 2-3 min
4. Build Docker Images - 5-7 min
5. Deploy to Dev - 3-4 min
6. Integration Tests - 5-7 min
7. Deploy to Staging - 10-15 min
8. Manual Approval - Variable
9. Deploy to Production - 15-20 min
10. Post-Deployment Validation - 5-10 min
```

### Quality Gates
- **Coverage:** ≥80%
- **Vulnerabilities:** 0 critical
- **Latency:** <2s (p95)
- **Error Rate:** <0.5%

### Deployment Strategy
- **Blue/Green:** Zero downtime
- **Gradual Traffic Shift:** 10% → 50% → 100%
- **Automatic Rollback:** Error rate >1%
- **Rollback Time:** <2 minutes

---

## 🔐 Secrets Management

### Architecture
```
AWS Secrets Manager (Sensitive)
├── Visa API credentials
├── SERP API key
├── Database passwords
└── Encryption: KMS (AES-256)
└── Rotation: Automatic (90 days)

AWS Parameter Store (Configuration)
├── Gateway URLs
├── Feature flags
└── Environment config
```

### Best Practices
✅ Never commit secrets to Git  
✅ Encrypt with KMS  
✅ Rotate automatically (90 days)  
✅ Audit access (CloudTrail)  
✅ Scan in CI/CD (TruffleHog)  
✅ Use IAM roles (not access keys)

---

## 📊 Test Data Management

### By Environment
- **Production:** Real data, PII encrypted
- **Staging:** Anonymized production data
- **QA:** Synthetic test data
- **Dev:** Minimal synthetic data

### Synthetic Data Generation
```python
from faker import Faker

class TestDataFactory:
    @staticmethod
    def create_dealer(tier="gold"):
        return {
            "user_id": f"test_dealer_{fake.uuid4()}",
            "email": fake.email(),
            "dealer_tier": tier
        }
```

### Compliance
- **GDPR:** No PII in test environments
- **PCI DSS:** Test card numbers only
- **Anonymization:** Automated scripts

---

## 🔍 External API Testing

### Strategy
1. **Unit Tests:** Mock external APIs
2. **Contract Tests:** Validate API schemas
3. **Integration Tests:** Use sandbox environments
4. **Monitoring:** Continuous health checks

### Abstraction Layer
```python
class SerpClient(ABC):
    @abstractmethod
    def search(self, query: str) -> dict:
        pass

class RealSerpClient(SerpClient):
    # Production implementation
    pass

class MockSerpClient(SerpClient):
    # Test implementation
    pass
```

---

## 🎯 Key Interview Points

### Testing
- "I implemented a 4-layer testing strategy with 82% coverage"
- "Unit tests run in <5 minutes for fast feedback"
- "Integration tests use real AWS services for confidence"
- "E2E tests validate critical business flows"

### Deployment
- "I chose serverless for operational simplicity and auto-scaling"
- "AWS CDK provides type safety and reusable constructs"
- "11-minute full deployment with automatic rollback"
- "Blue/Green deployment ensures zero downtime"

### CI/CD
- "98.5% pipeline success rate with automated quality gates"
- "45-60 minute commit-to-production pipeline"
- "Gradual traffic shift with automatic rollback"
- "Zero production incidents from untested code"

### Secrets
- "AWS Secrets Manager with KMS encryption and 90-day rotation"
- "Zero secrets in Git history (TruffleHog scanning)"
- "Full audit trail via CloudTrail"
- "PCI DSS compliant secrets management"

---

## ❓ Questions to Ask Interviewers

1. "What's your current test coverage and how do you enforce it?"
2. "How do you handle secrets management and rotation?"
3. "What's your deployment frequency and rollback strategy?"
4. "How do you balance test coverage with development velocity?"
5. "What observability tools do you use for serverless?"

---

**Remember: Quantify everything, show ownership, explain trade-offs! 🚀**

