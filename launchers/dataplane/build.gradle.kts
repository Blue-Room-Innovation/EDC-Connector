plugins {
    `java-library`
    id("application")
}

dependencies {
    implementation(project(":core:data-plane:data-plane-core"))
    implementation(project(":core:common:connector-core"))
    implementation(project(":extensions:common:vault:vault-hashicorp"))
    implementation(project(":extensions:common:monitor:monitor-jdk-logger"))
    implementation(project(":extensions:common:configuration:configuration-filesystem"))
    implementation(project(":extensions:common:sql:sql-core"))
    implementation(project(":extensions:common:sql:sql-bootstrapper"))
    implementation(project(":extensions:common:sql:sql-lease"))
    implementation(project(":extensions:common:sql:sql-pool:sql-pool-apache-commons"))
    implementation(libs.edc-runtime-metamodel)
    // Agrega aquí cualquier otra dependencia relevante de tu catálogo
}

application {
    mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime")
}

tasks.withType<com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar> {
    exclude("**/pom.properties", "**/pom.xml")
    mergeServiceFiles()
    archiveFileName.set("${project.name}.jar")
}
