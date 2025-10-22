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
CREDENTIAL_SERVICE_BASE="http://localhost:9481"
CONTROLPLANE_BASE="http://localhost:9282"
PARTICIPANT_DID="${PARTICIPANT_DID:-did:web:localhost%3A8281}"
SUPERUSER_API_KEY="${SUPERUSER_API_KEY:-c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo=}"
STS_SECRET_VALUE="${STS_SECRET_VALUE:-change-me}"

docker exec edc-vault sh -lc "\
  export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root; \
  vault kv put secret/super-user-apikey content='${SUPERUSER_API_KEY}' >/dev/null; \
  vault kv put secret/${PARTICIPANT_DID}-sts-client-secret content='${STS_SECRET_VALUE}' >/dev/null \
" >/dev/null

log "Stored super-user API key and STS secret in edc-vault"

PARTICIPANT_DID_B64=$(printf '%s' "${PARTICIPANT_DID}" | base64 | tr -d '\n')

log "Waiting for Identity Hub API on ${IDENTITY_API}..."
set +e
READY=0
for attempt in {1..30}; do
  HTTP_CHECK=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "X-API-Key: ${SUPERUSER_API_KEY}" \
    "${IDENTITY_API}/dids" 2>/dev/null)
  if [[ "${HTTP_CHECK}" =~ ^(200|204|401|404)$ ]]; then
    READY=1
    break
  fi
  sleep 2
done
set -e

if [[ "${READY}" -ne 1 ]]; then
  printf 'Identity Hub did not become reachable at %s (last HTTP %s)\n' "${IDENTITY_API}" "${HTTP_CHECK}" >&2
  exit 1
fi

read -r -d '' PARTICIPANT_PAYLOAD <<JSON
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
    "privateKeyAlias": "${PARTICIPANT_DID}-alias",
    "keyGeneratorParams": {
      "algorithm": "EdDSA",
      "curve": "Ed25519"
    }
  }
}
JSON

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
  201)
    log "Participant created in Identity Hub"
    cat "${CREATE_RESPONSE}"
    ;;
  409)
    log "Participant already exists, continuing"
    ;;
  *)
    printf 'Error creating participant (HTTP %s):\n%s\n' "${HTTP_CODE}" "$(cat "${CREATE_RESPONSE}")" >&2
    rm -f "${CREATE_RESPONSE}"
    exit 1
    ;;
esac

rm -f "${CREATE_RESPONSE}"

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
else
  printf 'Error publishing DID (HTTP %s)\n' "${PUBLISH_CODE}" >&2
  exit 1
fi

log "Seed completed. Your connector is registered and ready to interact with the dataspace."
