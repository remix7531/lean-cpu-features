import Lake
open Lake DSL System

package «cpu-features» where
  precompileModules := true

@[default_target]
lean_lib CpuFeatures

target cpuFeaturesO pkg : FilePath := do
  let oFile := pkg.buildDir / "c" / "cpu_features.o"
  let src ← inputTextFile <| pkg.dir / "c" / "cpu_features.c"
  let leanInclude := (← getLeanIncludeDir).toString
  buildO oFile src
    (weakArgs := #["-I", leanInclude])
    (traceArgs := #["-O2", "-fPIC"])

extern_lib libcpu_features pkg := do
  let name := nameToStaticLib "cpu_features"
  let job ← cpuFeaturesO.fetch
  buildStaticLib (pkg.staticLibDir / name) #[job]

lean_exe probe where
  root := `Probe
