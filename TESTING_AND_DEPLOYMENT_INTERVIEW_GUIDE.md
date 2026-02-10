# Testing & Deployment Interview Guide
## Comprehensive Q&A for Backend Testing Strategy and Serverless Deployment

**Prepared for:** Senior Backend Engineer / Solution Architect / DevOps Lead Interviews  
**Focus Areas:** Testing Methodologies, CI/CD, Serverless Deployment, Production Operations  
**Project Context:** TradeIQ - Multi-Agent AI Commerce Platform on AWS

---

## 📋 Table of Contents

1. [Code Testing Strategy](#1-code-testing-strategy)
2. [Serverless Backend Deployment](#2-serverless-backend-deployment)
3. [CI/CD Pipeline Architecture](#3-cicd-pipeline-architecture)
4. [Production Operations & Observability](#4-production-operations--observability)
5. [Advanced Scenarios](#5-advanced-scenarios)

---

## 1. Code Testing Strategy

### Q1: "Walk me through your testing strategy for this serverless backend system."

**What the interviewer is testing:**
- Understanding of testing pyramid
- Practical testing experience
- Balance between coverage and velocity
- Risk-based testing approach

**Strong Answer:**

"I implemented a comprehensive four-layer testing strategy for TradeIQ:

**Testing Pyramid:**
```
                    E2E Tests (5%)
                 ┌─────────────────┐
                 │ Critical Flows  │
                 └─────────────────┘
              Integration Tests (25%)
           ┌──────────────────────────┐
           │ Service-to-Service       │
           │ Database, External APIs  │
           └──────────────────────────┘
          Unit Tests (60%)
     ┌────────────────────────────────────┐
     │ Business Logic, Utilities          │
     │ MCP Tools, Data Transformations    │
     └────────────────────────────────────┘
    Contract Tests (10%)
┌──────────────────────────────────────────────┐
│ API Schemas, GraphQL Types                   │
│ MCP Protocol Validation                      │
└──────────────────────────────────────────────┘
```

**1. Unit Tests (60% of tests)**

**What I tested:**
- MCP tool functions (search_parts, add_to_cart, onboard_card)
- Business logic (dealer pricing, compatibility verification)
- Data transformations (SERP API response parsing)
- Utility functions (token generation, encryption)

**Tools & Frameworks:**
- pytest (Python testing framework)
- pytest-mock (mocking)
- pytest-cov (coverage reporting)
- freezegun (time mocking)

**Example:**
```python
# tests/unit/test_cart_manager.py
import pytest
from mcp_cart_tools.server import add_to_cart
from unittest.mock import Mock, patch

@pytest.fixture
def mock_dynamodb():
    with patch('boto3.resource') as mock:
        yield mock

def test_add_to_cart_success(mock_dynamodb):
    # Arrange
    user_id = "dealer_12345"
    items = [{
        "asin": "B09XM5ASIN",
        "title": "Honda OEM Brake Pads",
        "price": 89.99,
        "quantity": 2
    }]
    
    # Act
    result = add_to_cart(user_id, items)
    
    # Assert
    assert result['success'] == True
    assert result['items_added'] == 1
    assert mock_dynamodb.called

def test_add_to_cart_dealer_pricing():
    # Test dealer tier pricing calculation
    user_id = "platinum_dealer_123"
    items = [{"price": 100.00, "quantity": 1}]
    
    result = add_to_cart(user_id, items)
    
    # Platinum tier gets 25% discount
    assert result['items'][0]['dealer_price'] == 75.00

def test_add_to_cart_validation_error():
    # Test input validation
    with pytest.raises(ValueError, match="Invalid ASIN"):
        add_to_cart("dealer_123", [{"asin": ""}])
```

**Mocking Strategy:**
- Mock external services (DynamoDB, SERP API, Visa Gateway)
- Use dependency injection for testability
- Create fixtures for common test data
- Mock time-dependent functions (freezegun)

**Coverage Target:** 80% line coverage, 90% for critical paths


**2. Integration Tests (25% of tests)**

**What I tested:**
- Service-to-service communication (Supervisor → Shopping Agent)
- Database operations (DynamoDB read/write)
- External API integration (SERP API, Visa Gateway)
- MCP protocol communication
- Authentication flow (Cognito JWT validation)

**Tools & Frameworks:**
- pytest with real AWS services (LocalStack for local testing)
- moto (AWS service mocking)
- requests-mock (HTTP mocking)
- testcontainers (DynamoDB local)

**Example:**
```python
# tests/integration/test_shopping_agent_integration.py
import pytest
import boto3
from moto import mock_dynamodb
from mcp_shopping_tools.server import search_parts

@mock_dynamodb
def test_search_parts_with_dynamodb():
    # Setup: Create DynamoDB table
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.create_table(
        TableName='VehicleCompatibility',
        KeySchema=[
            {'AttributeName': 'vehicle_id', 'KeyType': 'HASH'},
            {'AttributeName': 'part_type', 'KeyType': 'RANGE'}
        ],
        AttributeDefinitions=[
            {'AttributeName': 'vehicle_id', 'AttributeType': 'S'},
            {'AttributeName': 'part_type', 'AttributeType': 'S'}
        ],
        BillingMode='PAY_PER_REQUEST'
    )
    
    # Insert test data
    table.put_item(Item={
        'vehicle_id': '2023_Honda_Civic',
        'part_type': 'brake_pads',
        'compatible_parts': ['B09XM5ASIN', 'B09ASIN456']
    })
    
    # Act: Search for parts
    result = search_parts(
        vehicle="2023 Honda Civic",
        part_type="brake pads"
    )
    
    # Assert: Verify compatibility check
    assert result['success'] == True
    assert len(result['parts']) > 0
    assert all(p['compatibility'] == 'verified' for p in result['parts'])

@pytest.mark.integration
def test_serp_api_integration():
    # Test real SERP API call (requires API key)
    result = search_parts(
        vehicle="2023 Honda Civic",
        part_type="brake pads",
        use_real_api=True
    )
    
    assert result['success'] == True
    assert 'parts' in result
    assert len(result['parts']) > 0
```

**Environment Isolation:**
- Use separate AWS accounts for testing (dev, qa, staging)
- Environment-specific DynamoDB tables (prefix: `dev-`, `qa-`, `prod-`)
- Separate Cognito user pools per environment
- API keys stored in AWS Secrets Manager per environment

**3. API Testing (Contract Testing)**

**What I tested:**
- GraphQL schema validation
- MCP protocol compliance
- Request/response contracts
- Error response formats
- API versioning

**Tools & Frameworks:**
- GraphQL schema validation (graphql-core)
- JSON Schema validation (jsonschema)
- Pact (consumer-driven contract testing)
- Postman/Newman (API testing)

**Example:**
```python
# tests/contract/test_mcp_protocol.py
import pytest
from jsonschema import validate, ValidationError
from mcp_cart_tools.server import mcp_server

# MCP tool schema
TOOL_SCHEMA = {
    "type": "object",
    "required": ["name", "description", "inputSchema"],
    "properties": {
        "name": {"type": "string"},
        "description": {"type": "string"},
        "inputSchema": {
            "type": "object",
            "required": ["type", "properties"],
            "properties": {
                "type": {"const": "object"},
                "properties": {"type": "object"}
            }
        }
    }
}

def test_mcp_tool_schema_compliance():
    # Get all registered tools
    tools = mcp_server.list_tools()
    
    for tool in tools:
        # Validate each tool against MCP schema
        try:
            validate(instance=tool, schema=TOOL_SCHEMA)
        except ValidationError as e:
            pytest.fail(f"Tool {tool['name']} violates MCP schema: {e}")

def test_add_to_cart_contract():
    # Test request/response contract
    request = {
        "user_id": "dealer_12345",
        "items": [{
            "asin": "B09XM5ASIN",
            "title": "Honda OEM Brake Pads",
            "price": 89.99,
            "quantity": 2
        }]
    }
    
    response = add_to_cart(**request)
    
    # Validate response schema
    response_schema = {
        "type": "object",
        "required": ["success", "items_added"],
        "properties": {
            "success": {"type": "boolean"},
            "items_added": {"type": "integer"},
            "error": {"type": "string"}
        }
    }
    
    validate(instance=response, schema=response_schema)

def test_error_response_format():
    # Test error responses follow standard format
    with pytest.raises(Exception) as exc_info:
        add_to_cart(user_id="", items=[])
    
    error = exc_info.value
    assert hasattr(error, 'code')
    assert hasattr(error, 'message')
    assert hasattr(error, 'details')
```

**4. End-to-End Tests (5% of tests)**

**What I tested:**
- Critical business flows (search → add to cart → checkout)
- Multi-agent orchestration
- Payment processing flow
- User authentication flow

**Tools & Frameworks:**
- pytest with real AWS services
- Selenium/Playwright (UI testing)
- AWS SDK (boto3)

**Example:**
```python
# tests/e2e/test_checkout_flow.py
import pytest
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

@pytest.mark.e2e
@pytest.mark.slow
def test_complete_checkout_flow():
    # Setup: Login as test dealer
    driver = webdriver.Chrome()
    driver.get("https://tradeiq-shopping-agent.web.app")
    
    # Step 1: Login
    login(driver, "test_dealer@example.com", "TestPassword123!")
    
    # Step 2: Search for parts
    search_box = driver.find_element(By.ID, "chat-input")
    search_box.send_keys("I need brake pads for 2023 Honda Civic")
    search_box.submit()
    
    # Wait for AI response
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.CLASS_NAME, "part-result"))
    )
    
    # Step 3: Add to cart
    add_button = driver.find_element(By.CLASS_NAME, "add-to-cart-btn")
    add_button.click()
    
    # Step 4: View cart
    cart_icon = driver.find_element(By.ID, "cart-icon")
    cart_icon.click()
    
    # Verify cart contents
    cart_items = driver.find_elements(By.CLASS_NAME, "cart-item")
    assert len(cart_items) == 1
    
    # Step 5: Checkout
    checkout_btn = driver.find_element(By.ID, "checkout-btn")
    checkout_btn.click()
    
    # Step 6: Confirm purchase
    confirm_btn = WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.ID, "confirm-purchase-btn"))
    )
    confirm_btn.click()
    
    # Step 7: Verify success
    success_msg = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.CLASS_NAME, "success-message"))
    )
    assert "Purchase completed" in success_msg.text
    
    driver.quit()
```

**Why This Strategy:**

1. **Risk-Based:** Focus on critical paths (payment, compatibility)
2. **Fast Feedback:** Unit tests run in <30 seconds
3. **Confidence:** Integration tests catch service issues
4. **Production Parity:** E2E tests use real AWS services
5. **Cost-Effective:** Minimize expensive E2E tests

**CI/CD Integration:**
- Unit tests: Run on every commit (required to pass)
- Integration tests: Run on PR merge (required to pass)
- Contract tests: Run on API changes (required to pass)
- E2E tests: Run nightly + before production deploy (can be skipped in emergency)

**Results:**
- 82% code coverage (exceeds 80% target)
- <5 minute test suite execution (unit + integration)
- Zero production bugs from untested code paths
- 98.5% CI/CD success rate"

---

### Q2: "How do you handle test data management across environments?"

**What the interviewer is testing:**
- Data management strategy
- Environment isolation
- Test data generation
- Data privacy compliance

**Strong Answer:**

"I implemented a comprehensive test data management strategy with environment isolation and synthetic data generation:

**1. Test Data Strategy by Environment**

```
Production:
├── Real customer data
├── PII encrypted (KMS)
├── No test data allowed
└── Read-only access for debugging

Staging:
├── Anonymized production data (monthly refresh)
├── PII masked/hashed
├── Realistic data volumes
└── Used for load testing

QA:
├── Synthetic test data
├── Predefined test scenarios
├── Known edge cases
└── Reset weekly

Development:
├── Minimal synthetic data
├── Developer-generated
├── Fast reset (on-demand)
└── Isolated per developer
```

**2. Synthetic Data Generation**

```python
# tests/fixtures/test_data_factory.py
from faker import Faker
import random

fake = Faker()

class TestDataFactory:
    @staticmethod
    def create_dealer(tier="gold"):
        """Generate synthetic dealer data"""
        return {
            "user_id": f"test_dealer_{fake.uuid4()}",
            "email": fake.email(),
            "dealer_tier": tier,
            "created_at": fake.unix_time(),
            "preferences": {
                "language": "en",
                "currency": "USD"
            }
        }
    
    @staticmethod
    def create_cart_item(vehicle="2023 Honda Civic"):
        """Generate synthetic cart item"""
        return {
            "asin": f"B09{fake.bothify('??????').upper()}",
            "title": f"{fake.word().title()} Auto Part",
            "price": round(random.uniform(20, 500), 2),
            "quantity": random.randint(1, 5),
            "vehicle": vehicle,
            "compatibility": "verified"
        }
    
    @staticmethod
    def create_order(user_id, items_count=3):
        """Generate synthetic order"""
        items = [TestDataFactory.create_cart_item() 
                 for _ in range(items_count)]
        
        return {
            "order_id": f"ORD-{fake.date()}-{fake.bothify('???###')}",
            "user_id": user_id,
            "items": items,
            "total_amount": sum(i['price'] * i['quantity'] for i in items),
            "status": "completed",
            "created_at": fake.unix_time()
        }

# Usage in tests
@pytest.fixture
def test_dealer():
    return TestDataFactory.create_dealer(tier="platinum")

@pytest.fixture
def test_cart_items():
    return [TestDataFactory.create_cart_item() for _ in range(3)]
```

**3. Environment-Specific Configuration**

```python
# config/test_config.py
import os

class TestConfig:
    ENVIRONMENT = os.getenv('TEST_ENV', 'dev')
    
    # Environment-specific settings
    CONFIGS = {
        'dev': {
            'dynamodb_table_prefix': 'dev-',
            'use_real_apis': False,
            'data_volume': 'minimal',
            'reset_on_start': True
        },
        'qa': {
            'dynamodb_table_prefix': 'qa-',
            'use_real_apis': True,
            'data_volume': 'medium',
            'reset_on_start': False
        },
        'staging': {
            'dynamodb_table_prefix': 'staging-',
            'use_real_apis': True,
            'data_volume': 'production-like',
            'reset_on_start': False
        }
    }
    
    @classmethod
    def get_config(cls):
        return cls.CONFIGS[cls.ENVIRONMENT]
    
    @classmethod
    def get_table_name(cls, base_name):
        prefix = cls.get_config()['dynamodb_table_prefix']
        return f"{prefix}{base_name}"
```

**4. Test Data Seeding**

```python
# tests/fixtures/seed_data.py
import boto3
from test_data_factory import TestDataFactory

def seed_test_data(environment='dev'):
    """Seed test data for specific environment"""
    dynamodb = boto3.resource('dynamodb')
    config = TestConfig.get_config()
    
    # Seed dealers
    dealer_table = dynamodb.Table(
        TestConfig.get_table_name('UserProfile')
    )
    
    dealers = [
        TestDataFactory.create_dealer('platinum'),
        TestDataFactory.create_dealer('gold'),
        TestDataFactory.create_dealer('silver')
    ]
    
    for dealer in dealers:
        dealer_table.put_item(Item=dealer)
    
    # Seed vehicle compatibility data
    compat_table = dynamodb.Table(
        TestConfig.get_table_name('VehicleCompatibility')
    )
    
    vehicles = [
        '2023_Honda_Civic',
        '2022_Toyota_Camry',
        '2024_Ford_F150'
    ]
    
    for vehicle in vehicles:
        compat_table.put_item(Item={
            'vehicle_id': vehicle,
            'part_type': 'brake_pads',
            'compatible_parts': [
                TestDataFactory.create_cart_item()['asin']
                for _ in range(5)
            ]
        })
    
    print(f"✓ Seeded test data for {environment}")

# Run before test suite
if __name__ == '__main__':
    seed_test_data(os.getenv('TEST_ENV', 'dev'))
```

**5. Data Anonymization (Staging)**

```python
# scripts/anonymize_production_data.py
import boto3
import hashlib
from faker import Faker

fake = Faker()

def anonymize_production_data():
    """
    Copy production data to staging with PII anonymization
    """
    # Source: Production DynamoDB
    prod_table = boto3.resource('dynamodb').Table('prod-UserProfile')
    
    # Destination: Staging DynamoDB
    staging_table = boto3.resource('dynamodb').Table('staging-UserProfile')
    
    # Scan production data
    response = prod_table.scan()
    
    for item in response['Items']:
        # Anonymize PII
        anonymized = {
            'user_id': item['user_id'],  # Keep ID for referential integrity
            'email': fake.email(),  # Replace with fake email
            'dealer_tier': item['dealer_tier'],  # Keep business data
            'payment_tokens': [],  # Remove payment data
            'preferences': item.get('preferences', {}),
            'created_at': item['created_at']
        }
        
        # Write to staging
        staging_table.put_item(Item=anonymized)
    
    print(f"✓ Anonymized {len(response['Items'])} records")

# Run monthly via Lambda
```

**6. Test Data Cleanup**

```python
# tests/conftest.py
import pytest
import boto3

@pytest.fixture(scope='session', autouse=True)
def cleanup_test_data():
    """Cleanup test data after test suite"""
    yield  # Run tests
    
    # Cleanup after all tests
    if TestConfig.ENVIRONMENT == 'dev':
        dynamodb = boto3.resource('dynamodb')
        
        tables = [
            'UserProfile',
            'ShoppingCart',
            'OrderHistory'
        ]
        
        for table_name in tables:
            table = dynamodb.Table(
                TestConfig.get_table_name(table_name)
            )
            
            # Delete all items with test prefix
            response = table.scan(
                FilterExpression='begins_with(user_id, :prefix)',
                ExpressionAttributeValues={':prefix': 'test_'}
            )
            
            for item in response['Items']:
                table.delete_item(Key={'user_id': item['user_id']})
        
        print("✓ Cleaned up test data")
```

**7. Data Privacy Compliance**

**GDPR Compliance:**
- No production PII in test environments
- Anonymization scripts for staging data
- Automated data deletion (TTL)
- Audit logs for data access

**PCI DSS Compliance:**
- No real payment cards in test environments
- Test card numbers (4111111111111111)
- Tokenized test data only
- Separate Visa sandbox environment

**Results:**
- Zero PII leaks to test environments
- Fast test data reset (<2 minutes)
- Realistic test scenarios
- GDPR/PCI DSS compliant"


---

### Q3: "How do you test external API integrations like SERP API and Visa Gateway?"

**What the interviewer is testing:**
- External dependency management
- Mocking strategies
- Contract testing
- Failure handling

**Strong Answer:**

"I use a multi-layered approach for testing external APIs: mocking for unit tests, contract testing for integration, and sandbox environments for E2E:

**1. Abstraction Layer for Testability**

```python
# mcp_shopping_tools/serp_client.py
from abc import ABC, abstractmethod

class SerpClient(ABC):
    """Abstract SERP API client for testability"""
    
    @abstractmethod
    def search(self, query: str, **kwargs) -> dict:
        pass

class RealSerpClient(SerpClient):
    """Production SERP API client"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://serpapi.com/search"
    
    def search(self, query: str, **kwargs) -> dict:
        response = requests.get(
            self.base_url,
            params={
                'q': query,
                'api_key': self.api_key,
                **kwargs
            },
            timeout=5.0
        )
        response.raise_for_status()
        return response.json()

class MockSerpClient(SerpClient):
    """Mock SERP API client for testing"""
    
    def search(self, query: str, **kwargs) -> dict:
        # Return predefined test data
        return {
            'organic_results': [
                {
                    'title': 'Honda OEM Brake Pads',
                    'link': 'https://example.com/brake-pads',
                    'price': '$89.99',
                    'rating': 4.8,
                    'reviews': 1245
                }
            ]
        }

# Dependency injection
def get_serp_client() -> SerpClient:
    if os.getenv('USE_MOCK_SERP', 'false') == 'true':
        return MockSerpClient()
    else:
        return RealSerpClient(api_key=os.getenv('SERP_API_KEY'))
```

**2. Unit Tests with Mocking**

```python
# tests/unit/test_shopping_agent.py
import pytest
from unittest.mock import Mock, patch
from mcp_shopping_tools.server import search_parts

@pytest.fixture
def mock_serp_client():
    client = Mock(spec=SerpClient)
    client.search.return_value = {
        'organic_results': [
            {
                'title': 'Honda OEM Brake Pads',
                'link': 'https://example.com/brake-pads',
                'price': '$89.99',
                'asin': 'B09XM5ASIN'
            }
        ]
    }
    return client

def test_search_parts_with_mock(mock_serp_client):
    with patch('mcp_shopping_tools.server.get_serp_client', 
               return_value=mock_serp_client):
        result = search_parts(
            vehicle="2023 Honda Civic",
            part_type="brake pads"
        )
        
        assert result['success'] == True
        assert len(result['parts']) == 1
        assert result['parts'][0]['title'] == 'Honda OEM Brake Pads'
        
        # Verify API was called correctly
        mock_serp_client.search.assert_called_once()
        call_args = mock_serp_client.search.call_args
        assert '2023 Honda Civic brake pads' in call_args[0][0]

def test_search_parts_api_timeout(mock_serp_client):
    # Test timeout handling
    mock_serp_client.search.side_effect = requests.Timeout()
    
    with patch('mcp_shopping_tools.server.get_serp_client',
               return_value=mock_serp_client):
        result = search_parts(
            vehicle="2023 Honda Civic",
            part_type="brake pads"
        )
        
        # Should return cached results or graceful error
        assert result['success'] == False
        assert 'timeout' in result['error'].lower()

def test_search_parts_api_error(mock_serp_client):
    # Test API error handling
    mock_serp_client.search.side_effect = requests.HTTPError("500 Server Error")
    
    with patch('mcp_shopping_tools.server.get_serp_client',
               return_value=mock_serp_client):
        result = search_parts(
            vehicle="2023 Honda Civic",
            part_type="brake pads"
        )
        
        assert result['success'] == False
        assert 'error' in result
```

**3. Contract Testing with Recorded Responses**

```python
# tests/contract/test_serp_api_contract.py
import pytest
import vcr
from mcp_shopping_tools.serp_client import RealSerpClient

# VCR.py records HTTP interactions for replay
my_vcr = vcr.VCR(
    cassette_library_dir='tests/fixtures/vcr_cassettes',
    record_mode='once',  # Record once, then replay
    match_on=['uri', 'method'],
)

@pytest.mark.contract
@my_vcr.use_cassette('serp_api_search.yaml')
def test_serp_api_contract():
    """
    Test SERP API contract with recorded response
    First run: Records real API response
    Subsequent runs: Replays recorded response
    """
    client = RealSerpClient(api_key='test_key')
    
    response = client.search(
        query='2023 Honda Civic brake pads',
        engine='google_shopping'
    )
    
    # Validate response structure
    assert 'organic_results' in response
    assert isinstance(response['organic_results'], list)
    
    if len(response['organic_results']) > 0:
        result = response['organic_results'][0]
        
        # Validate required fields
        assert 'title' in result
        assert 'link' in result
        assert 'price' in result or 'extracted_price' in result

@pytest.mark.contract
def test_serp_api_schema_validation():
    """Validate SERP API response against JSON schema"""
    from jsonschema import validate
    
    # Expected schema
    schema = {
        "type": "object",
        "required": ["organic_results"],
        "properties": {
            "organic_results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["title", "link"],
                    "properties": {
                        "title": {"type": "string"},
                        "link": {"type": "string", "format": "uri"},
                        "price": {"type": "string"},
                        "rating": {"type": "number"},
                        "reviews": {"type": "integer"}
                    }
                }
            }
        }
    }
    
    # Load recorded response
    with open('tests/fixtures/serp_response.json') as f:
        response = json.load(f)
    
    # Validate
    validate(instance=response, schema=schema)
```

**4. Integration Tests with Sandbox**

```python
# tests/integration/test_visa_integration.py
import pytest
from mcp_cart_tools.visa_client import VisaClient

@pytest.mark.integration
@pytest.mark.slow
def test_visa_tokenization_sandbox():
    """
    Test Visa tokenization with sandbox environment
    Uses test credentials and test card numbers
    """
    client = VisaClient(
        api_key=os.getenv('VISA_SANDBOX_API_KEY'),
        environment='sandbox'
    )
    
    # Test card number (Visa sandbox)
    test_card = {
        'card_number': '4111111111111111',
        'expiration': '12/25',
        'cvv': '123'
    }
    
    # Provision token
    result = client.provision_token(
        card_number=test_card['card_number'],
        expiration=test_card['expiration'],
        cvv=test_card['cvv']
    )
    
    # Validate response
    assert result['success'] == True
    assert 'vProvisionedTokenId' in result
    assert result['lastFourDigits'] == '1111'
    
    # Test token usage
    token_id = result['vProvisionedTokenId']
    payment_result = client.process_payment(
        token_id=token_id,
        amount=100.00
    )
    
    assert payment_result['success'] == True
    assert payment_result['status'] == 'approved'

@pytest.mark.integration
def test_visa_api_error_handling():
    """Test Visa API error scenarios"""
    client = VisaClient(
        api_key=os.getenv('VISA_SANDBOX_API_KEY'),
        environment='sandbox'
    )
    
    # Test invalid card number
    with pytest.raises(ValueError, match="Invalid card number"):
        client.provision_token(
            card_number='1234567890123456',  # Invalid
            expiration='12/25',
            cvv='123'
        )
    
    # Test expired card
    result = client.provision_token(
        card_number='4111111111111111',
        expiration='01/20',  # Expired
        cvv='123'
    )
    
    assert result['success'] == False
    assert 'expired' in result['error'].lower()
```

**5. Failure Scenario Testing**

```python
# tests/integration/test_api_failures.py
import pytest
from unittest.mock import patch
import requests

def test_serp_api_rate_limit():
    """Test SERP API rate limit handling"""
    with patch('requests.get') as mock_get:
        # Simulate rate limit error
        mock_response = Mock()
        mock_response.status_code = 429
        mock_response.json.return_value = {
            'error': 'Rate limit exceeded'
        }
        mock_get.return_value = mock_response
        
        result = search_parts(
            vehicle="2023 Honda Civic",
            part_type="brake pads"
        )
        
        # Should return cached results
        assert result['success'] == True
        assert result['source'] == 'cache'

def test_serp_api_network_failure():
    """Test network failure handling"""
    with patch('requests.get') as mock_get:
        # Simulate network error
        mock_get.side_effect = requests.ConnectionError()
        
        result = search_parts(
            vehicle="2023 Honda Civic",
            part_type="brake pads"
        )
        
        # Should fallback to alternative source
        assert result['success'] == True
        assert result['source'] == 'fallback'

def test_visa_api_timeout():
    """Test Visa API timeout handling"""
    with patch('requests.post') as mock_post:
        # Simulate timeout
        mock_post.side_effect = requests.Timeout()
        
        result = onboard_card(
            card_number='4111111111111111',
            expiration='12/25',
            cvv='123'
        )
        
        # Should retry with exponential backoff
        assert mock_post.call_count == 3  # 3 retries
        assert result['success'] == False
        assert 'timeout' in result['error'].lower()
```

**6. Monitoring API Health**

```python
# tests/monitoring/test_api_health.py
import pytest
from datetime import datetime, timedelta

@pytest.mark.monitoring
def test_serp_api_health():
    """Monitor SERP API health"""
    client = RealSerpClient(api_key=os.getenv('SERP_API_KEY'))
    
    start_time = datetime.now()
    
    try:
        response = client.search(query='test')
        latency = (datetime.now() - start_time).total_seconds()
        
        # Assert SLA: <2 seconds
        assert latency < 2.0, f"SERP API latency {latency}s exceeds SLA"
        
        # Log metrics
        cloudwatch.put_metric_data(
            Namespace='TradeIQ/ExternalAPIs',
            MetricData=[{
                'MetricName': 'SerpApiLatency',
                'Value': latency,
                'Unit': 'Seconds'
            }]
        )
        
    except Exception as e:
        # Alert on failure
        sns.publish(
            TopicArn='arn:aws:sns:us-east-1:123456789012:api-health-alerts',
            Subject='SERP API Health Check Failed',
            Message=f'Error: {str(e)}'
        )
        raise

@pytest.mark.monitoring
def test_visa_api_health():
    """Monitor Visa API health"""
    client = VisaClient(
        api_key=os.getenv('VISA_API_KEY'),
        environment='production'
    )
    
    start_time = datetime.now()
    
    try:
        # Health check endpoint
        response = client.health_check()
        latency = (datetime.now() - start_time).total_seconds()
        
        assert response['status'] == 'healthy'
        assert latency < 1.0
        
    except Exception as e:
        # Critical alert for payment API
        pagerduty.trigger_incident(
            title='Visa API Health Check Failed',
            severity='critical',
            details=str(e)
        )
        raise
```

**Why This Approach:**

1. **Fast Unit Tests:** Mocking eliminates external dependencies
2. **Contract Validation:** Ensures API compatibility
3. **Sandbox Testing:** Safe testing with real API structure
4. **Failure Resilience:** Tests all failure scenarios
5. **Monitoring:** Continuous health checks

**Results:**
- Zero production issues from API changes
- <30 second unit test execution
- 100% API contract coverage
- Proactive failure detection"

---

## 2. Serverless Backend Deployment

### Q4: "Why did you choose a serverless architecture, and what are the trade-offs?"

**What the interviewer is testing:**
- Architectural decision-making
- Understanding of serverless pros/cons
- Cost awareness
- Scalability knowledge

**Strong Answer:**

"I chose serverless architecture for TradeIQ based on specific requirements and trade-offs:

**Decision Criteria:**

**Requirements:**
- Variable traffic patterns (peak hours vs nights/weekends)
- Need for rapid scaling (0 → 1000 req/s in minutes)
- Minimal operational overhead (small team)
- Cost efficiency (pay-per-use)
- High availability (99.9%+ SLA)

**Serverless Components Used:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Serverless Architecture                   │
├─────────────────────────────────────────────────────────────┤
│ Compute:                                                     │
│   ├── ECS Fargate (AI agents) - Serverless containers       │
│   ├── AWS Lambda (event processing) - Functions             │
│   └── Bedrock AgentCore (AI orchestration) - Managed        │
│                                                              │
│ Database:                                                    │
│   ├── DynamoDB (on-demand) - Serverless NoSQL               │
│   └── DAX (caching) - Managed cache                         │
│                                                              │
│ API:                                                         │
│   ├── API Gateway - Managed API                             │
│   └── AppSync - Managed GraphQL                             │
│                                                              │
│ Auth:                                                        │
│   └── Cognito - Managed auth                                │
│                                                              │
│ Storage:                                                     │
│   ├── S3 - Object storage                                   │
│   └── Secrets Manager - Secrets                             │
└─────────────────────────────────────────────────────────────┘
```

**Why Serverless:**

**1. Cost Efficiency**
```
Traditional (EC2):
├── 24/7 running: $400/month (t3.large × 2)
├── Over-provisioning: 30% waste
├── Load balancer: $20/month
└── Total: $420/month (minimum)

Serverless (Fargate + Lambda):
├── Actual usage: $957/month (ARM64)
├── No over-provisioning: 0% waste
├── Auto-scaling: Included
└── Total: $957/month (scales with usage)

At 10K users: Serverless is 2.3x more expensive
At 50K users: Serverless is 1.2x more expensive
At 100K+ users: Serverless is cost-competitive

Decision: Chose serverless for operational simplicity
despite higher cost at current scale
```

**2. Operational Simplicity**
```
Traditional:
├── Server patching: Weekly
├── Scaling configuration: Manual
├── Load balancing: Manual setup
├── Monitoring: Custom setup
└── Team size: 2-3 DevOps engineers

Serverless:
├── Server patching: Automatic
├── Scaling configuration: Automatic
├── Load balancing: Built-in
├── Monitoring: Built-in (CloudWatch)
└── Team size: 0 dedicated DevOps

Savings: $200K/year in DevOps costs
```

**3. Scalability**
```
Traditional:
├── Scale-up time: 5-10 minutes (EC2 launch)
├── Manual intervention: Required
├── Over-provisioning: 30-50% for peaks
└── Max scale: Limited by instance count

Serverless:
├── Scale-up time: <60 seconds (Fargate)
├── Manual intervention: None
├── Over-provisioning: 0%
└── Max scale: Virtually unlimited

Result: Handle 10x traffic spike automatically
```

**Trade-offs Accepted:**

**1. Cold Starts**
```
Problem: First request to idle function takes 1-3 seconds

Mitigation:
├── Provisioned concurrency: 5 warm instances
├── Min tasks: 2 (always running)
├── Scheduled warming: Every 5 minutes
└── Cost: $50/month for warm instances

Result: <1% of requests experience cold start
```

**2. Vendor Lock-in**
```
Problem: AWS-specific services (Bedrock, Cognito, DynamoDB)

Mitigation:
├── Abstraction layers: CloudProvider interface
├── Standard protocols: GraphQL, REST, MCP
├── Containerization: Docker (portable)
└── Migration plan: 14-week timeline to GCP

Risk: Acceptable for 3-5 year horizon
```

**3. Debugging Complexity**
```
Problem: Distributed tracing across services

Mitigation:
├── AWS X-Ray: Distributed tracing
├── CloudWatch Logs: Centralized logging
├── Correlation IDs: Request tracking
└── Local testing: LocalStack

Result: Mean time to debug: 18 minutes
```

**4. Cost at Scale**
```
Problem: Serverless more expensive at very high scale

Mitigation:
├── Hybrid approach: EC2 for predictable workloads
├── Reserved capacity: Fargate Savings Plans
├── Cost monitoring: CloudWatch alarms
└── Migration trigger: >$5K/month serverless costs

Current: $1,761/month (well below trigger)
```

**When NOT to Use Serverless:**

❌ **Long-running batch jobs** (>15 min)
   → Use EC2 or ECS on EC2

❌ **Predictable, constant load** (24/7 high traffic)
   → Use EC2 with reserved instances

❌ **Latency-critical** (<10ms p99)
   → Use EC2 with optimized networking

❌ **Stateful applications** (WebSocket connections)
   → Use EC2 or ECS on EC2

✅ **Variable traffic** (our case)
✅ **Event-driven** (our case)
✅ **Rapid scaling** (our case)
✅ **Small team** (our case)

**Results:**
- 99.95% availability (exceeds 99.9% SLA)
- <60 second scale-up time
- $0.16 per user cost
- Zero server management
- 2-person team (vs 5-person traditional)"


---

### Q5: "Walk me through your Infrastructure as Code (IaC) approach and deployment process."

**What the interviewer is testing:**
- IaC best practices
- Deployment automation
- Environment management
- Rollback capabilities

**Strong Answer:**

"I use AWS CDK (TypeScript) for Infrastructure as Code with a multi-stack architecture:

**1. IaC Architecture**

```
infrastructure/
├── mcp-servers/              # MCP runtime stacks
│   ├── lib/
│   │   ├── base-mcp-stack.ts    # Base class (DRY)
│   │   ├── cart-stack.ts        # Cart service
│   │   └── shopping-stack.ts    # Shopping service
│   ├── cdk.json
│   └── package.json
│
├── agent-stack/              # Main supervisor agent
│   ├── lib/
│   │   ├── agent-stack.ts       # Stack definition
│   │   └── constructs/
│   │       └── gateway-construct.ts  # Reusable construct
│   ├── lambdas/
│   │   └── oauth-provider/      # Custom resource
│   ├── cdk.json
│   └── package.json
│
└── frontend-stack/           # Amplify hosting
    ├── lib/
    │   └── frontend-stack.ts
    ├── cdk.json
    └── package.json
```

**2. Base MCP Stack (Reusable Pattern)**

```typescript
// infrastructure/mcp-servers/lib/base-mcp-stack.ts
import * as cdk from 'aws-cdk-lib';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as bedrock from '@aws-cdk/aws-bedrock-agentcore-alpha';

export interface BaseMcpStackProps extends cdk.StackProps {
  serviceName: string;
  dockerfilePath: string;
  environment: { [key: string]: string };
  memoryLimitMiB: number;
  cpu: number;
  desiredCount: number;
  maxCapacity: number;
}

export class BaseMcpStack extends cdk.Stack {
  public readonly runtime: bedrock.Runtime;
  public readonly taskRole: iam.Role;
  
  constructor(scope: cdk.App, id: string, props: BaseMcpStackProps) {
    super(scope, id, props);
    
    // Import VPC from Amplify stack
    const vpc = ec2.Vpc.fromLookup(this, 'VPC', {
      vpcId: cdk.Fn.importValue(`ConciergeAgent-${deploymentId}-VPC-Id`)
    });
    
    // ECS Cluster
    const cluster = new ecs.Cluster(this, 'Cluster', {
      vpc,
      clusterName: `${props.serviceName}-cluster`
    });
    
    // Task Role (IAM permissions)
    this.taskRole = new iam.Role(this, 'TaskRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      description: `Task role for ${props.serviceName}`
    });
    
    // Grant Bedrock permissions
    this.taskRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'bedrock:InvokeModel',
        'bedrock:InvokeModelWithResponseStream'
      ],
      resources: ['*']
    }));
    
    // Grant CloudWatch permissions
    this.taskRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'logs:CreateLogGroup',
        'logs:CreateLogStream',
        'logs:PutLogEvents'
      ],
      resources: ['*']
    }));
    
    // Task Definition
    const taskDefinition = new ecs.FargateTaskDefinition(this, 'TaskDef', {
      memoryLimitMiB: props.memoryLimitMiB,
      cpu: props.cpu,
      taskRole: this.taskRole,
      runtimePlatform: {
        cpuArchitecture: ecs.CpuArchitecture.ARM64,  // 20% cost savings
        operatingSystemFamily: ecs.OperatingSystemFamily.LINUX
      }
    });
    
    // Container from Dockerfile
    const container = taskDefinition.addContainer('Container', {
      image: ecs.ContainerImage.fromAsset(props.dockerfilePath),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: props.serviceName,
        logRetention: logs.RetentionDays.ONE_MONTH
      }),
      environment: props.environment,
      healthCheck: {
        command: ['CMD-SHELL', 'curl -f http://localhost:8000/health || exit 1'],
        interval: cdk.Duration.seconds(30),
        timeout: cdk.Duration.seconds(5),
        retries: 3,
        startPeriod: cdk.Duration.seconds(60)
      }
    });
    
    container.addPortMappings({
      containerPort: 8000,
      protocol: ecs.Protocol.TCP
    });
    
    // Fargate Service
    const service = new ecs.FargateService(this, 'Service', {
      cluster,
      taskDefinition,
      desiredCount: props.desiredCount,
      minHealthyPercent: 50,  // Allow 50% capacity during deployment
      maxHealthyPercent: 200,  // Allow 2x capacity during deployment
      healthCheckGracePeriod: cdk.Duration.seconds(60),
      circuitBreaker: { rollback: true }  // Auto-rollback on failure
    });
    
    // Auto-scaling
    const scaling = service.autoScaleTaskCount({
      minCapacity: props.desiredCount,
      maxCapacity: props.maxCapacity
    });
    
    scaling.scaleOnCpuUtilization('CpuScaling', {
      targetUtilizationPercent: 70,
      scaleInCooldown: cdk.Duration.seconds(300),
      scaleOutCooldown: cdk.Duration.seconds(60)
    });
    
    scaling.scaleOnMemoryUtilization('MemoryScaling', {
      targetUtilizationPercent: 80,
      scaleInCooldown: cdk.Duration.seconds(300),
      scaleOutCooldown: cdk.Duration.seconds(60)
    });
    
    // Bedrock AgentCore Runtime
    this.runtime = new bedrock.Runtime(this, 'Runtime', {
      runtimeName: `${props.serviceName}-runtime`,
      runtimeType: bedrock.RuntimeType.MCP,
      runtimeConfig: {
        ecsCluster: cluster.clusterArn,
        ecsService: service.serviceArn,
        taskDefinition: taskDefinition.taskDefinitionArn
      },
      authConfig: {
        type: bedrock.AuthType.OAUTH,
        oauthConfig: {
          clientId: cdk.Fn.importValue(`ConciergeAgent-${deploymentId}-Auth-MachineClientId`),
          tokenUrl: `https://cognito-idp.${this.region}.amazonaws.com/${userPoolId}/oauth2/token`
        }
      }
    });
    
    // Outputs
    new cdk.CfnOutput(this, 'RuntimeArn', {
      value: this.runtime.runtimeArn,
      exportName: `${id}-RuntimeArn`
    });
    
    new cdk.CfnOutput(this, 'RuntimeId', {
      value: this.runtime.runtimeId,
      exportName: `${id}-RuntimeId`
    });
  }
}
```

**3. Specific Stack Implementation**

```typescript
// infrastructure/mcp-servers/lib/cart-stack.ts
import { BaseMcpStack, BaseMcpStackProps } from './base-mcp-stack';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';

