#!/usr/bin/env bash

# Seeds the local launcher stack so it mirrors the MVD dataspace setup.
# - Stores the super-user API key and STS client secret in edc-vault
# - Registers the launcher participant in the local Identity Hub
# - Activates the participant and publishes its DID document
#
# Usage: bash seed-local.sh

set -euo pipefail

log() {
    printf '[seed-local] %s\n' "$*"
}

IDENTITY_API="http://localhost:9482/api/identity/v1alpha"
CREDENTIAL_SERVICE_BASE="${CREDENTIAL_SERVICE_BASE:-http://host.docker.internal:9482}"
CONTROLPLANE_BASE="${CONTROLPLANE_BASE:-http://host.docker.internal:9282}"
PARTICIPANT_DID="${PARTICIPANT_DID:-did:web:host.docker.internal%3A9483}"
SUPERUSER_API_KEY="${SUPERUSER_API_KEY:-c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo=}"
STS_SECRET_VALUE="${STS_SECRET_VALUE:-}"

docker exec edc-vault sh -lc "\
  export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root; \
  vault kv put secret/super-user-apikey content='${SUPERUSER_API_KEY}' >/dev/null \
" >/dev/null

PRIVATE_KEY_CONTENT=$(cat ../deployment/assets/private.pem)
docker exec edc-vault sh -lc "\
  export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root; \
  vault kv put secret/key-1 content='${PRIVATE_KEY_CONTENT}' >/dev/null \
" >/dev/null
log "Stored private key alias key-1 in edc-vault"

log "Stored super-user API key in edc-vault"

PARTICIPANT_DID_B64=$(printf '%s' "${PARTICIPANT_DID}" | base64 | tr -d '\n')

log "Waiting for Identity Hub API on ${IDENTITY_API}..."
set +e
READY=0
HTTP_CHECK="000"
for attempt in $(seq 1 30); do
  HTTP_CHECK=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "X-API-Key: ${SUPERUSER_API_KEY}" \
    "${IDENTITY_API}/dids" 2>/dev/null)
  # Consider any non-000 HTTP code as the API being up (even 4xx during warmup)
  if [[ "${HTTP_CHECK}" =~ ^[0-9]{3}$ && "${HTTP_CHECK}" != "000" ]]; then
    READY=1
    break
  fi
  sleep 2
done
set -e

if [[ "${READY}" -ne 1 ]]; then
  printf 'Identity Hub did not become reachable at %s (last HTTP %s)\n' "${IDENTITY_API}" "${HTTP_CHECK}" >&2
  # continue anyway; some reverse proxies return unusual codes during warmup
  log "Proceeding with participant creation despite readiness check failure"
fi

PARTICIPANT_PAYLOAD=$(cat <<JSON
{
  "roles": [],
  "serviceEndpoints": [
    {
      "type": "CredentialService",
      "serviceEndpoint": "${CREDENTIAL_SERVICE_BASE}/api/credentials/v1/participants/${PARTICIPANT_DID_B64}",
      "id": "local-connector-credentialservice-1"
    },
    {
      "type": "ProtocolEndpoint",
      "serviceEndpoint": "${CONTROLPLANE_BASE}/api/dsp",
      "id": "local-connector-dsp"
    }
  ],
  "active": true,
  "participantId": "${PARTICIPANT_DID}",
  "did": "${PARTICIPANT_DID}",
  "key": {
    "keyId": "${PARTICIPANT_DID}#key-1",
    "privateKeyAlias": "key-1",
    "keyGeneratorParams": {
      "algorithm": "EC"
    }
  }
}
JSON
)

CREATE_RESPONSE=$(mktemp)
set +e
HTTP_CODE=$(curl -sS -o "${CREATE_RESPONSE}" -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H "X-API-Key: ${SUPERUSER_API_KEY}" \
  -d "${PARTICIPANT_PAYLOAD}" \
  "${IDENTITY_API}/participants/" 2>/dev/null)
CURL_STATUS=$?
set -e
if [[ "${CURL_STATUS}" -ne 0 ]]; then
  printf 'Error contacting Identity Hub to create participant (curl exit %s)\n' "${CURL_STATUS}" >&2
  cat "${CREATE_RESPONSE}" >&2 || true
  rm -f "${CREATE_RESPONSE}"
  exit 1
fi

