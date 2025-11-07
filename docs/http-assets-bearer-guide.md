# Guía: Assets HTTP con Bearer Token (stack local)

Esta guía muestra cómo publicar y consumir un asset `HttpData` protegido con Bearer Token usando el stack local (controlplane + dataplane + Vault) de este repositorio.

## Índice
1. Objetivo y alcance
2. Prerrequisitos
3. Opciones de autenticación: `authCode` vs `secretName`
4. Registro del asset (modo `authCode` - solo pruebas)
5. Registro del asset con secreto en Vault (`secretName`)
6. Propiedades del `dataAddress`
7. Cómo funciona `proxyPath`
8. Consumir el asset (EDR y llamadas al dataplane)
9. Flujo resumido
10. Buenas prácticas
11. Scripts relacionados
12. Troubleshooting rápido
13. Referencias

---

## 1. Objetivo y alcance

El conector expone datos vía assets `HttpData` y el dataplane actúa como proxy. Para APIs que requieren Bearer Token (o API Key similar) puedes:

| Método | Uso | Riesgos | Cuándo elegir |
|--------|-----|---------|---------------|
| `authCode` | Valor literal incrustado en el asset | Exposición del token si se exporta el asset, requiere PUT para rotar | Pruebas rápidas, tokens temporales |
| `secretName` | Referencia a secreto almacenado en Vault | El valor no aparece en la definición pública del asset, rotación sin tocar asset | Entornos reales y rotaciones frecuentes |

## 2. Prerrequisitos
* Stack levantado: `docker compose up -d --build` en `launchers/`.
* Vault dev accesible: `http://localhost:9200` (token: `root`).
* Token de gestión del controlplane: `password` (si no lo cambiaste en `configuration.properties`).
* `jq` y `curl` instalados para ejemplos.

## 3. Opciones de autenticación
Resumen rápido:

```text
authCode   -> dataAddress incluye el valor (p.ej. "Bearer eyJ...")
secretName -> dataAddress referencia nombre del secreto; el dataplane lo lee de Vault y lo inyecta
```

Rotación:
* `authCode`: actualizar vía `PUT /assets/{id}/dataaddress`.
* `secretName`: ejecutar script/llamada Vault (no se modifica el asset).

## 4. Registro con token incrustado (`authCode`) [solo pruebas]

Crea `asset-secure-endpoint.json`:

   ```json
   {
     "@context": {},
     "@id": "asset-secure-endpoint",
     "properties": {
       "edc:name": "Secure API asset",
       "edc:description": "Datos protegidos con bearer token",
       "edc:contenttype": "application/json"
     },
     "dataAddress": {
       "type": "HttpData",
       "baseUrl": "https://api.tu-dominio.com/recurso",
       "proxyMethod": "true",
       "proxyPath": "true",
       "proxyQueryParams": "true",
       "proxyBody": "true",
       "authKey": "Authorization",
       "authCode": "Bearer eyJhbGciOi..."
     }
   }
   ```

Registra el asset en la Management API:

   ```bash
      curl -X POST \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer password" \
         --data @asset-secure-endpoint.json \
         http://localhost:9281/api/management/v3/assets
   ```

Para renovar el token repite el `PUT` solo con el `dataAddress` (no hace falta reenviar `properties`):

   ```bash
      curl -X PUT \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer password" \
         --data '{
       "type": "HttpData",
       "baseUrl": "https://api.tu-dominio.com/recurso",
       "proxyMethod": "true",
       "proxyPath": "true",
       "proxyQueryParams": "true",
       "proxyBody": "true",
       "authKey": "Authorization",
       "authCode": "Bearer <nuevo-token>"
   }' \
   http://localhost:9281/api/management/v3/assets/asset-secure-endpoint/dataaddress
   ```

---

## 5. Registro con token en Vault (`secretName`) [recomendado]

Uso recomendado para entornos reales o tokens de larga duración.

