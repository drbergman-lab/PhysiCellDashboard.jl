module PhysiCellDashboard

using CairoMakie
using Montage
using PhysiCellOutput

using HTTP
using JSON3
using LightXML

export dashboard

mutable struct DashboardState
    output_dir::String

    current_frame::Int
    latest_frame::Int

    playing::Bool

    cache_dir::String
end

function DashboardState(output_dir::String)
    DashboardState(
        output_dir,
        -1,
        -1,
        true,
        mktempdir()
    )
end

"""
    frame_path(state, idx)

Path to the cached PNG for snapshot `idx`, whether or not it
has been rendered yet.
"""
function frame_path(state::DashboardState, idx::Integer)
    return joinpath(state.cache_dir, "frame$(lpad(idx, 8, '0')).png")
end

"""
    latest_snapshot_index(folder)

Return the largest PhysiCell output index currently available.
"""
function latest_snapshot_index(folder)

    max_index = -1

    for file in readdir(folder)

        m = match(r"output(\d+)\.xml$", file)

        isnothing(m) && continue

        idx = parse(Int, m.captures[1])

        max_index = max(max_index, idx)
    end

    return max_index
end

"""
    render_frame!(state, idx)

Render a tableau PNG for the requested snapshot, or reuse the
cached one if this frame was already rendered this session.
"""
function render_frame!(state::DashboardState, idx::Integer)

    path = frame_path(state, idx)

    if !isfile(path)

        snap = PhysiCellSnapshot(
            state.output_dir,
            idx;
            include_cells = true,
            include_substrates = true,
            include_mesh = true,
        )

        snap === missing && return false

        Montage.tableau(
            snap;
            output = path,
            overwrite = true,
        )
    end

    state.current_frame = idx

    return true
end

"""
    try_render!(state, idx)

Render frame `idx`, catching and logging errors instead of
propagating them (e.g. a snapshot file mid-write by a running
simulation). Returns whether the render succeeded.
"""
function try_render!(state::DashboardState, idx::Integer)

    try
        return render_frame!(state, idx)
    catch err
        @warn "Could not load frame" frame=idx exception=err
        return false
    end
end

"""
    monitor!(state)

Background task that follows a running simulation.

Version 1 uses polling.
"""
function monitor!(state::DashboardState)

    while true

        latest = latest_snapshot_index(state.output_dir)

        if latest > state.latest_frame
            state.latest_frame = latest
        end

        if state.playing &&
           state.current_frame < state.latest_frame

            next_frame = state.current_frame + 1

            try_render!(state, next_frame)
        end

        sleep(1.0)
    end
end

function html_page()

    return """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>PhysiCell Dashboard</title>

<style>
body {
    font-family: sans-serif;
    margin: 10px;
}

img {
    max-width: 100%;
    border: 1px solid #ccc;
}

button {
    margin-right: 5px;
}
</style>

</head>
<body>

<h2>PhysiCell Dashboard</h2>

<div>
<button onclick="play()">Play</button>
<button onclick="pause()">Pause</button>
<button onclick="prev()">Prev</button>
<button onclick="next()">Next</button>
<button onclick="start()">Start</button>
<button onclick="end()">End</button>
</div>

<br>

<div>
Frame:
<span id="frame">0</span>
/
<span id="latest">0</span>
</div>

<br>

<img id="sim" src="/current.png">

<script>

async function refresh() {

    let r = await fetch("/state");
    let s = await r.json();

    document.getElementById("frame").textContent =
        s.current_frame;

    document.getElementById("latest").textContent =
        s.latest_frame;

    document.getElementById("sim").src =
        "/current.png?frame=" + s.current_frame;
}

async function command(name) {
    await fetch("/" + name, {
        method: "POST"
    });
}

function play()  { command("play");  }
function pause() { command("pause"); }

function next()  { command("next"); }
function prev()  { command("prev"); }

function start() { command("start"); }
function end()   { command("end"); }

setInterval(refresh, 1000);

refresh();

</script>

</body>
</html>
"""
end