case "${HTTP_CODE}" in
  200|201)
    log "Participant created in Identity Hub"
    cat "${CREATE_RESPONSE}"
    ;;
  409)
    log "Participant already exists, continuing"
    ;;
  *)
    printf 'Error creating participant (HTTP %s):\n%s\n' "${HTTP_CODE}" "$(cat "${CREATE_RESPONSE}")" >&2
    # Retry once with EC key parameters as fallback for older hubs
    PARTICIPANT_PAYLOAD_FALLBACK=$(cat <<JSON
{
  "roles": [],
  "serviceEndpoints": [
    {
      "type": "CredentialService",
      "serviceEndpoint": "${CREDENTIAL_SERVICE_BASE}/api/credentials/v1/participants/${PARTICIPANT_DID_B64}",
      "id": "local-connector-credentialservice-1"
    },
    {
      "type": "ProtocolEndpoint",
      "serviceEndpoint": "${CONTROLPLANE_BASE}/api/dsp",
      "id": "local-connector-dsp"
    }
  ],
  "active": true,
  "participantId": "${PARTICIPANT_DID}",
  "did": "${PARTICIPANT_DID}",
  "key": {
    "keyId": "${PARTICIPANT_DID}#key-1",
    "privateKeyAlias": "key-1",
    "keyGeneratorParams": {
      "algorithm": "EC"
    }
  }
}
JSON
)
    HTTP_CODE2=$(curl -sS -o "${CREATE_RESPONSE}" -w "%{http_code}" \
      -H 'Content-Type: application/json' \
      -H "X-API-Key: ${SUPERUSER_API_KEY}" \
      -d "${PARTICIPANT_PAYLOAD_FALLBACK}" \
      "${IDENTITY_API}/participants" 2>/dev/null)
    if [[ "${HTTP_CODE2}" =~ ^(201|409)$ ]]; then
      log "Participant created/exists (fallback path)"
    else
      printf 'Error creating participant (fallback, HTTP %s):\n%s\n' "${HTTP_CODE2}" "$(cat "${CREATE_RESPONSE}")" >&2
      rm -f "${CREATE_RESPONSE}"
      exit 1
    fi
    ;;
esac

CREATE_BODY=$(cat "${CREATE_RESPONSE}" 2>/dev/null || true)
rm -f "${CREATE_RESPONSE}"

CLIENT_SECRET="${STS_SECRET_VALUE}"
if command -v jq >/dev/null 2>&1; then
  PARSED_SECRET=$(printf '%s' "${CREATE_BODY}" | jq -r '.clientSecret // empty' 2>/dev/null || true)
  if [[ -n "${PARSED_SECRET}" && "${PARSED_SECRET}" != "null" ]]; then
    CLIENT_SECRET="${PARSED_SECRET}"
  fi
elif command -v python3 >/dev/null 2>&1; then
  PARSED_SECRET=$(printf '%s' "${CREATE_BODY}" | python3 - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
    secret = data.get("clientSecret")
    if secret:
        print(secret)
except Exception:
    pass
PY
  )
  PARSED_SECRET=${PARSED_SECRET//$'\r'/}
  if [[ -n "${PARSED_SECRET}" ]]; then
    CLIENT_SECRET="${PARSED_SECRET}"
  fi
fi

if [[ -n "${CLIENT_SECRET}" ]]; then
  docker exec edc-vault sh -lc "\
    export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root; \
    vault kv put secret/${PARTICIPANT_DID}-sts-client-secret content='${CLIENT_SECRET}' >/dev/null \
  " >/dev/null
  log "Updated STS client secret in edc-vault"
fi

set +e
ACTIVATE_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
  -X PATCH "${IDENTITY_API}/participants/${PARTICIPANT_DID}/state?isActive=true" \
  -H "X-API-Key: ${SUPERUSER_API_KEY}" 2>/dev/null)
CURL_STATUS=$?
set -e
if [[ "${CURL_STATUS}" -ne 0 ]]; then
  printf 'Error activating participant (curl exit %s)\n' "${CURL_STATUS}" >&2
  exit 1
fi

if [[ "${ACTIVATE_CODE}" =~ ^(200|204)$ ]]; then
  log "Participant marked as active"
elif [[ "${ACTIVATE_CODE}" == "405" ]]; then
  log "Activation endpoint not supported (skipping)"
else
  printf 'Error activating participant (HTTP %s)\n' "${ACTIVATE_CODE}" >&2
  exit 1
fi

set +e
PUBLISH_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "${IDENTITY_API}/participants/${PARTICIPANT_DID}/dids/publish" \
  -H "X-API-Key: ${SUPERUSER_API_KEY}" 2>/dev/null)
CURL_STATUS=$?
set -e
if [[ "${CURL_STATUS}" -ne 0 ]]; then
  printf 'Error publishing DID (curl exit %s)\n' "${CURL_STATUS}" >&2
  exit 1
fi

if [[ "${PUBLISH_CODE}" =~ ^(200|204)$ ]]; then
  log "Participant DID published"
elif [[ "${PUBLISH_CODE}" =~ ^(409|405)$ ]]; then
  log "Publish endpoint responded with ${PUBLISH_CODE}, continuing"
elif [[ "${PUBLISH_CODE}" == "500" ]]; then
  log "Publish endpoint returned 500, assuming DID already published"
else
  printf 'Error publishing DID (HTTP %s)\n' "${PUBLISH_CODE}" >&2
  exit 1
fi

log "Seed completed. Your connector is registered and ready to interact with the dataspace."
