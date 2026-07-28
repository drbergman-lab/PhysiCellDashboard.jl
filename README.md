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
and Intel) and Windows — built by
[build_app.yml](.github/workflows/build_app.yml) via PackageCompiler.
No Julia installation needed to run it.

**Linux:** no prebuilt binary is provided — PackageCompiler's build requires more RAM
 than is available on GitHub's standard Linux runners. Build it yourself instead; see
"Building the app yourself" below. That does mean installing Julia first,
but the build itself is otherwise the same one-line command everyone else's
binary comes from.

**Install:**

1. Download the archive for your platform from the Releases page and
   extract it. You'll get a `pc_dashboard/` folder (containing `bin/`,
   `lib/`, and `share/` — the executable needs the rest of the folder
   next to it, so don't move `bin/pc_dashboard` out on its own), plus
   an `install.sh` next to it on macOS only.
2. **macOS:** run `./install.sh` from wherever you extracted to. This
   clears Gatekeeper's quarantine flag from the whole `pc_dashboard/`
   folder — needed because a browser download quarantines every file
   individually, not just the top-level archive, and pc_dashboard
   ships dozens of separate `.dylib`s (one per bundled library) that
   Gatekeeper would otherwise block one at a time on first launch.
   (Windows doesn't have this problem, so there's nothing to run there.)

   If you'd rather do it by hand, or `install.sh` isn't there:
   ```bash
   chmod -R u+w /path/to/pc_dashboard
   xattr -dr com.apple.quarantine /path/to/pc_dashboard
   ```
   on the **extracted folder** — not just `pc_dashboard/bin/pc_dashboard`.
3. Make it callable from anywhere, either:
   - add `pc_dashboard/bin` to your `PATH`, or
   - symlink just the executable into a directory already on your
     `PATH` (this is safe — the app resolves its own real location at
     startup to find its bundled libraries, the same way Julia's own
     official installer recommends symlinking `julia` itself):
     ```bash
     ln -s /path/to/pc_dashboard/bin/pc_dashboard /usr/local/bin/pc_dashboard
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

From the root of this repo (downloaded or cloned), run:

```bash
julia --project=build build/create_app.jl
```

Produces `build/pc_dashboard_app/`. Expect this to take several
minutes and produce an app directory in the hundreds-of-MB range.
