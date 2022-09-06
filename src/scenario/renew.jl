export add_french_renew!, add_german_renew!

function add_french_renew!(
    source_folder::String,
    scenario::Dict{String,DataFrame};
    dmax = 50,
)
    data = load_datagouvfr_data(source_folder)
    add_renew!(scenario, data, dmax = 50, country = "FR")
end


function add_german_renew!(
    source_folder::String,
    scenario::Dict{String,DataFrame};
    dmax = 50,
)
    data = load_bundesnetzagentur_data(source_folder)
    add_renew!(scenario, data, dmax = 50, country = "DE")
end


function add_renew!(
    scenario::Dict{String,DataFrame},
    data::DataFrame;
    dmax = 50,
    country = "XX",
)
    coord1 = [scenario["bus"].longitude scenario["bus"].latitude]
    coord2 = [data.longitude data.latitude]
    
    PV = Dict{Int64, Float64}()
    WD = Dict{Int64, Float64}()

    for i = 1:size(coord2, 1)
        dist, id = findmin(vec(get_distance(coord1, coord2[[i],:])))
        bus_id = scenario["bus"].id[id]
        if dist < dmax 
            if data.type[i] == "PV"
                if bus_id in keys(PV)
                    PV[bus_id] += data.capacity[i]
                else
                    PV[bus_id] = data.capacity[i]
                end
            elseif data.type[i] == "WD"
                if bus_id in keys(WD)
                    WD[bus_id] += data.capacity[i]
                else
                    WD[bus_id] = data.capacity[i]
                end
            end
        end
    end
    
    wd = DataFrame()
    wd[:,:bus_id] = Int64.(keys(WD))
    wd[:,:capacity] = keys(WD) .|> k -> WD[k]
    wd[:,:country] .= country
    wd[:,:type] .= "WD"
    wd[:,:category] .= "R"
    wd[:,:longitude] = keys(WD) .|> k -> findfirst(scenario["bus"].id .== k) |>
        id -> scenario["bus"].longitude[id]
    wd[:,:latitude] = keys(WD) .|> k -> findfirst(scenario["bus"].id .== k) |>
        id -> scenario["bus"].latitude[id]
    wd[:,:name] = ["Wind $country $i" for i=1:length(WD)]
    wd[:,:long_type] = ["wind" for i=1:length(WD)]

    pv = DataFrame()
    pv[:,:bus_id] = Int64.(keys(PV))
    pv[:,:capacity] = keys(PV) .|> k -> PV[k]
    pv[:,:country] .= country
    pv[:,:type] .= "PV"
    pv[:,:category] .= "R"
    pv[:,:longitude] = keys(PV) .|> k -> findfirst(scenario["bus"].id .== k) |>
        id -> scenario["bus"].longitude[id]
    pv[:,:latitude] = keys(PV) .|> k -> findfirst(scenario["bus"].id .== k) |>
        id -> scenario["bus"].latitude[id]
    pv[:,:name] = ["Solar $country $i" for i=1:length(PV)]
    pv[:,:long_type] = ["solar" for i=1:length(PV)]
    
    append!(scenario["renew"], wd)
    append!(scenario["renew"], pv)
    nothing
end
