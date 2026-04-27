/-!
# CpuFeatures

Runtime CPU-feature probe.  `hasFeature : String → Bool`.

Each feature name is mapped to one or more architecture-specific probes
in `table` below.  The wrong-arch probes always return `false` at the C
level, so listing both x86 and ARM entries for the same logical feature
is safe — `hasFeature` returns `true` if any matching probe fires.

Reference for the bit numbers / sysctl keys:
  * x86 — Intel SDM Vol. 2A §3.2 (CPUID); AMD APM Vol. 3 App. E.
  * ARM Linux HWCAP / HWCAP2 — `<asm/hwcap.h>` in the kernel tree.
  * Apple Silicon — `hw.optional.arm.FEAT_*` sysctl keys
    (`sysctl -a hw.optional` on a Mac).
-/

namespace CpuFeatures

/-- x86 CPUID bit query.  `reg` is `0=EAX, 1=EBX, 2=ECX, 3=EDX`. -/
@[extern "lean_cpuid_bit"]
private opaque cpuidBit (leaf subleaf : UInt32) (reg bit : UInt8) : Bool

/-- ARM Linux auxv-hwcap bit query.  `reg=0` → HWCAP, `reg=1` → HWCAP2. -/
@[extern "lean_arm_hwcap_bit"]
private opaque armHwcapBit (reg bit : UInt8) : Bool

/-- macOS `sysctlbyname` integer query — true iff the key exists and is non-zero. -/
@[extern "lean_sysctl_int"]
private opaque sysctlInt (key : @& String) : Bool

private inductive Probe
  /-- x86 CPUID: leaf, subleaf, register (0..3 = EAX..EDX), bit. -/
  | x86  (leaf subleaf : UInt32) (reg bit : UInt8)
  /-- ARM Linux HWCAP: register (0 = HWCAP, 1 = HWCAP2), bit. -/
  | arm  (reg bit : UInt8)
  /-- macOS sysctl integer key — used for Apple Silicon FEAT_* flags. -/
  | mac  (key : String)

private def Probe.run : Probe → Bool
  | .x86 l s r b => cpuidBit l s r b
  | .arm r b     => armHwcapBit r b
  | .mac k       => sysctlInt k

private def table : List (String × Probe) := [
  -- x86: leaf 1, ECX
  ("sse3",    .x86 1 0 2  0),
  ("pclmul",  .x86 1 0 2  1),
  ("ssse3",   .x86 1 0 2  9),
  ("fma",     .x86 1 0 2 12),
  ("sse4.1",  .x86 1 0 2 19),
  ("sse4.2",  .x86 1 0 2 20),
  ("popcnt",  .x86 1 0 2 23),
  ("aes",     .x86 1 0 2 25),
  ("avx",     .x86 1 0 2 28),
  ("rdrnd",   .x86 1 0 2 30),
  -- x86: leaf 1, EDX
  ("sse2",    .x86 1 0 3 26),
  -- x86: leaf 7 subleaf 0, EBX
  ("bmi",     .x86 7 0 1  3),
  ("avx2",    .x86 7 0 1  5),
  ("bmi2",    .x86 7 0 1  8),
  ("rdseed",  .x86 7 0 1 18),
  ("sha",     .x86 7 0 1 29),
  -- ARM aarch64 Linux HWCAP
  ("aes",     .arm 0  3),
  ("pclmul",  .arm 0  4),  -- PMULL on ARM
  ("sha1",    .arm 0  5),
  ("sha",     .arm 0  6),  -- SHA2 on ARM
  ("crc32",   .arm 0  7),
  ("sha3",    .arm 0 17),
  ("sha512",  .arm 0 21),
  -- Apple Silicon (macOS arm64)
  ("aes",     .mac "hw.optional.arm.FEAT_AES"),
  ("pclmul",  .mac "hw.optional.arm.FEAT_PMULL"),
  ("sha1",    .mac "hw.optional.arm.FEAT_SHA1"),
  ("sha",     .mac "hw.optional.arm.FEAT_SHA256"),
  ("sha512",  .mac "hw.optional.arm.FEAT_SHA512"),
  ("sha3",    .mac "hw.optional.arm.FEAT_SHA3"),
  ("crc32",   .mac "hw.optional.armv8_crc32"),
]

/-- `true` iff the running CPU advertises `feature`. -/
def hasFeature (feature : String) : Bool :=
  table.any fun (name, probe) => name == feature && probe.run

end CpuFeatures
