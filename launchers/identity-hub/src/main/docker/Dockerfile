# Identity Hub launcher image (Temurin Java 23 on Alpine) stays lightweight yet supports curl.
# The "-buster" tag gives access to the package manager required for installing curl later on.
FROM eclipse-temurin:23.0.2_7-jre-alpine

# Build-time args: callers can provide JVM flags (e.g., memory) or override the JAR location.
ARG JVM_ARGS=""
ARG JAR

# Curl enables the HEALTHCHECK command to poll the HTTP health endpoint from within the container.
RUN apk --no-cache add curl

WORKDIR /app


# Copy the shaded Identity Hub runtime into the container filesystem.
COPY ${JAR} identity-hub.jar

# The default hub HTTP API listens on 8080 internally (exposed as 8380 on the host via compose).
# Expose 8188 as well for legacy probes that rely on this port; the runtime still binds 8080.
EXPOSE 8188

# Base HTTP API configuration mirrors configuration.properties so the Dockerfile + config stay aligned.
ENV WEB_HTTP_PORT="8080"
ENV WEB_HTTP_PATH="/api"

# Health probe that matches the exposed port/path and is used by Docker to flag unhealthy containers.
HEALTHCHECK --interval=5s --timeout=5s --retries=10 CMD curl --fail http://localhost:8080/api/check/health

# Use "exec" for graceful termination (SIGINT) to reach JVM.
# ARG can not be used in ENTRYPOINT so storing value in an ENV variable
# Preserve optional JVM args/app insights agent version for runtime expansion in the entrypoint.
ENV ENV_JVM_ARGS=$JVM_ARGS
ENV ENV_APPINSIGHTS_AGENT_VERSION=$APPINSIGHTS_AGENT_VERSION
ENTRYPOINT [ "sh", "-c", "exec java $ENV_JVM_ARGS -jar identity-hub.jar --log-level=debug"]
