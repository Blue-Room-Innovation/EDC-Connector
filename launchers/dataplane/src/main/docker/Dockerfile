# Base runtime image for the dataplane launcher (Temurin Java 23 on Alpine).
# Keeping the image Alpine-based minimizes footprint while still allowing curl installs.
FROM eclipse-temurin:23.0.2_7-jre-alpine

# Build-time customization hooks for JVM flags and the shaded dataplane JAR path.
ARG JVM_ARGS=""
ARG JAR

# Curl is required for the container health check to poll the dataplane HTTP endpoint.
RUN apk --no-cache add curl

WORKDIR /app


# Copy the shaded dataplane launcher JAR into the working directory.
COPY ${JAR} edc-dataplane.jar

# Default dataplane REST API listens on 8080 inside the container.
EXPOSE 8080

# Environment configuration informing the runtime which port/path to expose internally.
# docker-compose maps host port 8081 -> container port 8080, so the internal port stays at 8080.
# Path uses "/api" to align with configuration.properties and the documented REST shape.
ENV WEB_HTTP_PORT="8080"
ENV WEB_HTTP_PATH="/api"

# Health probe hitting the dataplane runtime's REST endpoint.
HEALTHCHECK --interval=5s --timeout=5s --retries=10 CMD curl --fail http://localhost:8080/check/health

# Use "exec" for graceful termination (SIGINT) to reach JVM.
# ARG can not be used in ENTRYPOINT so storing value in an ENV variable
# Persist JVM args in ENV so the entrypoint can expand them at runtime.
ENV ENV_JVM_ARGS=$JVM_ARGS
# need the sh -c syntax so that the SECRETS variable gets expanded
# use the "exec" syntax so that SIGINT reaches the JVM -> graceful termination
CMD ["sh", "-c", "exec java -Dedc.fs.config=/app/configuration.properties -Dedc.vault.secrets=\"${SECRETS}\" -Djava.util.logging.config.file=/app/logging.properties -Djava.security.egd=file:/dev/urandom -jar edc-dataplane.jar --log-level=debug"]
