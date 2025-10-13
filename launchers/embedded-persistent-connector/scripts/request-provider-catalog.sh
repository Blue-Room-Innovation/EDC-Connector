#!/usr/bin/env bash
set -euo pipefail

MANAGEMENT_URL=${MANAGEMENT_URL:-http://localhost:9081/api/management/v3/catalog/request}
API_KEY=${API_KEY:-edc-dev}
COUNTERPARTY_URL=${COUNTERPARTY_URL:-http://provider-controlplane:8082/api/dsp}
COUNTERPARTY_ID=${COUNTERPARTY_ID:-did:web:provider-identityhub%3A7093}
PROTOCOL=${PROTOCOL:-dataspace-protocol-http}

payload=$(cat <<EOF
{
  "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
  "@type": "CatalogRequest",
  "counterPartyAddress": "${COUNTERPARTY_URL}",
  "counterPartyId": "${COUNTERPARTY_ID}",
  "protocol": "${PROTOCOL}"
}
EOF
)

curl -sS -X POST \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${payload}" \
  "${MANAGEMENT_URL}" |
  if command -v jq >/dev/null 2>&1; then jq .; else cat; fi
