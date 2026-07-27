# Compiles the `pc_dashboard` CLI into a standalone, Julia-free app
# directory via PackageCompiler.
#
# PackageCompiler lives in this build/ environment, not in
# PhysiCellDashboard's own Project.toml — it's a build-time tool,
# not a runtime dependency.
#
# Usage:
#   julia --project=build build/create_app.jl [app_dir]
#
# Expect this to take several minutes and produce an app directory
# in the hundreds-of-MB range (CairoMakie/Makie are heavy to compile
# into a sysimage). app_dir defaults to build/pc_dashboard_app.

using Pkg

const PKG_ROOT = normpath(joinpath(@__DIR__, ".."))

Pkg.develop(path = PKG_ROOT)
Pkg.instantiate()

using PackageCompiler

app_dir = isempty(ARGS) ? joinpath(@__DIR__, "pc_dashboard_app") : ARGS[1]

create_app(
    PKG_ROOT,
    app_dir;
    executables = ["pc_dashboard" => "julia_main"],
    force = true,
)

println("Built pc_dashboard app at $app_dir")
println("Run it with: $(joinpath(app_dir, "bin", "pc_dashboard"))")