1. Ajusta el `dataAddress` para usar `secretName` (sin prefijos):

   ```json
   "dataAddress": {
     "type": "HttpData",
     "baseUrl": "https://api.tu-dominio.com/recurso",
     "proxyMethod": "true",
     "proxyPath": "true",
     "proxyQueryParams": "true",
     "proxyBody": "true",
     "authKey": "Authorization",
     "secretName": "secure-api"
   }
   ```

2. Publica el asset como antes (`POST /management/v3/assets`).

Guarda el token en Vault (KV v2, campo `content`):

   ```bash
   export VAULT_ADDR=http://localhost:9200
   export VAULT_TOKEN=root   # token dev configurado en docker-compose

   # guardar o actualizar el token en la clave "content"
   vault kv put secret/secure-api content="Bearer eyJhbGciOi..."
   ```

   Alternativas:

   - **API HTTP directa**

   ```bash
   curl -X POST http://localhost:9200/v1/secret/data/secure-api \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"data":{"content":"Bearer eyJhbGciOi..."}}'
   ```

   - **Script helper (`store-vault-secret.sh`)**

   ```bash
   # requiere jq y curl instalados
   VAULT_ADDR=http://localhost:9200 \
   VAULT_TOKEN=root \
   SECRET_NAME=secure-api \
   SECRET_VALUE="Bearer eyJhbGciOi..." \
   ./store-vault-secret.sh
   ```

Revisar y rotar:

   ```bash
   vault kv get secret/secure-api          # ver valor actual
   vault kv put secret/secure-api content="Bearer <nuevo-token>"   # rotar
   ```

   El dataplane siempre utiliza la versión más reciente. No requiere reinicios ni actualizar el asset.

---

## 6. Propiedades del `dataAddress`

Todas las propiedades viven dentro de `dataAddress`. Tabla de las más comunes:

| Propiedad | Descripcion | Ejemplo util |
|-----------|-------------|--------------|
| `type` | Siempre `HttpData` para transferencias HTTP. | "type": "HttpData" |
| `baseUrl` | URL base del backend (sin `/data/<transferId>`). | "baseUrl": "https://api.circularpass.io/api/secure/v1" |
| `path` | Ruta fija concatenada cuando `proxyPath = "false"`. | "path": "/instances/did%3Aweb%3A..." |
| `method` | Metodo HTTP fijo (por defecto `GET`). | "method": "POST" |
| `proxyMethod` | "true" reutiliza el metodo usado por el consumidor. | "proxyMethod": "true" |
| `proxyPath` | "true" concatena al `baseUrl` todo lo que vaya tras `/api/public/`. | "proxyPath": "true" |
| `queryParams` | Parametros estaticos añadidos al backend. | "queryParams": "page=1&pageSize=10" |
| `proxyQueryParams` | Replica los parametros enviados por el consumidor. | "proxyQueryParams": "true" |
| `proxyBody` | "true" reenvia el body y `Content-Type` del consumidor. | "proxyBody": "true" |
| `contentType` | Cabecera fija cuando no proxificas el body. | "contentType": "application/json" |
| `authKey` | Cabecera donde se inyectara el secreto (Bearer, API key...). | "authKey": "Authorization" |
| `authCode` | Valor literal del header (solo pruebas). | "authCode": "Bearer eyJ..." |
| `secretName` | Nombre del secreto en Vault (sin `secret/`). | "secretName": "secure-api" |
| `header:<Nombre>` | Cabeceras adicionales fijas. | "header:Accept": "application/json" |
| `nonChunkedTransfer` | "true" desactiva chunking. | "nonChunkedTransfer": "true" |

### Notas clave

- Para rutas fijas deja `proxyPath = "false"` y define `baseUrl`/`path`.
- Para rutas dinamicas usa `proxyPath = "true"` y deja que el consumidor añada segmentos tras `/api/public/`.
- `authKey` sirve tanto para Bearer como para API keys; `secretName` funciona igual en ambos casos.
- `proxyBody = "true"` implica que el consumidor envia el cuerpo exacto al dataplane (ideal para `POST`).

