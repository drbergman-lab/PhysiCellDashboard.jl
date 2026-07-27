using PhysiCellDashboard
using Documenter

DocMeta.setdocmeta!(PhysiCellDashboard, :DocTestSetup, :(using PhysiCellDashboard); recursive=true)

makedocs(;
    modules=[PhysiCellDashboard],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="PhysiCellDashboard.jl",
    format=Documenter.HTML(;
        canonical="https://drbergman-lab.github.io/PhysiCellDashboard.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/drbergman-lab/PhysiCellDashboard.jl",
    devbranch="main",
)
