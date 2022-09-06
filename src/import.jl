export import_csv

function import_csv(foldername)
    scenario = Dict{String, DataFrame}()
    filename = readdir(foldername)
    for f in filename
        if contains(f, ".csv")
            scenario[f[1:end-4]] = CSV.read("$foldername/$f", DataFrame)  
        end
    end
    return scenario
end