export class CartStack extends BaseMcpStack {
  constructor(scope: cdk.App, id: string) {
    // Import DynamoDB tables from Amplify stack
    const userProfileTable = dynamodb.Table.fromTableName(
      this, 'UserProfileTable',
      cdk.Fn.importValue(`ConciergeAgent-${deploymentId}-Data-UserProfileTableName`)
    );
    
    const wishlistTable = dynamodb.Table.fromTableName(
      this, 'WishlistTable',
      cdk.Fn.importValue(`ConciergeAgent-${deploymentId}-Data-WishlistTableName`)
    );
    
    super(scope, id, {
      serviceName: 'cart',
      dockerfilePath: '../../concierge_agent/mcp_cart_tools',
      environment: {
        AWS_REGION: process.env.CDK_DEFAULT_REGION!,
        USER_PROFILE_TABLE_NAME: userProfileTable.tableName,
        WISHLIST_TABLE_NAME: wishlistTable.tableName,
        DEPLOYMENT_ID: deploymentId
      },
      memoryLimitMiB: 2048,
      cpu: 1024,
      desiredCount: 2,
      maxCapacity: 100
    });
    
    // Grant DynamoDB permissions
    userProfileTable.grantReadWriteData(this.taskRole);
    wishlistTable.grantReadWriteData(this.taskRole);
    
    // Grant Secrets Manager access for Visa credentials
    const visaSecret = secretsmanager.Secret.fromSecretNameV2(
      this, 'VisaSecret',
      'visa-api-credentials'
    );
    visaSecret.grantRead(this.taskRole);
  }
}
```

**4. Deployment Process**

```bash
# package.json scripts
{
  "scripts": {
    "deploy:amplify": "npx ampx sandbox --once --identifier $(node -p \"require('./deployment-config.json').deploymentId\")",
    "deploy:mcp": "find concierge_agent/mcp_* -name Dockerfile -exec touch {} \\; && cd infrastructure/mcp-servers && npm install && cdk deploy --all --require-approval never",
    "deploy:agent": "cd infrastructure/agent-stack && npm install && cdk deploy --require-approval never && cd ../.. && ./scripts/sync-gateway.sh",
    "deploy:frontend": "cd infrastructure/frontend-stack && npm install && cdk deploy --require-approval never && cd ../.. && ./scripts/deploy-frontend.sh",
    "deploy": "npm run deploy:amplify && npm run deploy:mcp && npm run deploy:agent && npm run deploy:frontend"
  }
}
```

**Deployment Order (Critical):**

```
1. Amplify Backend (Cognito, DynamoDB)
   ├── Creates: User pools, DynamoDB tables
   ├── Exports: CloudFormation exports
   └── Time: ~3 minutes

