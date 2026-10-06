// Apply the PIT Gradle plugin to every JVM project without changing its build files.
// Per-run scope comes from Gradle properties:
//   -PpitTargetClasses=a.b.*,c.D   classes to mutate
//   -PpitTargetTests=a.b.*Test      tests to run (default: same as target classes)
//   -PpitExcludedTests=*RedisTest   test classes to exclude
//   -PpitTestMethods=name1,name2    test methods to run (default: all)
initscript {
    repositories { gradlePluginPortal() }
    dependencies { classpath("info.solidsoft.gradle.pitest:gradle-pitest-plugin:1.19.0") }
}

allprojects {
    pluginManager.withPlugin("java") {
        apply<info.solidsoft.gradle.pitest.PitestPlugin>()
        extensions.configure<info.solidsoft.gradle.pitest.PitestPluginExtension> {
            pitestVersion.set("1.30.0")
            junit5PluginVersion.set("1.2.3")
            outputFormats.set(listOf("XML", "HTML"))
            timestampedReports.set(false)
            fullMutationMatrix.set(true)
            threads.set(Runtime.getRuntime().availableProcessors())

            fun csv(name: String): Set<String>? =
                (findProperty(name) as String?)?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() }?.toSet()

            csv("pitTargetClasses")?.let { targetClasses.set(it) }
            (csv("pitTargetTests") ?: csv("pitTargetClasses"))?.let { targetTests.set(it) }
            csv("pitExcludedTests")?.let { excludedTestClasses.set(it) }
            csv("pitTestMethods")?.let { includedTestMethods.set(it) }
        }
    }
}