### Combinaciones frecuentes (plantillas)

1. **GET fijo**
   ```json
   "dataAddress": {
     "type": "HttpData",
     "baseUrl": "https://api.circularpass.io/api/secure/v1/instances",
     "proxyPath": "false",
     "proxyMethod": "false",
     "proxyQueryParams": "false"
   }
   ```

2. **GET dinamico reutilizable**
   ```json
   "dataAddress": {
     "type": "HttpData",
     "baseUrl": "https://api.circularpass.io/api/secure/v1",
     "proxyPath": "true",
     "proxyMethod": "true",
     "proxyQueryParams": "true"
   }
   ```

3. **POST con secreto en Vault**
   ```json
   "dataAddress": {
     "type": "HttpData",
     "baseUrl": "https://api.tu-dominio.com/api/v2/oauth/login",
     "method": "POST",
     "proxyBody": "true",
     "contentType": "application/json",
     "authKey": "Authorization",
     "secretName": "secure-api"
   }
   ```

El consumidor invoca el dataplane con el token de la EDR y el body requerido por la API origen. El dataplane añade el header usando el secreto (Vault o `authCode`).

> Consejo: si tu API no acepta sufijos dinámicos, desactiva `proxyPath` o fija `path` con la ruta exacta.
## 7. Cómo funciona `proxyPath`

- El dataplane publica todo bajo `.../api/public/**`. Con `proxyPath = "true"` copia literalmente el tramo que vaya **despues de `/api/public/`** y lo concatena al `baseUrl`.
- Ejemplo dinamico: con `baseUrl = https://api.circularpass.io/api/secure/v1` y `proxyPath = "true"`, si el consumidor invoca  
  `GET .../api/public/data/<tpId>/instances/did%3A...`, el dataplane llamara a `https://api.circularpass.io/api/secure/v1/instances/did%3A...`.
- Ejemplo estatico: con `proxyPath = "false"` y `baseUrl = https://api.circularpass.io/api/secure/v1/instances`, cualquier llamada a `.../api/public/...` terminara en `https://api.circularpass.io/api/secure/v1/instances`. Usa este modo cuando tu backend expone una ruta fija (como en el ejemplo de CircularPass sin ruta dinamica).
- Si llamas al dataplane sin añadir nada tras `/api/public/` y tienes `proxyPath = "true"`, el sufijo sera exactamente lo que hayas enviado (p.ej. `data/<tpId>`). Si la API origen no admite ese sufijo, desactiva `proxyPath` o construye la ruta completa en la llamada del consumidor.

---

## 8. Consumir el asset tras la transferencia

1. El consumidor lanza la transferencia (`POST /management/v3/transferprocesses`).
2. Una vez en estado `COMPLETED`, recupera la EDR:

   ```bash
   curl -H "Authorization: Bearer password" \
      http://localhost:9281/api/management/v3/edrs/<transferProcessId>/dataaddress
   ```

   Campos clave:
   - `endpoint`: URL base del dataplane del proveedor (`http://localhost:9290/api/public`).
   - `authorization`: token temporal que el consumidor debe usar.

Para peticiones PULL suele usarse `GET {endpoint}/data/{tpId}`, pero en este stack puede omitirse y llamar solo a `{endpoint}`.

   ```bash
   curl -X GET \
      http://localhost:9290/api/public \
      -H "Authorization: <token-EDR>"
   ```

   El dataplane valida el token de la EDR y realiza la llamada al backend usando `baseUrl` (y `path`/`proxyPath` segun corresponda).

4. Para listar transferencias recientes ordenadas:

   ```bash
   curl -H "Authorization: Bearer password" \
      "http://localhost:9281/api/management/v3/transferprocesses?sort=createdAt&sortOrder=DESC&limit=5"
   ```

   Tambien puedes usar `POST /management/v3/transferprocesses/request` con un `QuerySpec` que incluya `sortField` y `sortOrder`.