2. MCP Servers (Shopping, Cart, Payment)
   ├── Imports: Cognito config, DynamoDB tables
   ├── Creates: ECS services, Bedrock runtimes
   ├── Exports: Runtime ARNs
   └── Time: ~60 seconds

3. Agent Stack (Supervisor)
   ├── Imports: MCP runtime ARNs, Cognito, DynamoDB
   ├── Creates: Main agent, Gateway, Memory
   ├── Exports: Gateway URL
   └── Time: ~4 minutes

4. Frontend Stack (Amplify Hosting)
   ├── Imports: Gateway URL, Cognito config
   ├── Creates: Amplify app, S3 bucket
   └── Time: ~3 minutes

Total: ~11 minutes
```

**5. Environment Management**

```json
// deployment-config.json
{
  "deploymentId": "shopping",
  "description": "Unique identifier for this deployment"
}

// Supports multiple deployments in same account:
// - shopping-dev
// - shopping-qa
// - shopping-staging
// - shopping (production)
```

```typescript
// Read deployment ID in CDK
const deploymentId = require('../../deployment-config.json').deploymentId;

// Use in resource names
const stackName = `CartStack-${deploymentId}`;
const tableName = `${deploymentId}-UserProfile`;
```

**6. Cross-Stack References**

```typescript
// Export from Amplify stack
new cdk.CfnOutput(this, 'UserPoolId', {
  value: userPool.userPoolId,
  exportName: `ConciergeAgent-${deploymentId}-Auth-UserPoolId`
});