function router(state)

    function handler(req)

        target = HTTP.URI(req.target).path

        if target == "/"

            return HTTP.Response(
                200,
                html_page();
                headers=["Content-Type" => "text/html"]
            )
        end

        if target == "/state"

            body = JSON3.write(Dict(
                "current_frame" => state.current_frame,
                "latest_frame" => state.latest_frame,
                "playing" => state.playing,
            ))

            return HTTP.Response(
                200,
                body;
                headers=["Content-Type" => "application/json"]
            )
        end

        if target == "/current.png"

            path = frame_path(state, state.current_frame)

            isfile(path) ||
                return HTTP.Response(404)

            return HTTP.Response(
                200,
                read(path);
                headers=[
                    "Content-Type" => "image/png",
                    "Cache-Control" => "no-store",
                ]
            )
        end

        if req.method == "POST"

            if target == "/play"
                state.playing = true
                return HTTP.Response(200)
            end

            if target == "/pause"
                state.playing = false
                return HTTP.Response(200)
            end

            if target == "/next"

                state.playing = false

                idx = min(
                    state.current_frame + 1,
                    state.latest_frame
                )

                ok = try_render!(state, idx)

                return HTTP.Response(ok ? 200 : 500)
            end

            if target == "/prev"

                state.playing = false

                idx = max(
                    state.current_frame - 1,
                    0
                )

                ok = try_render!(state, idx)

                return HTTP.Response(ok ? 200 : 500)
            end

            if target == "/start"

                state.playing = false

                ok = try_render!(state, 0)

                return HTTP.Response(ok ? 200 : 500)
            end

            if target == "/end"

                state.playing = false

                ok = try_render!(
                    state,
                    state.latest_frame
                )

                return HTTP.Response(ok ? 200 : 500)
            end
        end

        return HTTP.Response(404)
    end

    return handler
end

"""
    open_in_browser(url)

Open `url` in the system's default browser, on macOS, Linux, or
Windows. Logs a warning instead of throwing if that fails (e.g.
headless environments).
"""
function open_in_browser(url::AbstractString)

    try
        if Sys.isapple()
            run(`open $url`)
        elseif Sys.islinux()
            run(`xdg-open $url`)
        elseif Sys.iswindows()
            run(`cmd /c start $url`)
        else
            @warn "Don't know how to open a browser on this platform" url
        end
    catch err
        @warn "Could not open browser automatically" url exception=err
    end

    return nothing
end

"""
    dashboard(folder; host="127.0.0.1", port=8080, open_browser=true)

Launch a live dashboard for an existing or running
PhysiCell output folder.
"""
function dashboard(
    folder::AbstractString;
    host = "127.0.0.1",
    port = 8080,
    open_browser::Bool = true,
)

    state = DashboardState(folder)

    latest = latest_snapshot_index(folder)

    if latest ≥ 0
        state.latest_frame = latest
        try_render!(state, latest)
    end

    @async monitor!(state)

    url = "http://$(host):$(port)"

    @info "Dashboard available at $url"

    open_browser && open_in_browser(url)

    HTTP.serve(
        host,
        port,
    ) do req

        try
            router(state)(req)
        catch err

            @show err
            showerror(stdout, err)
            println()

            rethrow(err)
        end
    end
end

const DEFAULT_CONFIG_PATH = joinpath("config", "PhysiCell_settings.xml")

"""
    read_save_folder(config_path)

Read the `<save><folder>` text from a PhysiCell config XML file,
or `nothing` if the file can't be parsed or doesn't have one.
"""
function read_save_folder(config_path::AbstractString)

    xml_doc = try
        LightXML.parse_file(config_path)
    catch err
        @warn "Could not parse config XML" config_path exception=err
        return nothing
    end

    try
        save_elem = LightXML.find_element(LightXML.root(xml_doc), "save")
        save_elem === nothing && return nothing

        folder_elem = LightXML.find_element(save_elem, "folder")
        folder_elem === nothing && return nothing

        return strip(LightXML.content(folder_elem))
    finally
        LightXML.free(xml_doc)
    end
end

"""
    resolve_output_dir(cmd)

Determine the PhysiCell output directory for a simulation launched
via `cmd`, when the caller hasn't given one explicitly:

1. If `cmd` includes a `-o` flag, that's the output directory
   (resolved relative to the current working directory).
2. Otherwise, read `<save><folder>` from the simulation's config
   XML. The config path is `cmd`'s second argument (e.g.
   `./project ./config/settings.xml`), or `$DEFAULT_CONFIG_PATH`
   if `cmd` has no second argument.
3. If both of those fail, warn and fall back to `"./output"`.
"""
function resolve_output_dir(cmd::Cmd)

    args = cmd.exec

    o_idx = findfirst(==("-o"), args)
    if o_idx !== nothing && o_idx < length(args)
        return abspath(args[o_idx + 1])
    end

    config_path = abspath(length(args) ≥ 2 ? args[2] : DEFAULT_CONFIG_PATH)

    if isfile(config_path)
        folder = read_save_folder(config_path)
        folder === nothing || return abspath(folder)
    end

    @warn "Could not determine the output directory from the simulation command or its config; falling back to ./output" cmd config_path

    return abspath("output")