---

## 9. Flujo resumido

1. Publicas el asset `HttpData`.
2. Creas la `Policy` y la `ContractDefinition` para exponerlo en el catalogo.
3. El consumidor negocia y recibe la EDR.
4. El consumidor llama al dataplane con el token de la EDR.
5. El dataplane injerta el bearer del Vault en la llamada al backend y retorna la respuesta.

---

## 10. Buenas prácticas

- Limita `authCode` a pruebas. En producción usa `secretName`.
- Automatiza la rotación (`vault kv put secret/secure-api content="Bearer <nuevo>"`).
- Ajusta `proxyPath`/`proxyMethod` según comportamiento del backend.
- Logs útiles: `docker compose logs -f dataplane` y `docker compose logs -f controlplane`.
- Tras cambiar el asset realiza una nueva transferencia (las anteriores no cambian su EDR).
- Verifica el secreto rápido: `curl -H X-Vault-Token:root http://localhost:9200/v1/secret/data/secure-api | jq -r '.data.data.content'`.

---

## 11. Scripts relacionados

| Script | Propósito | Uso mínimo |
|--------|-----------|------------|
| `launchers/store-vault-secret.sh` | Guardar/rotar secreto en Vault bajo `content` | `SECRET_NAME=secure-api SECRET_VALUE="Bearer X" ./store-vault-secret.sh` |
| `launchers/create-circularpass.assets.sh` | Crear asset + policy + contract definition para API con secreto | `./create-circularpass.assets.sh` |
| `launchers/seed-local.sh` | Sembrar Vault (claves, superuser) y registrar participante en Hub | `./seed-local.sh` |

## 12. Troubleshooting rápido

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| 401 al llamar dataplane | EDR expirada o token incorrecto | Obtener EDR nuevamente tras transferencia COMPLETED |
| 404 en dataplane | `proxyPath=true` pero ruta vacía/no válida | Ajustar llamada o poner `proxyPath=false` y definir `path` |
| Backend 401 pese a EDR válida | Secreto ausente o mal formateado (sin `Bearer `) | Revisar Vault y rotar guardando prefijo `Bearer ` |
| `Secret not found` en logs | `secretName` no coincide con clave en Vault | Verificar nombre y volver a guardar con script |
| PUT dataaddress devuelve 404 | ID asset incorrecto | Revisar `@id` y endpoint `.../assets/{id}/dataaddress` |

## 13. Referencias

- `extensions/data-plane/data-plane-http/.../BaseCommonHttpParamsDecorator.java`
- `extensions/data-plane/data-plane-http/.../BaseSourceHttpParamsDecorator.java`
- `docs/technical-overview.md`

---

## 14. Seed rápido de asset de ejemplo (CircularPass)

El script `./create-circularpass.assets.sh` registra automáticamente:

- el asset `HttpData` apuntando a `https://api.circularpass.io/api/secure/v1/instances`,
- la policy `require-membership`,
- y la `ContractDefinition` que vincula ambos.

Variables útiles (opcional cambiar antes de ejecutar):

| Variable           | Valor por defecto                                      |
|--------------------|--------------------------------------------------------|
| `BASE_URL`         | `http://localhost:9281`                                |
| `MGMT_TOKEN`       | `password`                                             |
| `ASSET_BASE_URL`   | `https://api.circularpass.io/api/secure/v1/instances`  |
| `SECRET_NAME`      | `secure-api`                                           |
| `ASSET_ID`         | `asset-secure-endpoint`                                |
| `POLICY_ID`        | `require-membership`                                   |

Uso básico:

```bash
BASE_URL=http://localhost:9281 \
MGMT_TOKEN=password \
./create-circularpass.assets.sh
```

El script elimina versiones previas y deja el conector listo para probar transferencia + consumo con bearer en Vault.

