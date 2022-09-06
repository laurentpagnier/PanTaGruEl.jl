export create_PSdata

# this allows to inferace with the PSOP.jl package

function create_PSdata(scenario; sb = 100)
    
    Nbus = size(scenario["bus"], 1)
    Ngen = size(scenario["gen"], 1)
    Nline = 0
    Nwind = 0
    Nt = 1
    gen_loc = scenario["gen"].bus_id .|>
        b -> findfirst(scenario["bus"].id .== b)
    wind_loc = Int64[]
    min_gen = zeros(size(scenario["gen"],1))
    max_gen = scenario["gen"].capacity / sb
    
    line_id = Int64.(zeros(0,2))
    line_susceptance = Float64[]
    line_limit = Float64[]
    is_line = Bool[]
    for k=1:size(scenario["line"],1)
        for _  = 1:scenario["line"].circuit[k]
            id1 = findfirst(scenario["bus"].id .== scenario["line"].bus_id1[k])
            id2 = findfirst(scenario["bus"].id .== scenario["line"].bus_id2[k])
            line_id = [line_id; id1 id2]
            b = scenario["line"].voltage[k]^2 / scenario["line"].x[k] / sb
            push!(line_susceptance, b)
            push!(line_limit, scenario["line"].fmax[k] / sb)
            push!(is_line, true)
            Nline += 1
        end
    end
    
    for k=1:size(scenario["trans"],1)
        id1 = findfirst(scenario["bus"].id .== scenario["trans"].bus_id1[k])
        id2 = findfirst(scenario["bus"].id .== scenario["trans"].bus_id2[k])
        line_id = [line_id; id1 id2]
        v = max(scenario["trans"].voltage1[k], scenario["trans"].voltage2[k])
        b = v^2 / scenario["trans"].x[k] / sb
        push!(line_susceptance, b)
        push!(line_limit, scenario["trans"].fmax[k] / sb)
        push!(is_line, false)
        Nline += 1
    end
    demand = reshape(scenario["demand"].active, Nbus, 1) / sb
    wind = zeros(0,0)
    ramping_rate = zeros(Nbus) # in pu/hour
    lin_cost = Float64.(scenario["gen"].marginal_cost)
    quad_cost = zeros(Ngen)
    on_cost = zeros(Ngen)
    startup_cost = zeros(Ngen)
    shutdown_cost = zeros(Ngen)
    min_on_time = Int64.(zeros(Ngen))
    min_down_time = Int64.(zeros(Ngen))

    return is_line, PSdata(gen_loc, wind_loc, min_gen, max_gen, line_id, line_susceptance,
        line_limit, demand, wind, ramping_rate, lin_cost, quad_cost,
        on_cost, startup_cost, shutdown_cost, min_on_time, min_down_time,
        Nbus, Nline, Ngen, Nwind, Nt, sb)
end
