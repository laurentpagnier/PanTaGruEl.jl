include("../utm.jl")


function download_bundesnetzagentur_data(
    source_folder::String
)
    create_dir("$source_folder/bundesnetzagentur")
    download("https://www.bundesnetzagentur.de/SharedDocs/Downloads/DE/Sachgebiete/Energie/Unternehmen_Institutionen/ErneuerbareEnergien/ZahlenDatenInformationen/VOeFF_Registerdaten/2019_01_Veroeff_RegDaten.xlsx?__blob=publicationFile&v=2",
        "$source_folder/bundesnetzagentur/2019_01_Veroeff_RegDaten.xlsx")
end


function load_bundesnetzagentur_data(
    source_folder::String
)
    de2type = Dict(
        "Biomasse" => "BM",
        "Wasserkraft" => "HY",
        "Wind Land" => "WD",
        "Wind See" => "WD",
        "Grubengas" => "OT",
        "Klärgas" => "OT",
        "Deponiegas" => "OT",
        "Freifläche PV" => "PV",
        "Geothermie" => "OT",
        "Speicher" => "HY",
    )
    
    data = DataFrame(XLSX.readtable("$source_folder/bundesnetzagentur/2019_01_Veroeff_RegDaten.xlsx", "Gesamtübersicht"))
    E = data."UTM-East" .|> e -> typeof(e) == Missing ? NaN : e .- 3.2E7
    N = Float64.(data."UTM-North" .|> n -> typeof(n) == Missing ? NaN : n)
    zone = 32
    lat, lon = utm2gps(E, N, 32)
    data[:,:latitude] = lat
    data[:,:longitude] = lon
    data[:,:type] = data."4.1 Energieträger" .|> t -> de2type[t]
    rename!(data, "4.2 Installierte Leistung [kW]" => "capacity")
    data[:,:capacity] ./= 1000
    return select(data,[:latitude, :longitude, :type, :capacity])
end
