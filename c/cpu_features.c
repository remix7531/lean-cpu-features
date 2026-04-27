/* Generic CPU feature probes — feature-name-free.
 *
 * Three exports, one per detection mechanism:
 *   lean_cpuid_bit(leaf, subleaf, reg, bit) : UInt8
 *     x86 CPUID:  reg ∈ {0=EAX, 1=EBX, 2=ECX, 3=EDX}.
 *   lean_arm_hwcap_bit(reg, bit) : UInt8
 *     ARM Linux auxv hwcap:  reg=0 → HWCAP, reg=1 → HWCAP2.
 *   lean_sysctl_int(name) : UInt8
 *     macOS sysctlbyname (used for Apple Silicon feature flags such as
 *     "hw.optional.arm.FEAT_SHA256").
 *
 * Each export returns 0 outside its applicable platform.  The
 * feature-name → (probe, parameters) mapping lives in CpuFeatures.lean.
 */

#include <stdint.h>
#include <lean/lean.h>

#if defined(__x86_64__) || defined(__i386__)
#include <cpuid.h>
#endif

#if (defined(__aarch64__) || defined(__arm__)) && defined(__linux__)
#include <sys/auxv.h>
#endif

#if defined(__APPLE__)
#include <sys/sysctl.h>
#include <stddef.h>
#endif

LEAN_EXPORT uint8_t lean_cpuid_bit(uint32_t leaf, uint32_t subleaf,
                                   uint8_t reg, uint8_t bit) {
#if defined(__x86_64__) || defined(__i386__)
    unsigned int r[4] = {0, 0, 0, 0};
    if (__get_cpuid_count(leaf, subleaf, &r[0], &r[1], &r[2], &r[3]))
        return (uint8_t)((r[reg & 3] >> (bit & 31)) & 1);
#else
    (void)leaf; (void)subleaf; (void)reg; (void)bit;
#endif
    return 0;
}

LEAN_EXPORT uint8_t lean_arm_hwcap_bit(uint8_t reg, uint8_t bit) {
#if (defined(__aarch64__) || defined(__arm__)) && defined(__linux__)
    unsigned long h = (reg == 0) ? getauxval(AT_HWCAP) : getauxval(AT_HWCAP2);
    return (uint8_t)((h >> (bit & 63)) & 1);
#else
    (void)reg; (void)bit;
    return 0;
#endif
}

LEAN_EXPORT uint8_t lean_sysctl_int(b_lean_obj_arg name) {
#if defined(__APPLE__)
    int64_t v = 0;
    size_t sz = sizeof(v);
    if (sysctlbyname(lean_string_cstr(name), &v, &sz, NULL, 0) == 0)
        return (uint8_t)(v != 0);
#else
    (void)name;
#endif
    return 0;
}
