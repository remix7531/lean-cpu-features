#!/usr/bin/env bash
# Negative + positive tests for `hasFeature`.
#
# Native run (no sandboxing) checks the host's actual feature flags.
# Under qemu-user with `-cpu`, the same binary sees a different
# CPUID/HWCAP, letting us assert the "feature absent" path on Linux
# without needing different hardware.  No macOS equivalent.
set -euo pipefail

cd "$(dirname "$0")/.."

PROBE="$(pwd)/.lake/build/bin/probe"
[[ -x "$PROBE" ]] || lake build probe >/dev/null

pass=0; fail=0

check() {
    local desc="$1" feature="$2" expected="$3"; shift 3
    local got
    got=$("$@" "$PROBE" "$feature" | awk '{print $2}')
    if [[ "$got" == "$expected" ]]; then
        printf 'PASS  %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL  %s  (got %s, expected %s)\n' "$desc" "$got" "$expected"
        fail=$((fail + 1))
    fi
}

uname_m="$(uname -m)"
os="$(uname -s)"

# --- Native positives + cross-arch negatives ---
# Cross-arch negatives exercise the dispatch table on the *running* arch:
# every modern x86 CPU lacks ARM-only feature names, and every ARM CPU
# lacks x86-only ones.  This covers the "no entry / wrong-arch entry"
# code paths even on machines where qemu can't sandbox.
if [[ "$uname_m" == "x86_64" ]]; then
    check "native x86 has sse2"     sse2     true
    check "native x86 has sse4.2"   sse4.2   true
    check "native x86 has popcnt"   popcnt   true
    # ARM-only feature names: no x86 entry → always false on x86.
    check "native x86 lacks sha1"   sha1     false
    check "native x86 lacks sha3"   sha3     false
    check "native x86 lacks sha512" sha512   false
    check "native x86 lacks crc32"  crc32    false
    # Unknown feature name.
    check "native x86 unknown"      bogus    false
elif [[ "$uname_m" == "aarch64" || "$uname_m" == "arm64" ]]; then
    check "native arm has aes"      aes      true
    # x86-only feature names: no ARM entry → always false on ARM.
    check "native arm lacks sse2"   sse2     false
    check "native arm lacks avx"    avx      false
    check "native arm lacks avx2"   avx2     false
    check "native arm lacks bmi2"   bmi2     false
    check "native arm lacks rdrnd"  rdrnd    false
    check "native arm lacks fma"    fma      false
    check "native arm lacks popcnt" popcnt   false
    check "native arm unknown"      bogus    false
fi

# --- Sandboxed negatives via qemu-user (x86 Linux only) ---
if [[ "$os" == "Linux" && "$uname_m" == "x86_64" ]]; then
    if command -v qemu-x86_64 >/dev/null; then
        # Nehalem (2008): SSE4.2 yes, SHA/AES/AVX no.
        check "qemu x86 Nehalem -- no sha"    sha     false qemu-x86_64 -cpu Nehalem
        check "qemu x86 Nehalem -- no aes"    aes     false qemu-x86_64 -cpu Nehalem
        check "qemu x86 Nehalem -- no avx"    avx     false qemu-x86_64 -cpu Nehalem
        check "qemu x86 Nehalem -- no avx2"   avx2    false qemu-x86_64 -cpu Nehalem
        check "qemu x86 Nehalem -- no bmi2"   bmi2    false qemu-x86_64 -cpu Nehalem
        check "qemu x86 Nehalem -- has sse4.2" sse4.2 true  qemu-x86_64 -cpu Nehalem
        # Westmere (2010): adds AES-NI, still no SHA-NI.
        check "qemu x86 Westmere -- has aes"  aes     true  qemu-x86_64 -cpu Westmere
        check "qemu x86 Westmere -- no sha"   sha     false qemu-x86_64 -cpu Westmere
        # `max`: every feature qemu can advertise.
        check "qemu x86 max -- has sha"       sha     true  qemu-x86_64 -cpu max
        check "qemu x86 max -- has avx2"      avx2    true  qemu-x86_64 -cpu max
    else
        echo "SKIP  qemu-x86_64 not installed (apt-get install qemu-user)"
    fi
fi

# ARM Linux: no portable way to fake auxv HWCAP (qemu-user passes it
# through from the host kernel); native + cross-arch negatives only.

echo
echo "Total: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
