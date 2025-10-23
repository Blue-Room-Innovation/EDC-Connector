#!/usr/bin/env bash

set -euo pipefail

# Registra este conector local (EDC-Connector) como participante en el Identity Hub
# del proveedor de i2cat (edc-scenario-main), sin modificar su docker-compose.
#
# Requisitos:
# - i2cat provider levantado en local con puertos publicados (por defecto 7091 para API de identidad)
# - Este EDC-Connector arrancado (compose en launchers) y seed-local ejecutado (para tener DID/VCs y Vault)
# - En Docker Desktop (Win/Mac), host.docker.internal debe resolver desde los contenedores
#
# Variables override (opcionales):
#   I2CAT_PROVIDER_IDENTITY_HOST   (default: localhost)
#   I2CAT_PROVIDER_IDENTITY_PORT   (default: 7091)
#   SUPERUSER_API_KEY              (default: i2cat demo key)
#   PARTICIPANT_DID                (default: did:web:host.docker.internal%3A9483)

log() { printf '[seed-i2cat] %s\n' "$*"; }

I2CAT_PROVIDER_IDENTITY_HOST="${I2CAT_PROVIDER_IDENTITY_HOST:-localhost}"
I2CAT_PROVIDER_IDENTITY_PORT="${I2CAT_PROVIDER_IDENTITY_PORT:-7091}"
IDENTITY_API_BASE="http://${I2CAT_PROVIDER_IDENTITY_HOST}:${I2CAT_PROVIDER_IDENTITY_PORT}/api/identity/v1alpha"

SUPERUSER_API_KEY="${SUPERUSER_API_KEY:-c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo=}"

# Este DID coincide con la configuración de launchers/controlplane e identity-hub
PARTICIPANT_DID="${PARTICIPANT_DID:-did:web:host.docker.internal%3A9483}"

PARTICIPANT_DID_B64=$(printf '%s' "${PARTICIPANT_DID}" | base64 | tr -d '\n')

CREDENTIAL_SERVICE="http://host.docker.internal:9481/api/credentials/v1/participants/${PARTICIPANT_DID_B64}"
PROTOCOL_ENDPOINT="http://host.docker.internal:9282/api/dsp"

read -r -d '' PAYLOAD <<JSON
{
  "roles": [],
  "serviceEndpoints": [
    {
      "type": "CredentialService",
      "serviceEndpoint": "${CREDENTIAL_SERVICE}",
      "id": "edc-connector-credentialservice-1"
    },
    {
      "type": "ProtocolEndpoint",
      "serviceEndpoint": "${PROTOCOL_ENDPOINT}",
      "id": "edc-connector-dsp"
    }
  ],
  "active": true,
  "participantId": "${PARTICIPANT_DID}",
  "did": "${PARTICIPANT_DID}",
  "key": {
    "keyId": "${PARTICIPANT_DID}#key-1",
    "privateKeyAlias": "${PARTICIPANT_DID}-alias",
    "keyGeneratorParams": { "algorithm": "EdDSA", "curve": "Ed25519" }
  }
}
JSON

TMP=$(mktemp)
set +e
HTTP_CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${SUPERUSER_API_KEY}" \
  -d "${PAYLOAD}" \
  "${IDENTITY_API_BASE}/participants/" 2>/dev/null)
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  log "Error conectando con Identity Hub del provider (curl exit $STATUS)"; cat "$TMP" || true; rm -f "$TMP"; exit 1
fi

case "$HTTP_CODE" in
  201) log "Participante creado en Identity Hub del provider"; cat "$TMP";;
  409) log "Participante ya existe en Identity Hub del provider";;
  *) log "Error creando participante (HTTP $HTTP_CODE)"; cat "$TMP"; rm -f "$TMP"; exit 1;;
esac

rm -f "$TMP"
log "Seed i2cat completado. El provider podrá resolver tu DSP y Credentials en host.docker.internal."

