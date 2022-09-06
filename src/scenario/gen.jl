export assign_simple_type_to_gen!, assign_marginal_cost!, differentiate_gen_and_renew!,
    assign_ramping_rate!, remove_gen_duplicate!, remove_neg_gen!, large_gen_on_380!,
    set_gen_damping!, set_gen_inertia!, assign_inertia_constant!,
    crosscheck_with_wri!
    


simple_type = Dict("biomass" => ("BM", "O"), "biomass_cons" => ("BM", "O"),
"fossil_brown_lignite" => ("LI", "C"), "fossil_brown_lignite_cons" => ("LI", "C"),
"fossil_coal_gas" => ("CG", "G"), "fossil_coal_gas_cons" => ("CG", "G"),
"fossil_coal_hard" => ("HC", "C"), "fossil_coal_hard_cons" => ("HC", "C"),
"fossil_mixed" => ("FM", "F"), "fossil_mixed_cons" => ("FM", "F"),
"fossil_oil" => ("FO", "F"), "fossil_oil_shale" => ("FO", "F"),
"fossil_oil_other" => ("FO", "F"), "fossil_oil_peat" => ("FO", "F"),
"hydro_mixed" => ("HY", "H"), "hydro_mixed_cons" => ("HY", "H"),
"hydro_pure_ps" => ("PS", "H"), "hydro_pure_storage" => ("DA", "H"),
"hydro_pure_storage_cons" => ("DA", "H"), "hydro_ror" => ("RR", "H"),
"nuclear" => ("NU", "N"), "nuclear_cons" => ("NU", "N"),
"other_nl" => ("OT", "O"), "other_nl_cons" => ("OT", "O"),
"other_nrenew" => ("OT", "O"), "other_nrenew_cons" => ("OT", "O"),
"other_renew" => ("OT", "O"), "solar_pv" => ("PV", "R"),
"solar_thermal" => ("SO", "R"), "waste_nr" => ("WA", "O"),
"wind" => ("WD", "R"), "wind_cons" => ("WD", "R"), "converter_b2b" => ("XX","X"),
"power_plus_sub" => ("XX","X"), "Null" => ("XX","X"), "fossil_other" => ("FO","F"),
"fossil_peat" => ("FO","F"))


function assign_simple_type_to_gen!(
    scenario::Dict{String,DataFrame};
    simple_type = simple_type
)
    st = scenario["gen"].long_type .|> t -> simple_type[t]
    scenario["gen"].type = [st[i][1] for i=1:length(st)]
    scenario["gen"].category = [st[i][2] for i=1:length(st)]
    nothing
end


function assign_marginal_cost!(
    scenario::Dict{String,DataFrame};
    mc = Dict("BM" => 10, "DA" => 80, "FM" => 100, "FO" => 100,
    "HC" => 35, "HY" => 60, "LI" => 24, "NU" => 16, "OT" => 10,
    "PS" => 100, "RR" => 10, "WA" => 10, "CG" => 110, "WD" => 0,
    "XX" => 0.0, "PV" => 0., "SO" => 0., "GT" => 0.)
)
    scenario["gen"].marginal_cost = scenario["gen"].type .|> t -> mc[t]  
    nothing
end


function differentiate_gen_and_renew!(
    scenario::Dict{String,DataFrame}
)
    renew = ["PV", "WD", "SO"]
    scenario["renew"] = subset(scenario["gen"],
        :type => t -> t.|> t -> t in renew)
    subset!(scenario["gen"],
        :type => t -> t .|> t -> !(t in renew))
end


function assign_ramping_rate!(
    scenario::Dict{String,DataFrame};
    rr = Dict("BM" => 0.05, "DA" => 1., "FM" => 1., "FO" => 1., "HC" => 0.2,
    "HY" => 1., "LI" => 0.1, "NU" => 0.05, "OT" => 0.05, "PS" => 1.,
    "RR" => 1., "WA" => 0.05, "CG" => 1., "WD" => 1., "XX" => 0., "PV" => 0.,
    "SO" => 0., "GT" => 0.05)
)
    scenario["gen"][!,:ramping_rate] = zip(scenario["gen"].type,
        scenario["gen"].capacity) .|> p -> rr[p[1]] * p[2] 
    nothing
end


function remove_gen_duplicate!(
    scenario::Dict{String,DataFrame}
)
     scenario["gen"] = scenario["gen"][unique(scenario["gen"].name) .|>
        n -> findfirst(scenario["gen"].name .== n), :]
end