// Import in MCP stack
const userPoolId = cdk.Fn.importValue(
  `ConciergeAgent-${deploymentId}-Auth-UserPoolId`
);
```

**7. Rollback Strategy**

```typescript
// Automatic rollback on deployment failure
const service = new ecs.FargateService(this, 'Service', {
  cluster,
  taskDefinition,
  circuitBreaker: { rollback: true },  // Auto-rollback
  deploymentController: {
    type: ecs.DeploymentControllerType.ECS  // Rolling update
  }
});

// CloudFormation rollback on stack failure
// Automatic: CDK handles this
```

**Manual Rollback:**
```bash
# Rollback to previous task definition
aws ecs update-service \
  --cluster cart-cluster \
  --service cart-service \
  --task-definition cart-task:previous

# Rollback entire stack
cdk deploy --rollback
```

**8. Deployment Validation**

```bash
# scripts/validate-deployment.sh
#!/bin/bash
set -e

echo "Validating deployment..."

# Check ECS service health
SERVICE_STATUS=$(aws ecs describe-services \
  --cluster cart-cluster \
  --services cart-service \
  --query 'services[0].status' \
  --output text)

if [ "$SERVICE_STATUS" != "ACTIVE" ]; then
  echo "❌ Service not active: $SERVICE_STATUS"
  exit 1
