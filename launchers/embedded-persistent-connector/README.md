# Minimal Connector + Health Endpoint

Esta versión simplificada replica los samples `basic-01` y `basic-02`:
un runtime EDC básico con un único servidor HTTP y un endpoint de health.

## Características Incluídas
- Boot + runtime/core mínimo.
- Servidor HTTP (Jetty + Jersey) en `8181` con path `/api`.
- Endpoint `GET /api/health` que responde `{"response":"I'm alive!"}`.
- Configuración externa vía `configuration.properties`.

## Excluido para mantenerlo mínimo
- Data Plane dedicado / transfer, negociación, catálogo, DSP, management APIs.
- Persistencia externa (todo en memoria).
- Vault, Identity Hub, autenticación.

## Build
```
./gradlew :launchers:embedded-persistent-connector:shadowJar
```
Resultado: `build/libs/minimal-connector.jar`.

## Ejecutar en Host
```
java -jar launchers/embedded-persistent-connector/build/libs/minimal-connector.jar -Dedc.fs.config=launchers/embedded-persistent-connector/configuration.properties
```

Probar health:
```
curl http://localhost:8181/api/health
```

## Docker / Compose
El `docker-compose.yml` declara `name: minimal-connector` para que el contenedor se denomine `minimal-connector-connector-1`.

```
docker compose up --build
```
Luego:
```
curl http://localhost:8181/api/health
```

Logs esperados: mensaje indicando recepción de la petición de health.

Si ves advertencia de "orphan containers" (por restos anteriores):
```
docker compose down --remove-orphans
```

La raíz incluye `.dockerignore` para reducir el contexto de build.

## Configuración
Editar `configuration.properties` para cambiar puerto o path.

## Siguientes Pasos (opcionales)
- Añadir APIs de gestión: incluir dependencias `management-api` y definir otro contexto (p.e. `web.http.management.*`).
- Añadir protocolo DSP para negociación/transfer.
- Añadir persistencia (SQL / Vault) si se requieren datos duraderos.

---
Basado en los samples oficiales de EDC (`basic-01`, `basic-02`).
