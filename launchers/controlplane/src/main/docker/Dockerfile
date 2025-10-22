# Base runtime image (Temurin JRE on Alpine) used to run the shaded launcher JAR.
# Alpine keeps image size small; Temurin provides the Java 23 runtime shipped by the project.
# The "-buster" suffix ensures package manager availability for installing runtime helpers.
FROM eclipse-temurin:23.0.2_7-jre-alpine

# Build-time args let callers inject additional JVM flags or point to a different launcher JAR.
# These become environment variables later so the entrypoint can reuse them.
ARG JVM_ARGS=""
ARG JAR

# Add curl so Docker's HEALTHCHECK can probe the runtime over HTTP.
RUN apk --no-cache add curl

WORKDIR /app


# Drop the shaded connector JAR into the working directory.
COPY ${JAR} edc-controlplane.jar

# Control plane exposes multiple APIs; 8280 is the base HTTP endpoint used for health and REST APIs.
EXPOSE 8280

# Inform the runtime which port/path to bind the default (management) API to.
# These match the values defined in configuration.properties and the docker-compose port mapping.
ENV WEB_HTTP_PORT="8280"
ENV WEB_HTTP_PATH="/api"

# Container-level liveness probe hitting the REST health endpoint.
HEALTHCHECK --interval=5s --timeout=5s --retries=10 CMD curl --fail http://localhost:8280/api/check/health

# Use "exec" for graceful termination (SIGINT) to reach JVM.
# ARG can not be used in ENTRYPOINT so storing value in an ENV variable
# Persist the optional JVM args as an environment variable so the entrypoint can expand them.
ENV ENV_JVM_ARGS=$JVM_ARGS
# need the sh -c syntax so that the SECRETS variable gets expanded
# use the "exec" syntax so that SIGINT reaches the JVM -> graceful termination
CMD ["sh", "-c", "exec java -Dedc.fs.config=/app/configuration.properties -Dedc.vault.secrets=\"${SECRETS}\" -Djava.util.logging.config.file=/app/logging.properties -Djava.security.egd=file:/dev/urandom -jar edc-controlplane.jar --log-level=debug"]



