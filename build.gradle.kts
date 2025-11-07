/*
 *  Copyright (c) 2022 Microsoft Corporation
 *
 *  This program and the accompanying materials are made available under the
 *  terms of the Apache License, Version 2.0 which is available at
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Contributors:
 *       Microsoft Corporation - initial API and implementation
 *
 */

import com.bmuschko.gradle.docker.tasks.image.DockerBuildImage
import com.github.jengelman.gradle.plugins.shadow.ShadowJavaPlugin

plugins {
    `java-library`
    id("com.bmuschko.docker-remote-api") version "9.4.0"
    id("com.github.johnrengelman.shadow") version "8.1.1"
    alias(libs.plugins.edc.build)
}

val javaVersion: String by project
val edcScmUrl: String by project
val edcScmConnection: String by project

buildscript {
    dependencies {
        val version: String by project
        classpath("org.eclipse.edc.edc-build:org.eclipse.edc.edc-build.gradle.plugin:$version")
    }
}

allprojects {
    apply(plugin = "${group}.edc-build")

    configure<org.eclipse.edc.plugins.edcbuild.extensions.BuildExtension> {
        pom {
            scmUrl.set(edcScmUrl)
            scmConnection.set(edcScmConnection)
        }
    }

    configure<CheckstyleExtension> {
        configFile = rootProject.file("resources/edc-checkstyle-config.xml")
        configDirectory.set(rootProject.file("resources"))
    }
    configure<org.eclipse.edc.plugins.edcbuild.extensions.BuildExtension> {
        swagger {
            title.set("Identity HUB REST API")
            description = "Identity HUB REST APIs - merged by OpenApiMerger"
            outputFilename.set(project.name)
            outputDirectory.set(file("${rootProject.projectDir.path}/resources/openapi/yaml"))
        }
    }

}
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.github.johnrengelman.shadow") &&
            file("${project.projectDir}/src/main/docker/Dockerfile").exists()
        ) {

            //actually apply the plugin to the (sub-)project
            apply(plugin = "com.bmuschko.docker-remote-api")
            // configure the "dockerize" task
            val dockerTask: DockerBuildImage = tasks.create("dockerize", DockerBuildImage::class) {
                val dockerContextDir = project.projectDir
                dockerFile.set(file("$dockerContextDir/src/main/docker/Dockerfile"))
                images.add("${project.name}:${project.version}")
                images.add("${project.name}:latest")
                // specify platform with the -Dplatform flag:
                if (System.getProperty("platform") != null)
                    platform.set(System.getProperty("platform"))
                buildArgs.put("JAR", "build/libs/${project.name}.jar")
                inputDir.set(file(dockerContextDir))
            }
            // make sure  always runs after "dockerize" and after "copyOtel"
            dockerTask.dependsOn(tasks.named(ShadowJavaPlugin.SHADOW_JAR_TASK_NAME))
        }
    }
}
