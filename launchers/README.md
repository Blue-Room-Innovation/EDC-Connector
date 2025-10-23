# Launchers

Este directorio contiene los “launchers” ejecutables del conector: Control Plane, Data Plane e Identity Hub. A continuación tienes una guía completa en español para construir los artefactos, arrancar la pila Docker, sembrar (seed) secretos/identidad y verificar que todo funciona. Al final se incluye una descripción de los componentes y de la arquitectura.

## Requisitos

- Docker Desktop (o Docker Engine) con Compose v2.
- JDK 17 o superior para ejecutar el wrapper de Gradle (`./gradlew` / `.\gradlew`).
- Bash (Git Bash/WSL) y `curl` en el PATH para ejecutar `seed-local.sh`.
- Puertos libres en el host: `9280-9285`, `9181`, `9290`, `9480-9486`, `9200`, `9432`.
- Material de identidad: claves DID y credenciales verificables en `deployment/assets/` (los ficheros que vienen son de ejemplo; sustituye por los tuyos si procede).

## 1) Construir los JAR “sombreados” (shadow)

Cada Dockerfile copia un JAR sombreado desde `launchers/<runtime>/build/libs`. Genera/actualiza estos artefactos cuando cambies código o dependencias:

```bash
./gradlew -Ppersistence=true :launchers:controlplane:shadowJar :launchers:dataplane:shadowJar :launchers:identity-hub:shadowJar
```


La propiedad `-Ppersistence=true` incluye las extensiones de PostgreSQL y HashiCorp Vault usadas por la configuración que se entrega. Omitirla solo tiene sentido si has desactivado conscientemente esos servicios.

> Consejo: Gradle hará “up-to-date” si nada cambió, así que puedes ejecutar este paso siempre sin pagar todo el coste del build.

## 2) Revisar identidades, credenciales y participantes

La pila de Compose monta la configuración y el material de credenciales desde el repo. Revisa y alinea:

- `launchers/controlplane/configuration.properties` - DID del conector (`edc.participant.id`), callback DSP, credenciales de Vault/DB, token de gestión, etc.
- `launchers/dataplane/configuration.properties` - puertos del dataplane, endpoint de registro del selector (`edc.dpf.selector.url`), alias de claves para firmar/verificar tokens de proxy.
- `launchers/identity-hub/configuration.properties` - DID del hub, API key de superusuario, endpoints de Vault/DB y rutas a credenciales.
- `deployment/assets/public.pem` / `private.pem` y `deployment/assets/credentials/*` - par de claves DID y VCs.
- `deployment/assets/participants/participants.local.json` - (opcional) mapa DID -> endpoint a resolver por el Control Plane.

Todas las piezas deben ser consistentes: el DID configurado en controlplane, dataplane e identity-hub debe corresponder con las claves/VCs montadas. Si no, tendrás reinicios/errores de validación.

## 3) Arrancar con Docker Compose (recomendado)

Desde la carpeta `launchers/` construye las imágenes y arranca servicios:

```bash
cd launchers
docker compose build
docker compose up -d
```

Si falla `docker compose build` por falta de JARs, repite el paso 1. La pila levanta: controlplane, dataplane, identity-hub, PostgreSQL y Vault, todos en la misma red para resolverse por nombre de servicio (`controlplane`, `dataplane`, `identity-hub`, `postgres`, `vault`).

> Si solo cambiaste ficheros de configuración, puedes usar `docker compose up -d --build` para reconstruir sin pasar por Gradle manualmente.

## 4) (Opcional) Construir imágenes con Gradle (`dockerize`)

Este repo define una tarea `dockerize` por launcher (se crea automáticamente si hay `shadowJar` y `src/main/docker/Dockerfile`, ver `build.gradle.kts: subprojects { afterEvaluate { ... dockerize ... } }`). Sirve para preconstruir imágenes desde Gradle y etiquetarlas con `latest` y la versión del proyecto.

Comandos típicos:

```bash
./gradlew -Ppersistence=true \
  :launchers:controlplane:dockerize \
  :launchers:dataplane:dockerize \
  :launchers:identity-hub:dockerize
```

Si necesitas construir para otra plataforma (por ejemplo, `linux/amd64`):

```bash
./gradlew :launchers:controlplane:dockerize -Dplatform=linux/amd64
```

Importante sobre las etiquetas: `dockerize` genera imágenes `controlplane:latest`, `dataplane:latest`, `identity-hub:latest`. El `docker-compose.yml` usa `edc-controlplane:latest`, `edc-dataplane:latest`, `edc-identity-hub:latest`. Opciones:

- Retag antes de levantar Compose:

```bash
docker tag controlplane:latest edc-controlplane:latest
docker tag dataplane:latest edc-dataplane:latest
docker tag identity-hub:latest edc-identity-hub:latest
```

- O simplemente usa `docker compose up -d --build` y deja que Compose construya/etiquete con los nombres esperados. En la práctica, usar Compose (paso 3) es suficiente y no necesitas `dockerize` salvo que quieras publicar/gestionar imágenes con Gradle.

## 5) Sembrar Vault e Identity Hub (primer arranque o tras limpiar volúmenes)

Cuando los contenedores estén en marcha, ejecuta el script de seed para almacenar secretos en Vault y registrar el participante en el Identity Hub:

```bash
cd launchers
bash seed-local.sh
```

El script:

- guarda la API key de superusuario (`SUPERUSER_API_KEY`) y el secreto de STS (`STS_SECRET_VALUE`) en el contenedor `edc-vault` bajo claves KV con el campo `content`;
- registra el participante en el Hub, lo activa y publica su DID.

Variables que puedes sobreescribir antes de ejecutar:

