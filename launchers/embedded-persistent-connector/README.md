# Minimal Connector + Control Plane

Runtime EDC empaquetado como fat-jar/shadow con control plane completo (negociación DSP, catálogo y management API), persistencia Postgres y trazas en fichero.

## Características Incluidas
- Boot + control plane `0.10.0` (management, catalog, DSP, control).
- Servidor HTTP con contextos dedicados (interno: `8181` health, `8281` management, `8282` DSP, `8283` control, `8284` catalog; Docker expone `8181/9081/9082/9083/9084`).
- Persistencia SQL para assets/policies/contracts usando Postgres (`connector-db`).
- Integración Hashicorp Vault + STS/Identity Hub configurable (por defecto apunta a los servicios i2cat vía `host.docker.internal`).
- Configuración externa (`configuration.properties`) y logging a fichero (`logging.properties`).

## Queda fuera por ahora
- Data Plane dedicado / transfer real (sólo control plane; añade tu propio dataplane para pruebas de transferencia).
- Seeds automáticos de assets/policies (usa la Management API o scripts).
- Credenciales DID/VC reales (placeholders listos para conectar con el escenario i2cat cuando estén emitidas).

## Build
```
./gradlew :launchers:embedded-persistent-connector:shadowJar
```
Resultado: `build/libs/minimal-connector.jar`.

> Usa este comando solo si necesitas el JAR localmente o quieres producir la imagen sin arrancar el contenedor. Para levantar Docker no hace falta: el propio `docker compose up -d --build` ejecuta Gradle por ti. La primera build dentro de Docker tarda ~2 minutos mientras Gradle descarga dependencias; verás un mensaje informativo para confirmar que sigue trabajando.

## Ejecutar en Host
1. Arranca Postgres con el mismo compose (deja la base escuchando en `localhost:5532`):
	```
	docker compose up -d connector-db
	```
2. (Opcional) Ajusta el callback DSP si no usas el valor por defecto:
	```
	export EDC_DSP_CALLBACK_ADDRESS=http://localhost:8282/api/dsp
	```
	(puedes pasar la propiedad como `-Dedc.dsp.callback.address=...` en el paso siguiente).
3. Crea la carpeta de logs la primera vez:
	```
	mkdir -p launchers/embedded-persistent-connector/logs
	```
4. Ejecuta el runtime:
	```
	java -jar launchers/embedded-persistent-connector/build/libs/minimal-connector.jar \
	  -Dedc.fs.config=launchers/embedded-persistent-connector/configuration.properties \
	  -Djava.util.logging.config.file=launchers/embedded-persistent-connector/logging.properties
	```
5. Comprueba endpoints básicos:
	```
	curl http://localhost:8181/api/health
	curl -H "x-api-key: edc-dev" http://localhost:8281/api/management/v3/assets
	```

## Docker / Compose
El `docker-compose.yml` lanza dos servicios:
- `connector-db`: Postgres 15 con credenciales `connector/connector` y base `minimal_connector` (volumen `connector_db_data`).
- `connector`: runtime EDC que compila el jar en build y se conecta al Postgres anterior.

### Primera vez (build + run)
```
docker compose up -d --build
```
- Compila la imagen, arranca Postgres y levanta el conector con la configuración por defecto.
- La fase Gradle tarda ~2 minutos la primera vez; se muestra un mensaje informativo para evitar la sensación de bloqueo.
- Los logs del conector aparecen en `launchers/embedded-persistent-connector/logs/` (montado en `/app/logs`).
- El runtime usa las credenciales de Vault/STS del escenario i2cat (`host.docker.internal` apunta al host desde Docker Desktop). Asegúrate de tener ese stack arriba o ajusta `EDC_VAULT_*`/`EDC_IAM_*` en `docker-compose.yml`.

