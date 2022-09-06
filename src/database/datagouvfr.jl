using DataFrames
using CSV


function download_datagouvfr_data(source_folder::String)
    create_dir("$source_folder/datagouvfr")
    download("https://www.data.gouv.fr/fr/datasets/r/dbe8a621-a9c4-4bc3-9cae-be1699c5ff25",
        "$source_folder/datagouvfr/communes-departement-region.csv")
    download("https://www.data.gouv.fr/fr/datasets/r/c14e5a7d-2ca6-4ad8-bc61-93889d13fc25",
        "$source_folder/datagouvfr/registre-national-installation-production-stockage-electricite-agrege.csv")
end


function load_datagouvfr_data(source_folder::String)
    commune = DataFrame(CSV.File("$source_folder/datagouvfr/communes-departement-region.csv"))
    data = DataFrame(CSV.File("$source_folder/datagouvfr/registre-national-installation-production-stockage-electricite-agrege.csv"))

    insee2gps = Dict(zip(commune.code_commune_INSEE, commune.latitude, commune.longitude) .|> d ->
    begin
        length(d[1]) < 5 ? tag = "0" * d[1] : tag = d[1]
        lat, lon = (0,0)
        try
            lat, lon = Tuple{Float64,Float64}((d[2], d[3]))
        catch   
            lat, lon = (NaN, NaN)
        end
        tag => (lat, lon)
    end
    )

    departement = commune.code_departement .|> c -> typeof(c) == Missing ? "XX" : c
    dep = unique(departement)

    coord = dep .|> d -> findall(departement .== d) |> id ->
        try
            Tuple{Float64,Float64}((sum(commune.latitude[id]) / length(id), sum(commune.longitude[id]) / length(id)))
        catch
            (NaN, NaN)
        end

    lat = [coord[i][1] for i = 1:length(coord)]
    lon = [coord[i][2] for i = 1:length(coord)]
    dep2gps = Dict(zip(dep,lat,lon) .|> d -> d[1] => (d[2], d[3]))

    lat = Float64[]
    lon = Float64[]

    for i=1:size(data,1)
        try
            coord = insee2gps[data.codeinseecommune[i]]
        catch
            try
                coord = dep2gps[data.codedepartement[i]]
            catch
                coord = (NaN, NaN)
            end
        end
        push!(lat, coord[1])
        push!(lon, coord[2])
    end

    data[:,"latitude"] = lat
    data[:,"longitude"] = lon
    rename!(data, "puismaxinstallee" => "capacity")

    fr2tag = Dict("SOLAI" => "PV",
        "THERM" => "FT",
        "HYDLQ" => "HY",
        "EOLIE" => "WD",
        "BIOEN" => "BM",
        "STOCK" => "FT",
        "NUCLE" => "NU",
        "AUTRE" => "OT",
        "MARIN" => "OT",
        "GEOTH" => "OT",
    )
    data.capacity = data.capacity .|> c -> (typeof(c) == Missing) || isnan(c) ? 0.0 : c / 1000
    data.type = data.codefiliere .|> c -> fr2tag[c];
    return select!(data, [:capacity, :longitude, :latitude, :type])
end
