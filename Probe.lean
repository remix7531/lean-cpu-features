import CpuFeatures

def main (args : List String) : IO Unit := do
  let names := if args.isEmpty then
    ["sse2", "sse4.2", "avx", "avx2", "aes", "sha", "bmi2"]
  else args
  for n in names do
    IO.println s!"{n}: {CpuFeatures.hasFeature n}"
