import Init.System.IO

/-- Fetch Mathlib and the project's published artifacts using stock tools. -/
def main (args : List String) : IO UInt32 := do
  let spawnArgs : IO.Process.SpawnArgs :=
    if System.Platform.isWindows then
      { cmd := "pwsh"
        args := #["-File", "scripts/lake-cache-get.ps1"] ++ args.toArray }
    else
      { cmd := "bash"
        args := #["scripts/lake-cache-get.sh"] ++ args.toArray }
  let child ← IO.Process.spawn spawnArgs
  child.wait
