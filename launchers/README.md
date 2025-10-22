# Launchers

This directory contains the runnable launchers for the control plane, data plane and identity hub runtimes. The instructions below explain how to build and run the connector locally with the same configuration shape that the MVD and edc-scenario participants use.

## Prerequisites

- Docker Desktop (or a Docker daemon) running.
- JDK 17+ and Gradle wrapper (already included in the repository).
- Ports 8280-8285, 8081, 8290 and 8380-8386 available on your host.

## 1. Build the launcher runtimes (only when you changed code)

```powershell
cd C:\repos\dataspaces\EDC-Connector
./gradlew -Ppersistence=true ^
    :launchers:controlplane:shadowJar ^
    :launchers:dataplane:shadowJar ^
    :launchers:identity-hub:shadowJar
```

> Skip this step if you have not modified the Java/Gradle sources since the last build—the existing JARs in `launchers/*/build/libs` will be reused by Docker.

## 2. (Optional) Update participants list

If you want the connector to resolve the same participants as the MVD, edit:

```
C:\repos\dataspaces\EDC-Connector\deployment\assets\participants\participants.local.json
```

and add the DID/endpoint map that matches your environment.

## 3. Start the connector stack

```powershell
cd C:\repos\dataspaces\EDC-Connector\launchers
docker compose build controlplane
docker compose up -d
```

> `docker compose up -d` builds the remaining images if required and starts: controlplane, dataplane, identity-hub, postgres and vault.

## 4. Seed the local Identity Hub and Vault (first run only)

Run the helper script to create the launcher participant, publish its DID and store the required secrets in Vault:

```bash
cd C:\repos\dataspaces\EDC-Connector\launchers
bash seed-local.sh
```

The script is idempotent; re-run it whenever you reset the Docker volumes or rotate the API key. If you prefer to execute the steps manually, remember that Hashicorp Vault expects secrets under the `content` key:

```powershell
docker exec edc-vault sh -lc "\
  export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root; \
  vault kv put secret/did:web:localhost%3A8281-sts-client-secret content=change-me"
```

## 5. Verify the runtimes

Health checks:

```powershell
curl http://localhost:8280/api/check/health    # controlplane
curl http://localhost:8081/api/check/health    # dataplane
curl http://localhost:8380/api/check/health    # identity hub
```

Management API (mirrors the MVD shape). Always include the token `password`:

```powershell
curl -X POST http://localhost:8281/api/management/v3/assets `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer password" `
  -d '{
        "asset": { "properties": { "asset:prop:id": "asset-1" } },
        "dataAddress": { "type": "HttpData", "baseUrl": "https://httpbin.org/anything" }
      }'
```

If the request returns 201, the connector is ready to serve management calls like MVD/edc-scenario participants.

## 6. Stopping the stack

```powershell
cd C:\repos\dataspaces\EDC-Connector\launchers
docker compose down
```

The Docker volumes keep the Postgres data between runs. Use `docker compose down -v` if you want a clean database.

---

- [DPF Selector](dpf-selector/)
- [Generic](generic/)
- [STS server](sts-server/)
