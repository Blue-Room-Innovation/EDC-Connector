plugins {
    id("java")
    id("application")
}

application {
    mainClass.set("org.eclipse.edc.dataplane.Main")
}

dependencies {
    // Añade aquí las dependencias necesarias para el dataplane
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "org.eclipse.edc.dataplane.Main"
    }
}
