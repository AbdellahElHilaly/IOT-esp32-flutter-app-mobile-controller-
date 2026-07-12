allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureNamespace = {
        val android = extensions.findByName("android")
        if (android != null) {
            var pkgName: String? = null
            val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                try {
                    val content = manifestFile.readText()
                    val match = Regex("package=\"([^\"]+)\"").find(content)
                    if (match != null) {
                        pkgName = match.groupValues[1]
                        val cleanContent = content.replace("package=\"[^\"]+\"".toRegex(), "")
                        manifestFile.writeText(cleanContent)
                    }
                } catch (e: Exception) {}
            }

            val resolvedNamespace = pkgName ?: "com.example.${project.name.replace("-", "_")}"

            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android)
                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, resolvedNamespace)
                }
            } catch (e: Exception) {
                try {
                    val setNamespace = android.javaClass.getMethod("namespace", String::class.java)
                    setNamespace.invoke(android, resolvedNamespace)
                } catch (e2: Exception) {}
            }
        }
    }

    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}
