module PhysiCellDashboard

using Montage
using PhysiCellOutput

using HTTP
using JSON3

export dashboard

mutable struct DashboardState
    output_dir::String

    current_frame::Int
    latest_frame::Int

    playing::Bool

    image_file::String
end

function DashboardState(output_dir::String)
    DashboardState(
        output_dir,
        0,
        -1,
        true,
        joinpath(mktempdir(), "current.png")
    )
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

Render a tableau PNG for the requested snapshot.
"""
function render_frame!(state::DashboardState, idx::Integer)

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
        output = state.image_file,
        overwrite = true,
    )

    state.current_frame = idx

    return true
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

            try
                render_frame!(state, next_frame)
            catch err
                @warn "Could not load frame" frame=next_frame exception=err
            end
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
        "/current.png";
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

        target = req.target

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

            isfile(state.image_file) ||
                return HTTP.Response(404)

            return HTTP.Response(
                200,
                read(state.image_file);
                headers=["Content-Type" => "image/png"]
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

                render_frame!(state, idx)

                return HTTP.Response(200)
            end

            if target == "/prev"

                state.playing = false

                idx = max(
                    state.current_frame - 1,
                    0
                )

                render_frame!(state, idx)

                return HTTP.Response(200)
            end

            if target == "/start"

                state.playing = false

                render_frame!(state, 0)

                return HTTP.Response(200)
            end

            if target == "/end"

                state.playing = false

                render_frame!(
                    state,
                    state.latest_frame
                )

                return HTTP.Response(200)
            end
        end

        return HTTP.Response(404)
    end

    return handler
end

"""
    dashboard(folder; host="127.0.0.1", port=8080)

Launch a live dashboard for an existing or running
PhysiCell output folder.
"""
function dashboard(
    folder::AbstractString;
    host = "127.0.0.1",
    port = 8080,
)

    state = DashboardState(folder)

    latest = latest_snapshot_index(folder)

    if latest ≥ 0
        state.latest_frame = latest
        render_frame!(state, latest)
    end

    @async monitor!(state)

    @info "Dashboard available at http://$(host):$(port)"

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

end