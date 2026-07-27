# PhysiCellDashboard

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://drbergman-lab.github.io/PhysiCellDashboard.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://drbergman-lab.github.io/PhysiCellDashboard.jl/dev/)
[![Build Status](https://github.com/drbergman-lab/PhysiCellDashboard.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/drbergman-lab/PhysiCellDashboard.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/drbergman-lab/PhysiCellDashboard.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/drbergman-lab/PhysiCellDashboard.jl)

A live, browser-based viewer for PhysiCell simulation output. Launches
alongside a running (or already-finished) simulation and shows each
snapshot as it's written, with play/pause/step controls.

## Command-line app (no Julia install required)

Every [GitHub Release](https://github.com/drbergman-lab/PhysiCellDashboard.jl/releases)
has a standalone `pc_dashboard` binary attached for macOS (Apple Silicon
and Intel), Linux, and Windows — built by
[build_app.yml](.github/workflows/build_app.yml) via PackageCompiler.
No Julia installation needed to run it.

**Install:**

1. Download the archive for your platform from the Releases page and
   extract it. You'll get a `pc_dashboard/` folder containing `bin/`,
   `lib/`, and `share/` — the executable needs the rest of the folder
   next to it, so don't move `bin/pc_dashboard` out on its own.
2. Make it callable from anywhere, either:
   - add `pc_dashboard/bin` to your `PATH`, or
   - symlink just the executable into a directory already on your
     `PATH` (this is safe — the app resolves its own real location at
     startup to find its bundled libraries, the same way Julia's own
     official installer recommends symlinking `julia` itself):
     ```bash
     ln -s /path/to/pc_dashboard/bin/pc_dashboard /usr/local/bin/pc_dashboard
     ```
3. **macOS only:** since the binary isn't notarized, Gatekeeper will
   quarantine it on first download. Clear that once per download with:
   ```bash
   xattr -dr com.apple.quarantine /path/to/pc_dashboard
   ```

**Use it:**

```bash
# Launch a PhysiCell run and watch it live:
pc_dashboard -- ./project ./config/PhysiCell_settings.xml

# Just watch an existing/running output folder:
pc_dashboard -o output

# Full usage:
pc_dashboard --help
```

## From Julia

```julia
using PhysiCellDashboard

# Watch an existing/running output folder:
dashboard("output")

# Or launch the simulation yourself:
dashboard(`./project ./config/PhysiCell_settings.xml`)
```

## Building the app yourself

```bash
julia --project=build build/create_app.jl
```

Produces `build/pc_dashboard_app/`. Expect this to take several
minutes and produce an app directory in the hundreds-of-MB range —
see [TODO.md](TODO.md) for a planned path to shrinking that.
