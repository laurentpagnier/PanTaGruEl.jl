export export_matpower, export_csv, export_pandapower, export_pandapower,
    export_oats

include("export/matpower.jl")
include("export/pandapower.jl")
include("export/oats.jl")

function get_matpower_type(t)
    if t == "PQ"
        return 1
    elseif t == "PV"
        return 2
    elseif t == "Vθ"
        return 3
    end
end

function export_csv(foldername, scenario)
    create_dir(foldername)
    for k in keys(scenario)
        CSV.write("$foldername/$k.csv", scenario[k])  
    end
    nothing
end



