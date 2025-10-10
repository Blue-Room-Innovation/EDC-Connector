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

> Usa este comando solo si necesitas el JAR localmente o quieres producir la imagen sin arrancar el contenedor. Para levantar Docker no hace falta: el propio `docker compose up -d --build` ejecuta Gradle por ti. La primera build dentro de Docker tarda ~2 minutos mientras Gradle descarga dependencias; verás un mensaje informativo para confirmar que sigue trabajando.

## Ejecutar en Host
Crear carpeta para logs (solo primera vez):
```
mkdir -p launchers/embedded-persistent-connector/logs
```

Ejecutar:
```
java -jar launchers/embedded-persistent-connector/build/libs/minimal-connector.jar -Dedc.fs.config=launchers/embedded-persistent-connector/configuration.properties -Djava.util.logging.config.file=launchers/embedded-persistent-connector/logging.properties
```

Probar health:
```
curl http://localhost:8181/api/health
```

## Docker / Compose
El `docker-compose.yml` declara `name: minimal-connector` para que el contenedor se denomine `minimal-connector-connector-1`.

### Primera vez (build + run)
```
docker compose up -d --build
```
- Este comando construye la imagen **y** deja el contenedor corriendo. La parte de build tarda ~2 minutos la primera vez porque Gradle descarga dependencias; verás un mensaje indicando que sigue compilando.
- Usar `--build` es suficiente para generar el artefacto dentro de la imagen, no necesitas ejecutar Gradle manualmente.
- Los logs se guardan en `launchers/embedded-persistent-connector/logs/` del host (carpeta montada en `/app/logs`).

Verifica el endpoint de health:
```
curl http://localhost:8181/api/health
```

### Ejecuciones posteriores (sin rebuild)
```
docker compose up -d
```
Gradle ya no se lanza y el arranque es casi inmediato. Solo vuelve a usar `--build` si cambias código o configuración y necesitas regenerar la imagen.

### Otros comandos útiles
- Ver logs: `docker compose logs -f`
- Detener: `docker compose down`
- Limpiar contenedores huérfanos de ejecuciones previas: `docker compose down --remove-orphans`
- Limpiar y recrear la carpeta de logs: `rm -rf logs && mkdir logs`

La raíz incluye `.dockerignore` para reducir el contexto de build.

## Configuración
Editar `configuration.properties` para cambiar puerto o path.

## Siguientes Pasos (opcionales)
- Añadir APIs de gestión: incluir dependencias `management-api` y definir otro contexto (p.e. `web.http.management.*`).
- Añadir protocolo DSP para negociación/transfer.
- Añadir persistencia (SQL / Vault) si se requieren datos duraderos.

---
Basado en los samples oficiales de EDC (`basic-01`, `basic-02`).
