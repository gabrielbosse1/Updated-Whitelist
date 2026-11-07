package online.slavok.whitelist

import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Per-loader manifest contract. One shaded jar serves every supported mod loader
 * (bukkit/spigot/paper/purpur/folia), so what each loader validates before
 * enabling the plugin is the plugin.yml contract asserted here. The test-matrix
 * CI job runs this suite once per loader (see .github/workflows/build.yml).
 */
class LoaderSupportTest {

    private val pluginYml: String = checkNotNull(
        javaClass.getResourceAsStream("/plugin.yml"),
    ) { "plugin.yml missing from the test classpath (processResources output)" }
        .bufferedReader().readText()

    @Test
    fun `bukkit and spigot accept the manifest at the 1_18 api floor`() {
        // Bukkit/Spigot 1.18+ refuse plugins declaring a newer api-version, so the
        // floor that makes the jar span 1.18 → 26.3 must not drift upward.
        assertTrue(
            pluginYml.contains("api-version: '1.18'"),
            "plugin.yml must declare api-version '1.18' (the bukkit/spigot 1.18+ floor)",
        )
    }

    @Test
    fun `folia enables the plugin only with the folia-supported flag`() {
        // Folia refuses to enable any plugin that does not opt in explicitly.
        assertTrue(
            pluginYml.contains("folia-supported: true"),
            "plugin.yml must declare folia-supported: true or Folia will not enable the plugin",
        )
    }

    @Test
    fun `manifest version is expanded before the jar reaches any loader`() {
        assertTrue(
            !pluginYml.contains("\${version}"),
            "processResources must expand \${version} — loaders reject a literal placeholder",
        )
    }
}
