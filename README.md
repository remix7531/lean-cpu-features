# cpu-features

Tiny Lean 4 library: runtime CPU feature detection.

```lean
import CpuFeatures

#eval CpuFeatures.hasFeature "sha"   -- true / false
#eval CpuFeatures.hasFeature "avx2"
#eval CpuFeatures.hasFeature "aes"
```

`hasFeature : String → Bool` returns whether the running CPU advertises
the named feature. The string is matched against an internal table that
maps each name to one or more architecture-specific probes:

| platform | mechanism |
|---|---|
| x86 (any OS) | `cpuid` |
| Linux aarch64 | `getauxval(AT_HWCAP / HWCAP2)` |
| macOS arm64 (Apple Silicon) | `sysctlbyname("hw.optional.arm.FEAT_*")` |

Wrong-arch probes return `false`, so listing both an x86 and an ARM
entry under the same logical name (e.g. `"sha"` for SHA-NI **or** ARMv8
SHA-2) is safe.

## Recognised names

`sha`, `sha1`, `sha512`, `sha3`, `aes`, `avx`, `avx2`, `sse2`, `sse3`,
`ssse3`, `sse4.1`, `sse4.2`, `bmi`, `bmi2`, `pclmul`, `popcnt`,
`rdrnd`, `rdseed`, `fma`, `crc32`. Add more in `CpuFeatures.lean`.

## Build / test

```sh
make build    # lake build
make probe    # ./.lake/build/bin/probe — prints flag values
make test     # native + qemu-user negative tests (Linux)
make clean
```

`tests/run.sh` runs the same compiled binary natively and under
`qemu-x86_64 -cpu ...` / `qemu-aarch64 -cpu ...` to assert the
**feature-absent** path on Linux. macOS skips the qemu negatives
(no equivalent on Darwin).

## Use as a dependency

```lean
require «cpu-features» from git "https://github.com/remix7531/lean-cpu-features.git" @ "main"
```