Verifica el endpoint de health:
```
curl http://localhost:8181/api/health
```
Management API (clave `edc-dev`):
```
curl -H "x-api-key: edc-dev" http://localhost:9081/api/management/v3/assets
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
- Reiniciar solo la base: `docker compose restart connector-db`

La raíz incluye `.dockerignore` para reducir el contexto de build.

## Configuración
`configuration.properties` declara los contextos HTTP, la conexión Postgres y placeholders de identidad.

Valores relevantes:
- API key por defecto: `edc-dev` (`web.http.management.*` y `web.http.catalog.*`).
- Postgres local: `jdbc:postgresql://localhost:5532/minimal_connector` (en Docker se sobreescribe a `connector-db`).
- Callback DSP y selectors: `http://localhost:8282/api/dsp` y `http://localhost:8283/api/control/v1/dataplanes` (en Docker se mapean a `http://localhost:9082/...` y `http://localhost:9083/...`; ajusta si cambias puertos o nombre de host).
- Integración i2cat: `edc.vault.hashicorp.*` y `edc.iam.sts.*` apuntan a los puertos expuestos por su escenario Docker (cambia si ejecutas otro Vault/STS o si no necesitas identidad todavía).
- Identidad: el fichero mantiene un DID placeholder (`did:web:minimal-connector.local`) pero el `docker-compose.yml` lo sobreescribe con `did:web:provider-identityhub%3A7093` para reutilizar las credenciales ya sembradas en el vault i2cat. Cuando dispongas de tu propio DID/VC basta con exportar `EDC_PARTICIPANT_ID`, `EDC_IAM_ISSUER_ID` y los alias del vault/STS correspondiente.

Puedes sobrescribir cualquier clave:
- En host: `-Dclave=valor` en la línea de `java -jar`.
- En Docker: variables de entorno dentro de `docker-compose.yml` (ya hay un bloque `environment` con las más habituales).

## Integración con el escenario i2cat
1. Arranca `edc-scenario-main` y ejecuta `./seed.sh` para registrar proveedor⇔consumidor.
2. Construye/levanta este runtime: `docker compose up -d --build` (la primera vez tardará ~3 min porque Gradle compila el jar).
3. Comprueba que el conector queda listo:
	 ```
	 curl http://localhost:8181/api/health
	 curl -H "x-api-key: edc-dev" http://localhost:9081/api/management/v3/assets
	 ```
	 Deberías ver `Runtime ... ready` en los logs de Docker y la Management API devolverá una lista vacía si aún no tienes assets.
4. Comunicación con el stack i2cat:
	 - El vault y el STS se resuelven vía `host.docker.internal:{8400,8582}` desde el contenedor `connector` (el compose ya expone esas URLs).
	 - El DSP de i2cat es alcanzable en `http://localhost:8282/api/dsp`. Cuando emitas tus credenciales, podrás lanzar un `catalog` con:
		 ```
			 curl -H "x-api-key: edc-dev" -H "Content-Type: application/json" \
				 -d '{
							"@context": {"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
							"@type":"CatalogRequest",
							"counterPartyAddress":"http://host.docker.internal:8282/api/dsp",
							"counterPartyId":"did:web:provider-identityhub%3A7093",
							"protocol":"dataspace-protocol-http"
						}' \
			 http://localhost:9081/api/management/v3/catalog/request
		 ```
		 Mientras no exista un VC emitido recibirás un `401/403` desde el proveedor; una vez que el Identity Hub te firme uno, el flujo continuará y obtendrás el catálogo remoto.

### Registrar un DID propio cuando esté disponible
Si quieres preparar todos los artefactos antes de tener el VC real:
- **Vault**: guarda tu clave privada en Hashicorp (alias libre, por ejemplo `did:web:minimal-connector.local#key-1`).
	```
	curl -X POST http://localhost:8400/v1/secret/data/did:web:minimal-connector.local#key-1 \
			 -H "X-Vault-Token: root" \
			 -H "Content-Type: application/json" \
			 -d '{"data":{"privateKeyPem":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"}}'
	```
	Puedes generar un par EC (`secp256r1`) con `openssl ecparam -name prime256v1 -genkey -noout -out key.pem`.
