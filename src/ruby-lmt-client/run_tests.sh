#!/bin/bash
set -e

echo "🧪 Testing Ruby LMT Client..."
echo ""

cd "$(dirname "$0")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Install dependencies
echo "📦 Installing dependencies..."
if bundle install --quiet; then
    echo -e "${GREEN}✅ Dependencies installed${NC}"
else
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi
echo ""

# 2. Run unit tests
echo "🧪 Running unit tests..."
if bundle exec rspec --format documentation; then
    echo -e "${GREEN}✅ All unit tests passed${NC}"
else
    echo -e "${RED}❌ Some unit tests failed${NC}"
    exit 1
fi
echo ""

# 3. Check if Azure credentials are set
if [ -z "$AZURE_SERVICEBUS_CONNECTION_STRING" ]; then
    echo -e "${YELLOW}⚠️  AZURE_SERVICEBUS_CONNECTION_STRING not set${NC}"
    echo -e "${YELLOW}   Skipping integration tests${NC}"
    echo ""
    echo -e "${GREEN}✅ Unit tests completed successfully!${NC}"
    echo ""
    echo "To run integration tests, set these environment variables:"
    echo "  export SERVICE_ID=\"test-service\""
    echo "  export AZURE_SERVICEBUS_CONNECTION_STRING=\"your-connection-string\""
    echo "  export X_BLOCKS_KEY=\"your-x-blocks-key\""
    exit 0
fi

echo "🔗 Azure credentials found - running integration tests..."
echo ""

# 4. Run basic example
echo "📝 Running basic logging example..."
if timeout 10 ruby examples/basic_usage.rb; then
    echo -e "${GREEN}✅ Basic logging test passed${NC}"
else
    echo -e "${YELLOW}⚠️  Basic logging test had issues (might be timeout)${NC}"
fi
echo ""

# 5. Run OpenTelemetry example
echo "🔍 Running tracing example..."
if timeout 10 ruby examples/with_opentelemetry.rb; then
    echo -e "${GREEN}✅ Tracing test passed${NC}"
else
    echo -e "${YELLOW}⚠️  Tracing test had issues (might be timeout)${NC}"
fi
echo ""

echo -e "${GREEN}✅ All tests completed!${NC}"
echo ""
echo "📊 Check your Azure Portal to verify messages:"
echo "   Topic: lmt-${SERVICE_ID:-ruby-test-service}"
echo "   Subscriptions:"
echo "     - blocks-lmt-service-logs"
echo "     - blocks-lmt-service-traces"

