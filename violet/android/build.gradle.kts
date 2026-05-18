import org.gradle.api.GradleException
import java.io.ByteArrayOutputStream

plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
    id("com.google.firebase.crashlytics") version "2.9.9" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

val androidRustTargets = listOf(
    "armv7-linux-androideabi",
    "aarch64-linux-android",
    "i686-linux-android",
    "x86_64-linux-android",
)

fun setProcessEnvironment(name: String, value: String) {
    try {
        val environment = System.getenv()
        val field = environment.javaClass.getDeclaredField("m")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        (field.get(environment) as MutableMap<String, String>)[name] = value
        return
    } catch (_: ReflectiveOperationException) {
        // Fall through to the ProcessEnvironment maps used by some JDKs.
    }

    try {
        val processEnvironment = Class.forName("java.lang.ProcessEnvironment")
        val variableClass = Class.forName("java.lang.ProcessEnvironment\$Variable")
        val valueClass = Class.forName("java.lang.ProcessEnvironment\$Value")
        val variableValueOf = variableClass.getDeclaredMethod("valueOf", String::class.java)
        val valueValueOf = valueClass.getDeclaredMethod("valueOf", String::class.java)
        variableValueOf.isAccessible = true
        valueValueOf.isAccessible = true
        val variable = variableValueOf.invoke(null, name)
        val environmentValue = valueValueOf.invoke(null, value)

        val environmentField = processEnvironment.getDeclaredField("theEnvironment")
        environmentField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        (environmentField.get(null) as MutableMap<Any, Any>)[variable] = environmentValue

        runCatching {
            val caseInsensitiveEnvironmentField =
                processEnvironment.getDeclaredField("theCaseInsensitiveEnvironment")
            caseInsensitiveEnvironmentField.isAccessible = true
            @Suppress("UNCHECKED_CAST")
            (caseInsensitiveEnvironmentField.get(null) as MutableMap<Any, Any>)[variable] =
                environmentValue
        }
        return
    } catch (_: ReflectiveOperationException) {
        throw GradleException("Failed to set $name for cargokit Rust build")
    }
}

subprojects {
    tasks.matching { it.name.startsWith("cargokitCargoBuild") }.configureEach {
        doFirst {
            val cargoBin = rootProject.file("${System.getProperty("user.home")}/.cargo/bin")
            val rustup = cargoBin.resolve("rustup").takeIf { it.canExecute() }?.absolutePath ?: "rustup"
            val path = listOf(cargoBin.absolutePath, System.getenv("PATH").orEmpty())
                .filter { it.isNotBlank() }
                .joinToString(":")

            exec {
                executable = rustup
                args("target", "add", *androidRustTargets.toTypedArray(), "--toolchain", "stable")
                environment("PATH", path)
            }

            val rustcOutput = ByteArrayOutputStream()
            exec {
                executable = rustup
                args("which", "rustc", "--toolchain", "stable")
                environment("PATH", path)
                standardOutput = rustcOutput
            }

            setProcessEnvironment("PATH", path)
            setProcessEnvironment("RUSTC", rustcOutput.toString().trim())
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
