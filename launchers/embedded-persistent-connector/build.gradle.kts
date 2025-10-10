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
    implementation(project(":core:control-plane:control-plane-core"))
    implementation(project(":core:common:edr-store-core"))
    implementation(project(":core:common:token-core"))
    implementation(project(":core:data-plane-selector:data-plane-selector-core"))
    implementation(project(":core:policy-monitor:policy-monitor-core"))
    implementation(project(":extensions:common:json-ld"))
    implementation(project(":extensions:common:iam:decentralized-identity"))
    implementation(project(":extensions:common:iam:identity-trust"))

    // Control Plane completo (DSP, APIs, identidad, autenticación básica)
    implementation(project(":data-protocols:dsp"))
    implementation(project(":data-protocols:dsp:dsp-http-api-configuration"))
    implementation(project(":dist:bom:controlplane-dcp-bom"))

    // Persistencia SQL para stores de control plane y selectores
    implementation(project(":dist:bom:controlplane-feature-sql-bom"))

    // HTTP server (Jetty + Jersey) y WebService
    implementation(project(":extensions:common:http"))
    implementation(project(":extensions:common:api:management-api-configuration"))
    implementation(project(":extensions:common:api:control-api-configuration"))
    implementation(project(":extensions:common:auth:auth-tokenbased"))

    // Monitor simple y configuración por fichero
    implementation(project(":extensions:common:monitor:monitor-jdk-logger"))
    implementation(project(":extensions:common:configuration:configuration-filesystem"))

    // Vault Hashicorp para secretos externos
    implementation(project(":extensions:common:vault:vault-hashicorp"))

    // APIs del control plane (Management + Control) y selector de data planes
    implementation(project(":extensions:control-plane:api:management-api"))
    implementation(project(":extensions:control-plane:api:control-plane-api"))
    implementation(project(":extensions:data-plane-selector:data-plane-selector-api"))
    implementation(project(":extensions:data-plane-selector:data-plane-selector-control-api"))
    implementation(project(":extensions:control-plane:callback:callback-http-dispatcher"))
    implementation(project(":extensions:control-plane:callback:callback-event-dispatcher"))
    implementation(project(":extensions:control-plane:edr:edr-store-receiver"))
    implementation(project(":extensions:control-plane:transfer:transfer-data-plane-signaling"))
    implementation(project(":extensions:control-plane:provision:provision-http"))
    implementation(project(":extensions:control-plane:transfer:transfer-pull-http-dynamic-receiver"))
    implementation(project(":extensions:common:iam:oauth2:oauth2-client"))

    // Driver JDBC para Postgres
    implementation(libs.postgres)

    // (Opcional) JSON-LD no es necesario para el health, se omite

    // Jakarta RS para las anotaciones (@Path, @GET, etc.) usadas por el endpoint de health
    implementation(libs.jakarta.rsApi)
}

tasks.withType<com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar> {
    mergeServiceFiles()
    archiveFileName.set("minimal-connector.jar")
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
}