fi

# Check task health
RUNNING_COUNT=$(aws ecs describe-services \
  --cluster cart-cluster \
  --services cart-service \
  --query 'services[0].runningCount' \
  --output text)

DESIRED_COUNT=$(aws ecs describe-services \
  --cluster cart-cluster \
  --services cart-service \
  --query 'services[0].desiredCount' \
  --output text)

if [ "$RUNNING_COUNT" -lt "$DESIRED_COUNT" ]; then
  echo "❌ Not enough tasks running: $RUNNING_COUNT/$DESIRED_COUNT"
  exit 1
fi

# Health check endpoint
HEALTH_URL="https://api.tradeiq.com/health"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

if [ "$HEALTH_STATUS" != "200" ]; then
  echo "❌ Health check failed: $HEALTH_STATUS"
  exit 1
fi

echo "✅ Deployment validated successfully"
```

**Why CDK Over Terraform:**

**CDK Advantages:**
- Type safety (TypeScript)
- AWS-native (first-class support)
- Reusable constructs (OOP)
- Automatic dependency management
- CloudFormation rollback

**Terraform Advantages:**
- Multi-cloud support
- Larger community
- State management
- More mature

**Decision:** CDK for AWS-only project with complex dependencies

**Results:**
- 11-minute full deployment
- Zero manual steps
- Automatic rollback on failure
- 98.5% deployment success rate
- Consistent environments (dev, qa, staging, prod)"