```bash
export PARTICIPANT_DID="did:web:host.docker.internal%3A9483"
export SUPERUSER_API_KEY="base64.superuser.key"
export STS_SECRET_VALUE="change-me"
bash seed-local.sh
```

Repite el seed si rotas credenciales o tras `docker compose down -v`.

## 6) Verificación rápida

Comprueba salud de servicios:

```bash
docker compose ps
curl http://localhost:9280/api/check/health     # controlplane
curl http://localhost:9181/api/check/health     # dataplane
curl http://localhost:9480/api/check/health     # identity hub
```

Prueba la API de gestión (token `password`):

```bash
curl -X POST http://localhost:9281/api/management/v3/assets \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer password" \
  -d '{
        "asset": { "properties": { "asset:prop:id": "asset-1" } },
        "dataAddress": { "type": "HttpData", "baseUrl": "https://httpbin.org/anything" }
      }'
```

Si devuelve `201`, el controlplane está listo para llamadas de gestión.

## 7) Parada y limpieza

```bash
docker compose down          # para contenedores y conserva volúmenes
docker compose down -v       # para y borra datos de PostgreSQL/Vault
```

Usa `docker compose logs -f <servicio>` para diagnosticar arranques. Si un contenedor falla por "No such file" al lanzar el JAR, reconstruye los shadow JARs (paso 1).

---

## Componentes y Arquitectura

- Control Plane
  - Orquesta negociación de contratos (DSP), catálogo, políticas y transferencias.
  - Expone APIs: base/health (`9280`), gestión (`9281`), protocolo DSP (`9282`), control/selector (`9283`), catálogo (`9284`), versión (`9285`). Mapeo host:contenedor según `docker-compose.yml`.
  - Usa PostgreSQL para persistencia y Vault para secretos.

- Data Plane
  - Proxy sin estado que mueve datos entre origen y destino durante una transferencia autorizada.
  - APIs: REST interna (`9181->8080`) y pública de transferencia (`9290->8290`). Se registra en el Control Plane vía Data Plane Selector (`edc.dpf.selector.url`).

- Identity Hub
  - Gestiona DIDs, credenciales verificables y STS (Secure Token Service) necesarios para autenticación entre participantes y servicios.
  - APIs publicadas en `9480-9486` (base, credentials, identity, did, version, sts).
  - Usa PostgreSQL y Vault; espera claves/VCs bajo `deployment/assets/`.

- Vault y PostgreSQL
  - Vault (modo dev) almacena secretos; el script de seed escribe bajo `secret/<clave>` con valor en el campo `content`.
  - PostgreSQL persiste estados del conector/hub/dataplane. Volumen `pgdata` mantiene datos entre arranques.

### Flujo de arranque

1) Arrancan `postgres` (hasta healthy) y `vault`.
2) `controlplane` inicia y queda healthy (requiere DB/Vault).
3) `dataplane` arranca y se registra en el selector del controlplane.
4) `identity-hub` arranca, tras lo cual ejecutas `seed-local.sh` para registrar el participante y publicar su DID.

### Puertos relevantes (host -> contenedor)

- Control Plane: `9280->8280`, `9281->8281`, `9282->8282`, `9283->8283`, `9284->8284`, `9285->8285`
- Data Plane: `9181->8080`, `9290->8290`
- Identity Hub: `9480->8080`, `9481->8281`, `9482->8282`, `9483->8283`, `9485->8285`, `9486->8286`
- Vault: `9200->8200` | PostgreSQL: `9432->5432`

---

- [DPF Selector](dpf-selector/)
- [Generic](generic/)
- [STS server](sts-server/)

---

## Interoperar con i2cat (edc-scenario-main)

Objetivo: desde este EDC-Connector (como consumer) solicitar el catálogo al provider del escenario i2cat sin modificar su compose.

1) Arranca este stack y ejecuta el seed local
- Sigue los pasos 1–6 de este README.

2) (Opcional) Registrar este conector en el Identity Hub del provider i2cat
- No es estrictamente necesario para pedir catálogo si el provider puede resolver tu DID `did:web:host.docker.internal%3A9483` y alcanzar tus endpoints (DSP y CredentialService) desde su red.
- Úsalo sólo si recibes errores del tipo "participante desconocido" o si el provider no consigue localizar tu CredentialService durante la negociación.
- Ejecuta desde `launchers/`:
  - `bash seed-i2cat.sh`
- Variables opcionales:
  - `I2CAT_PROVIDER_IDENTITY_HOST` (por defecto `localhost`)
  - `I2CAT_PROVIDER_IDENTITY_PORT` (por defecto `7091`)
  - `SUPERUSER_API_KEY` (por defecto la de demo)
  - `PARTICIPANT_DID` (por defecto `did:web:host.docker.internal%3A9483`)
- El script registra tu `ProtocolEndpoint` (`http://host.docker.internal:9282/api/dsp`) y tu `CredentialService` (`http://host.docker.internal:9481/...`).

3) Solicita el catálogo del provider i2cat
- Ejecuta:
  - `bash catalog-request.sh`
- Variables opcionales:
  - `PROVIDER_DSP_URL` (por defecto `http://localhost:8282/api/dsp`)
  - `EDC_MGMT_URL` (por defecto `http://localhost:9281`) y `EDC_MGMT_TOKEN` (por defecto `password`).
- Si el provider tiene políticas que requieren VCs específicas, reemplaza tus credenciales en `deployment/assets/credentials/` por VCs emitidas por su issuer.

Notas
- En Windows/Mac, `host.docker.internal` es resolvible desde los contenedores de i2cat, por lo que el provider alcanzará tus endpoints sin tocar su compose.
- Si ves el dataplane `unhealthy`, ya se ha corregido el healthcheck para apuntar a `/api/check/health` en la imagen.