- **Identity Hub**: registra el participante en el hub proveedor para que el resto de agentes reconozcan tu endpoint DSP.
	```
	API_KEY="c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo="
	jq -n --arg dsp "http://host.docker.internal:9082/api/dsp" \
				--arg did "did:web:minimal-connector.local" '{
				"roles":[],
				"serviceEndpoints":[{"type":"ProtocolEndpoint","serviceEndpoint":$dsp,"id":"minimal-dsp"}],
				"active":true,
				"participantId":$did,
				"did":$did,
				"key":{
						"keyId":"minimal-connector-key-1",
						"privateKeyAlias":"did:web:minimal-connector.local#key-1",
						"keyGeneratorParams":{"algorithm":"EC"}
				}
			}' | \
	curl -sS -X POST http://localhost:7091/api/identity/v1alpha/participants/ \
			 -H "Content-Type: application/json" -H "x-api-key: $API_KEY" -d @-
	```
- **Runtime**: sobrescribe `EDC_PARTICIPANT_ID`, `EDC_IAM_ISSUER_ID`, `EDC_IAM_STS_*` y los alias del vault en `docker-compose.yml` (o vía variables de entorno) y vuelve a ejecutar `docker compose up -d --build`.

## Publicar un asset sin restricciones (no policy)
La Management API v3 acepta JSON-LD. Estos tres pasos crean un asset HTTP, la policy “allow all” y el contract definition asociado:
```bash
curl -sS -X POST http://localhost:9081/api/management/v3/assets \
	-H "x-api-key: edc-dev" -H "Content-Type: application/json" \
	-d '{
				"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
				"@type":"Asset",
				"@id":"asset-json",
				"properties":{"edc:title":"demo-user-list"},
				"dataAddress":{
					"@type":"DataAddress",
					"type":"HttpData",
					"baseUrl":"https://jsonplaceholder.typicode.com/users"
				}
			}'

curl -sS -X POST http://localhost:9081/api/management/v3/policydefinitions \
	-H "x-api-key: edc-dev" -H "Content-Type: application/json" \
	-d '{
				"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
				"@type":"PolicyDefinition",
				"@id":"allow-all",
				"policy":{
					"@type":"Policy",
					"permissions":[{"edc:action":{"type":"USE"}}]
				}
			}'

curl -sS -X POST http://localhost:9081/api/management/v3/contractdefinitions \
	-H "x-api-key: edc-dev" -H "Content-Type: application/json" \
	-d '{
				"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
				"@type":"ContractDefinition",
				"@id":"contract-allow-all",
				"accessPolicyId":"allow-all",
				"contractPolicyId":"allow-all",
				"assetsSelector":[{"operandLeft":"https://w3id.org/edc/v0.0.1/ns/id","operator":"=","operandRight":"asset-json"}]
			}'
```
El asset queda visible en `http://localhost:9084/api/catalog` y, una vez emitas tu VC, podrá ser negociado por los conectores del escenario i2cat.

## Dónde se persiste la información
- **Base de datos**: Postgres (`connector-db`) contiene las tablas `edc_asset`, `edc_data_address`, `edc_policy`, `edc_contract_definition`, etc. Puedes inspeccionarlas con:
	```
	docker exec -it minimal-connector-connector-db psql -U connector -d minimal_connector -c "\dt"
	docker exec -it minimal-connector-connector-db psql -U connector -d minimal_connector -c "select * from edc_asset;"
	```
- **Vault**: cualquier alias configurado en `EDC_IAM_STS_*` o `edc.dataplane.transfer.*` se resuelve en `secret/<alias>` dentro del vault i2cat (port 8400). Usa `vault kv get secret/<alias>` para verificar que tu clave está guardada.
- **Logs**: mappeados a `launchers/embedded-persistent-connector/logs/` en el host para facilitar el troubleshooting.

## Siguientes Pasos (opcionales)
- Añadir un Data Plane propio (o enlazar con el existente en i2cat) y registrar la instancia vía Control API.
- Publicar assets/policies con la Management API (`x-api-key: edc-dev`) y verificar que aparecen en su catálogo.
- Integrar un flujo de emisión de credenciales DID real y guardar secretos en Vault.

---
Basado en los samples oficiales de EDC (`basic-01`, `basic-02`).
