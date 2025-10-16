plugins {
    id("java")
    id("application")
}

application {
    mainClass.set("org.eclipse.edc.identityhub.Main")
}

dependencies {
    // Añade aquí las dependencias necesarias para el identity-hub
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "org.eclipse.edc.identityhub.Main"
    }
}
