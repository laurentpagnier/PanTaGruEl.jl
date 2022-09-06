export discard_non_trans!, get_trans_parameters!


function retreave_voltage(bus, trans)
    # NOT WORKING
    v = findall(trans["voltage1"] .== 0) .|>
        id -> findfirst(bus["id"] .== trans["bus_id1"][id]) |>
        id -> bus["voltage"][id]
    println(v)
    trans["voltage1"][trans["voltage1"] .== 0] = v
    
    v = findall(trans["voltage2"] .== 0) .|>
        id -> findfirst(bus["id"] .== trans["bus_id2"][id]) |>
        id -> bus["voltage"][id]
    trans["voltage2"][trans["voltage2"] .== 0] = v
    nothing
end


function discard_non_trans!(
    scenario::Dict{String,DataFrame}
)
    # they are acdc converters
    subset!(scenario["trans"], :is_transformer => is_t -> is_t .== true)
    nothing
end


function get_trans_parameters!(
    scenario::Dict{String,DataFrame};
    r_eff = 2.0,
    x_eff = 55.0,
    fmax = 1000
)
    scenario["trans"].r = r_eff * ones(size(scenario["trans"], 1))
    scenario["trans"].x = x_eff * ones(size(scenario["trans"], 1))
    scenario["trans"].fmax = fmax * ones(size(scenario["trans"], 1))
    nothing
end


