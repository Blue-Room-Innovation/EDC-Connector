#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:9081/api/management/v3}
API_KEY=${API_KEY:-edc-dev}
ASSET_ID=${ASSET_ID:-asset-json}
POLICY_ID=${POLICY_ID:-policy-allow-all}
CONTRACT_ID=${CONTRACT_ID:-contract-allow-all}

if command -v jq >/dev/null 2>&1; then
  jq_present=1
else
  jq_present=0
fi

curl_cmd() {
  curl -sS -X "$1" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$3" \
    "${BASE_URL}/${2}" |
    if [ ${jq_present} -eq 1 ]; then jq .; else cat; fi
}

echo "Publishing asset ${ASSET_ID}"
curl_cmd POST "assets" "{\n  \"@context\": {\"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\"},\n  \"@type\": \"Asset\",\n  \"@id\": \"${ASSET_ID}\",\n  \"properties\": {\"edc:title\": \"demo-user-list\"},\n  \"dataAddress\": {\n    \"@type\": \"DataAddress\",\n    \"type\": \"HttpData\",\n    \"baseUrl\": \"https://jsonplaceholder.typicode.com/users\"\n  }\n}"

echo "Publishing allow-all policy ${POLICY_ID}"
curl_cmd POST "policydefinitions" "{\n  \"@context\": {\"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\"},\n  \"@type\": \"PolicyDefinition\",\n  \"@id\": \"${POLICY_ID}\",\n  \"policy\": {\n    \"@type\": \"Policy\",\n    \"permissions\": [ { \"edc:action\": { \"type\": \"USE\" } } ]\n  }\n}"

echo "Publishing contract definition ${CONTRACT_ID}"
curl_cmd POST "contractdefinitions" "{\n  \"@context\": {\"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\"},\n  \"@type\": \"ContractDefinition\",\n  \"@id\": \"${CONTRACT_ID}\",\n  \"accessPolicyId\": \"${POLICY_ID}\",\n  \"contractPolicyId\": \"${POLICY_ID}\",\n  \"assetsSelector\": [ {\n    \"operandLeft\": \"https://w3id.org/edc/v0.0.1/ns/id\",\n    \"operator\": \"=\",\n    \"operandRight\": \"${ASSET_ID}\"\n  } ]\n}"

echo "Seed complete"
