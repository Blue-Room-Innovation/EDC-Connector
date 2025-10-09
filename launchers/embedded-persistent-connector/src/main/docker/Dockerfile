FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Nombre del JAR sombreado (se puede sobreescribir con --build-arg JAR=...)
ARG JAR=minimal-connector.jar
COPY build/libs/${JAR} app.jar
COPY configuration.properties ./configuration.properties

EXPOSE 8181
ENV JAVA_TOOL_OPTIONS="-Xms128m -Xmx256m"

ENTRYPOINT ["java","-jar","app.jar","-Dedc.fs.config=configuration.properties"]
