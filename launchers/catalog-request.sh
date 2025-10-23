#!/usr/bin/env bash

set -euo pipefail

# Solicita el catálogo al provider de i2cat usando la Management API local del controlplane.
# Por defecto apunta al DSP publicado en localhost:8282 (provider-controlplane en i2cat).
#
# Variables override:
#   EDC_MGMT_URL      (default: http://localhost:9281)
#   EDC_MGMT_TOKEN    (default: password)
#   PROVIDER_DSP_URL  (default: http://host.docker.internal:8282/api/dsp)
#   PROVIDER_DID      (default: did:web:provider-identityhub%3A7093)

EDC_MGMT_URL="${EDC_MGMT_URL:-http://localhost:9281}"
EDC_MGMT_TOKEN="${EDC_MGMT_TOKEN:-password}"
PROVIDER_DSP_URL="${PROVIDER_DSP_URL:-http://host.docker.internal:8282/api/dsp}"
PROVIDER_DID="${PROVIDER_DID:-did:web:provider-identityhub%3A7093}"

BODY=$(cat <<JSON
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "@type": "CatalogRequest",
  "counterPartyId": "${PROVIDER_DID}",
  "counterPartyAddress": "${PROVIDER_DSP_URL}",
  "protocol": "dataspace-protocol-http",
  "querySpec": { "offset": 0, "limit": 50 }
}
JSON
)

echo "[catalog-request] Solicitando catálogo a ${PROVIDER_DSP_URL} como ${PROVIDER_DID}..." >&2
RESP=$(curl -sS -X POST "${EDC_MGMT_URL}/api/management/v3/catalog/request" \
  -H "Authorization: Bearer ${EDC_MGMT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${BODY}")
if command -v ${JQ_BIN:-jq} >/dev/null 2>&1; then
  echo "$RESP" | ${JQ_BIN:-jq} .
else
  echo "$RESP"
fi
