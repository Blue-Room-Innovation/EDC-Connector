plugins {
    id("java")
    id("application")
}

application {
    mainClass.set("org.eclipse.edc.controlplane.Main")
}

dependencies {
    // Añade aquí las dependencias necesarias para el controlplane
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "org.eclipse.edc.controlplane.Main"
    }
}