end

"""
    dashboard(cmd::Cmd; output_dir=nothing, host="127.0.0.1", port=8080, open_browser=true)

Launch a PhysiCell simulation via `cmd` and serve a live dashboard
of its output as it's produced. The simulation process is
terminated when the dashboard exits (e.g. via Ctrl-C).

If `output_dir` isn't given, it's resolved from `cmd` — see
[`resolve_output_dir`](@ref).
"""
function dashboard(
    cmd::Cmd;
    output_dir::Union{Nothing,AbstractString} = nothing,
    host = "127.0.0.1",
    port = 8080,
    open_browser::Bool = true,
)

    resolved_output_dir = output_dir === nothing ?
        resolve_output_dir(cmd) :
        output_dir

    @info "Launching simulation" cmd output_dir=resolved_output_dir

    proc = run(cmd; wait = false)

    try
        dashboard(
            resolved_output_dir;
            host = host,
            port = port,
            open_browser = open_browser,
        )
    finally
        if process_running(proc)
            @info "Stopping simulation"
            kill(proc)
        end
    end
end

const CLI_USAGE = """
Usage: pc_dashboard [-o DIR] [-p PORT] [--host HOST] [--no-browser] [-- CMD...]

  -o, --output-dir DIR   PhysiCell output folder to watch. If omitted
                         and a CMD is given, this is resolved from
                         CMD's own -o flag or its config XML (see
                         `resolve_output_dir`); otherwise defaults to
                         "output".
  -p, --port PORT        Port to serve the dashboard on (default: 8080)
      --host HOST        Host to bind to (default: "127.0.0.1")
      --no-browser       Don't open a browser window automatically
  -h, --help             Show this message

If CMD is given after `--`, it is launched as the PhysiCell
simulation and the dashboard follows its output as it's produced.
Otherwise the dashboard just watches an existing/running output
folder.

Examples:
  pc_dashboard -o output
  pc_dashboard -- ./project ./config/PhysiCell_settings.xml
"""

"""
    run_cli(args)

Parse `args` (as from `ARGS`) and launch the dashboard
accordingly. Used by [`julia_main`](@ref) for the compiled
`pc_dashboard` executable.
"""
function run_cli(args::Vector{String})

    output_dir = nothing
    host = "127.0.0.1"
    port = 8080
    open_browser = true

    sim_cmd_args = String[]
    reading_cmd = false

    i = 1
    while i ≤ length(args)
        a = args[i]

        if reading_cmd
            push!(sim_cmd_args, a)
        elseif a in ("-h", "--help")
            print(CLI_USAGE)
            return
        elseif a in ("-o", "--output-dir")
            i += 1
            output_dir = args[i]
        elseif a in ("-p", "--port")
            i += 1
            port = parse(Int, args[i])
        elseif a == "--host"
            i += 1
            host = args[i]
        elseif a == "--no-browser"
            open_browser = false
        elseif a == "--"
            reading_cmd = true
        else
            error(
                "Unrecognized argument: $a " *
                "(use `--` to separate pc_dashboard's own flags " *
                "from the simulation command)"
            )
        end

        i += 1
    end

    if isempty(sim_cmd_args)
        dashboard(something(output_dir, "output"); host, port, open_browser)
    else
        dashboard(Cmd(sim_cmd_args); output_dir, host, port, open_browser)
    end

    return
end

"""
    julia_main()::Cint

Entry point for the compiled `pc_dashboard` executable (see
[`PackageCompiler.create_app`](https://github.com/JuliaLang/PackageCompiler.jl)).
Reads `ARGS`; run `pc_dashboard --help` for usage.
"""
function julia_main()::Cint
    try
        run_cli(ARGS)
    catch err
        Base.invokelatest(Base.display_error, Base.current_exceptions())
        return 1
    end
    return 0
end

end