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

# --- Native: feature universally available on every supported runner ---
case "$uname_m" in
    x86_64) check "native x86 has sse2"     sse2 true ;;
    aarch64|arm64) check "native arm has aes" aes  true ;;
esac

# --- Sandboxed negatives via qemu-user (Linux only) ---
if [[ "$os" == "Linux" ]] && command -v qemu-x86_64 >/dev/null && [[ "$uname_m" == "x86_64" ]]; then
    # Nehalem (2008): SSE4.2 yes, SHA/AES/AVX no.
    check "qemu x86 Nehalem -- no sha" sha false qemu-x86_64 -cpu Nehalem
    check "qemu x86 Nehalem -- no aes" aes false qemu-x86_64 -cpu Nehalem
    check "qemu x86 Nehalem -- no avx" avx false qemu-x86_64 -cpu Nehalem
    # `max`: every feature qemu can advertise — useful positive.
    check "qemu x86 max -- has sha"    sha true  qemu-x86_64 -cpu max
fi

if [[ "$os" == "Linux" ]] && command -v qemu-aarch64 >/dev/null && [[ "$uname_m" == "aarch64" ]]; then
    # cortex-a53 has no crypto extensions advertised by default.
    check "qemu arm cortex-a53 -- no sha" sha false qemu-aarch64 -cpu cortex-a53
    check "qemu arm cortex-a53 -- no aes" aes false qemu-aarch64 -cpu cortex-a53
    # max: full crypto.
    check "qemu arm max -- has sha"       sha true  qemu-aarch64 -cpu max
fi

echo
echo "Total: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
