plugins {
    `java-library`
    id("application")
    id("com.github.johnrengelman.shadow") version "8.1.1"
}

application { mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime") }

java { toolchain { languageVersion.set(JavaLanguageVersion.of(17)) } }

repositories { mavenCentral() }

dependencies {
    // Básico: boot + runtime core + connector core
    implementation(project(":core:common:boot"))
    implementation(project(":core:common:connector-core"))
    // Se elimina control-plane-core para un runtime ultra mínimo (solo health endpoint)

    // HTTP server (Jetty + Jersey) y WebService
    implementation(project(":extensions:common:http"))

    // Monitor simple y configuración por fichero
    implementation(project(":extensions:common:monitor:monitor-jdk-logger"))
    implementation(project(":extensions:common:configuration:configuration-filesystem"))

    // (Opcional) JSON-LD no es necesario para el health, se omite

    // Jakarta RS para las anotaciones (@Path, @GET, etc.) usadas por el endpoint de health
    implementation(libs.jakarta.rsApi)
}

tasks.withType<com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar> {
    mergeServiceFiles()
    archiveFileName.set("minimal-connector.jar")
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
}
