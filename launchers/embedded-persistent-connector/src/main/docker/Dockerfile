FROM gradle:8-jdk17-alpine AS build
WORKDIR /workspace

# Copiamos solo los artefactos necesarios para compilar el subproyecto y cachear dependencias.
COPY gradle gradle
COPY gradlew gradlew
COPY gradlew.bat gradlew.bat
COPY build.gradle.kts build.gradle.kts
COPY settings.gradle.kts settings.gradle.kts
COPY gradle.properties gradle.properties
COPY version-catalog version-catalog
COPY core core
COPY extensions extensions
COPY resources resources
COPY spi spi
COPY launchers launchers

RUN sed -i 's/\r$//' gradlew \
	&& chmod +x gradlew \
	&& echo "Gradle está compilando el runtime minimal (tarda ~2 min la primera vez)..." \
	&& ./gradlew :launchers:embedded-persistent-connector:shadowJar --no-daemon --console=plain --info

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Nombre del JAR sombreado (se puede sobreescribir con --build-arg JAR=...)
ARG JAR=minimal-connector.jar
COPY --from=build /workspace/launchers/embedded-persistent-connector/build/libs/${JAR} app.jar
COPY launchers/embedded-persistent-connector/configuration.properties ./configuration.properties
COPY launchers/embedded-persistent-connector/logging.properties ./logging.properties

RUN mkdir -p /app/logs

EXPOSE 8181
ENV JAVA_TOOL_OPTIONS="-Xms128m -Xmx256m -Djava.util.logging.config.file=/app/logging.properties"

ENTRYPOINT ["java","-jar","app.jar","-Dedc.fs.config=configuration.properties"]
