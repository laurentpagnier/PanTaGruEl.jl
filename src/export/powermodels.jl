function export_powermodels(
    file::String,
    scenario::Dict{String, DataFrame};
    name::String="",
    Sb = 100,
    vmax = 1.1,
    vmin = 0.9,
    extended = false)
    exp = Dict{String, Any}()

    # Make a deepcopy of the scenario because of inplace sorting
    scenario_cp = deepcopy(scenario)

    exp["baseMVA"] = Sb
    if name != ""
        exp["name"] = name
    else
        exp["name"] = split(file, '/')[end]
    end
    exp["per_unit"] = true

    # Status: 0 off, 1 on

    six = sortperm(scenario_cp["bus"][!, "id"])
    scenario_cp["bus"] = scenario_cp["bus"][six, :]
    exp["bus"] = Dict{String, Any}()
    for row in eachrow(scenario_cp["bus"])
        id = row["id"]
        ix = string(id) # PowerModels require the key of the bus to be the same as is its index
        exp["bus"][ix] = Dict{String, Any}()
        exp["bus"][ix]["name"] = row["name"]
        exp["bus"][ix]["index"] = id
        exp["bus"][ix]["status"] = 1
        exp["bus"][ix]["coord"] = (row["longitude"], row["latitude"])
        exp["bus"][ix]["population"] = row["population"]
        exp["bus"][ix]["vmin"] = vmin
        exp["bus"][ix]["vmax"] = vmax
        exp["bus"][ix]["vm"] = 1.
        exp["bus"][ix]["base_kv"] = row["voltage"]
        exp["bus"][ix]["bus_type"] = get_matpower_type(row["type"])
        exp["bus"][ix]["country"] = row["country"]
    end

    scenario_cp["demand"] = scenario_cp["demand"][six, :]
    id = 1
    exp["load"] = Dict{String, Any}()
    for (i, row) in enumerate(eachrow(scenario_cp["demand"]))
        if row["active"] == 0 && row["reactive"] == 0
            continue
        end
        ix = string(id)
        exp["load"][ix] = Dict{String, Any}()
        exp["load"][ix]["status"] = 1
        exp["load"][ix]["index"] = i
        exp["load"][ix]["pd"] = row["active"] / Sb
        exp["load"][ix]["qd"] = row["reactive"] / Sb
        exp["load"][ix]["load_bus"] = scenario_cp["bus"][i, :]["id"]
        if extended
            exp["load"][ix]["load_coefficient"] = row["freq coeff"] / Sb
        end
        id += 1
    end
    sort!(scenario_cp["gen"], :bus_id)
    id = 1
    exp["gen"] = Dict{String, Any}()
    quad = "marginal_cost_increase" in names(scenario_cp["gen"])
    for (i, row) in enumerate(eachrow(scenario_cp["gen"]))
        if (row["type"]  in ["WD", "XX", "SO", "PV"])
            exp["bus"][string(row["bus_id"])]["bus_type"] = 1
        else
            ix = string(id)
            exp["gen"][ix] = Dict{String, Any}()
            exp["gen"][ix]["gen_status"] = 1
            exp["gen"][ix]["index"] = i
            exp["gen"][ix]["pmin"] = 0.
            exp["gen"][ix]["pmax"] = row["capacity"] / Sb
            exp["gen"][ix]["qmin"] = -0.5 * row["capacity"] / Sb
            exp["gen"][ix]["qmax"] = 0.5 * row["capacity"] / Sb
            exp["gen"][ix]["gen_bus"] = row["bus_id"]
            exp["gen"][ix]["mbase"] = Sb
            exp["gen"][ix]["type"] = row["long_type"]
            exp["gen"][ix]["vg"] = 1.
            exp["gen"][ix]["model"] = 2 # Polynomial
            if quad
                exp["gen"][ix]["ncost"] = 3
                exp["gen"][ix]["cost"] = (row["marginal_cost"], row["marginal_cost_increase"], 0) .* Sb
            else 
                exp["gen"][ix]["ncost"] = 2
                exp["gen"][ix]["cost"] = (row["marginal_cost"], 0)  .* Sb
            end
            if extended
                exp["gen"][ix]["inertia"] = row["H"] / Sb
                exp["gen"][ix]["primary"] = row["damping"] / Sb 
            end
            id += 1
        end
    end

    # Do some sorting of the lines first
    for row in eachrow(scenario_cp["line"])
        if row["bus_id1"] > row["bus_id2"]
            row["bus_id1"], row["bus_id2"] = row["bus_id2"], row["bus_id1"]
        end
    end
    sort!(scenario_cp["line"], ["bus_id1", "bus_id2"])
    exp["branch"] = Dict{String, Any}()
    id = 1
    for (i, row) in enumerate(eachrow(scenario_cp["line"]))
        for _ in 1:row["circuit"]
            ix = string(id)
            exp["branch"][ix] = Dict{String, Any}()
            exp["branch"][ix]["br_status"] = 1
            exp["branch"][ix]["f_bus"] = row["bus_id1"]
            exp["branch"][ix]["t_bus"] = row["bus_id2"]
            exp["branch"][ix]["br_r"] = row["r"] * Sb / row["voltage"]^2
            exp["branch"][ix]["br_x"] = row["x"] * Sb / row["voltage"]^2
            exp["branch"][ix]["b_to"] = row["b"] * Sb / row["voltage"]^2 / 2
            exp["branch"][ix]["b_fr"] = row["b"] * Sb / row["voltage"]^2 / 2
            exp["branch"][ix]["g_to"] = 0.
            exp["branch"][ix]["g_fr"] = 0.
            exp["branch"][ix]["tap"] = 1.
            exp["branch"][ix]["shift"] = 0.
            exp["branch"][ix]["transformer"] = false
            exp["branch"][ix]["angmin"] = -π/3 # -π/2
            exp["branch"][ix]["angmax"] = π/3 # π/2
            exp["branch"][ix]["rate_a"] = row["fmax"] / Sb
            exp["branch"][ix]["index"] = id
            id += 1
        end
    end
    # Add the transformers
    # Sorting first
    for row in eachrow(scenario_cp["trans"])
        if row["bus_id1"] > row["bus_id2"]
            row["bus_id1"], row["bus_id2"] = row["bus_id2"], row["bus_id1"]
        end
    end
    sort!(scenario["trans"], ["bus_id1", "bus_id2"])
    for (i, row) in enumerate(eachrow(scenario_cp["trans"]))
        ix = string(id)
        exp["branch"][ix] = Dict{String, Any}()
        v = max(scenario["trans"].voltage1[i], scenario["trans"].voltage2[i])
        exp["branch"][ix]["br_status"] = 1
        exp["branch"][ix]["f_bus"] = row["bus_id1"]
        exp["branch"][ix]["t_bus"] = row["bus_id2"]
        exp["branch"][ix]["br_r"] = row["r"] * Sb / v^2
        exp["branch"][ix]["br_x"] = row["x"] * Sb / v^2
        exp["branch"][ix]["b_to"] = 0.
        exp["branch"][ix]["b_fr"] = 0.
        exp["branch"][ix]["g_to"] = 0.
        exp["branch"][ix]["g_fr"] = 0.
        exp["branch"][ix]["tap"] = 1.
        exp["branch"][ix]["shift"] = 0.
        exp["branch"][ix]["transformer"] = true
        exp["branch"][ix]["angmin"] = -π/3 # -π/2
        exp["branch"][ix]["angmax"] = π/3 # π/2
        exp["branch"][ix]["rate_a"] = row["fmax"] / Sb
        exp["branch"][ix]["index"] = id
        id += 1
    end

    exp["shunt"] = Dict{String, Any}()
    exp["storage"] = Dict{String, Any}()
    exp["switch"] = Dict{String, Any}()
    exp["dcline"] = Dict{String, Any}()

    open("$file.json", "w") do io
        JSON3.pretty(io, exp)
    end
end