function large_gen_on_380!(
    scenario::Dict{String,DataFrame},
    pmin = 500.0,
)
    idlarge = findall(scenario["gen"].capacity .> pmin)
    id = scenario["gen"].bus_id[idlarge] .|>
        id -> findfirst(scenario["bus"].id .== id)
    for i = 1:length(id)
        if scenario["bus"].voltage[id[i]] < 380 
            id2 = findall(scenario["bus"].name .== scenario["bus"].name[id[i]]) |>
                id -> scenario["bus"].voltage[id] |> v -> findfirst(v .>= 380)
            if id2 != nothing
                id2 = findall(scenario["bus"].name .== scenario["bus"].name[id[i]])[id2]
                scenario["gen"].bus_id[idlarge[i]] = scenario["bus"].id[id2]
            end
        end
    end
end


function assign_inertia_constant!(
    scenario::Dict{String,DataFrame};
    H = Dict("BM" => 0, "CG" => 6, "DA" => 4, "FM" => 6, "FO" => 6, "HC" => 6,
        "HY" => 3, "LI" => 6, "PS" => 3, "NU" => 6, "OT" => 3,
        "RR" => 3, "LO" => 0, "WA" => 3, "WD" => 0, "XX" => 0,
        "PV" => 0, "SO" => 0, "GT" => 6)
)
    scenario["gen"].H = scenario["gen"].type .|> t -> Float64(H[t])
    nothing
end


function remove_neg_gen!(
    scenario::Dict{String, DataFrame};
    dryrun = false,
)
    if dryrun
        println(subset(scenario["gen"], :capacity => p -> p .<= 0))
    else
        subset!(scenario["gen"], :capacity => p -> p .> 0)
    end
    nothing
end


function set_gen_inertia!(
    scenario::Dict{String,DataFrame};
    freq = 50.0
)
    inertia = scenario["gen"].H .* scenario["gen"].capacity ./ (pi * freq)
    scenario["gen"].inertia = inertia 
    nothing
end


function set_gen_damping!(gen; Vs = 1, X = 0, Xdp = 0.39,
    Xdpp = 0.28, Xqp = 0.52, Xqpp = 0.32, Tdpp = 0.028,
    Tqpp = 0.058, delta = 0/180*pi)
    damping = zeros(length(gen["id"])); 
    # damping bialek p.174 and table p. 139
    for i=1:length(gen["id"])
        if !(gen["id"][i] in ["WD", "SO", "PV", "XX"])
            damping[i] = Vs^2 * ((Xdp-Xdpp)^2/(X + Xdp) * Xdp/Xdpp*Tdpp*sin(delta)^2
                + (Xqp - Xqpp)^2/(X + Xqp) * Xqp/Xqpp*Tqpp*cos(delta)^2) * gen["power"][i]
        end
    end
    gen["damping"] = damping
    nothing
end



function crosscheck_with_wri!(
    source_folder,
    scenario;
    dthres = 10,
    dryrun = false,
)
    wri = load_wri_data(source_folder)
    country = unique(scenario["bus"].country)
    gen = subset(wri, :country => c -> c .|> c -> c in country,
        :type => t -> t .|> t -> !(t in ["Solar", "Wind", "Storage"]))
    
    coord_1 = [scenario["gen"].longitude scenario["gen"].latitude]
    coord_b = [scenario["bus"].longitude scenario["bus"].latitude]
    coord_2 = [gen.longitude  gen.latitude]
    row = Dict{String,Any}()
    for n in names(scenario["gen"])
        if typeof(scenario["gen"][:,n]) == Vector{Int64}
            row[n] = -1
        elseif typeof(scenario["gen"][:,n]) == Vector{Float64}
            row[n] = -1.0
        elseif typeof(scenario["gen"][:,n]) == Vector{String}
            row[n] = ""
        elseif typeof(scenario["gen"][:,n]) == Vector{Bool}
            row[n] = ""
        end
    end
    for i=1:size(gen, 1)
        _ , id = findmin(get_distance(coord_b, coord_2[[i],:]))
        row["bus_id"] = scenario["bus"].id[id]
        row["name"] = gen.name[i]
        row["country"] = gen.country[i]
        row["long_type"] = gen.type[i]
        row["capacity"] = gen.capacity[i]
        row["longitude"] = gen.longitude[i]
        row["latitude"] = gen.latitude[i]
        row["type"]= wri_type_to_simple[gen.type[i]][1]
        row["category"] = wri_type_to_simple[gen.type[i]][2]
        if !isempty(coord_1)
            dmin, id = findmin(get_distance(coord_1, coord_2[[i],:]))
            if dmin > dthres
                dryrun ? println(row) : append!(scenario["gen"], row)
            end
        else
            dryrun ? println(row) : append!(scenario["gen"], row)
        end
    end
end
