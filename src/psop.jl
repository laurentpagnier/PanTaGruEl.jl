export create_PSdata, reinforce_network

using PSOP

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
    quad_cost = ("marginal_cost_increase" in names(scenario["gen"])) ? scenario["gen"].marginal_cost_increase : zeros(Ngen)
    #quad_cost = zeros(Ngen)
    on_cost = zeros(Ngen)
    startup_cost = zeros(Ngen)
    shutdown_cost = zeros(Ngen)
    min_on_time = Int64.(zeros(Ngen))
    min_down_time = Int64.(zeros(Ngen))

    return is_line, PSOP.PSdata(gen_loc, wind_loc, min_gen, max_gen, line_id, line_susceptance,
        line_limit, demand, wind, ramping_rate, lin_cost, quad_cost,
        on_cost, startup_cost, shutdown_cost, min_on_time, min_down_time,
        Nbus, Nline, Ngen, Nwind, Nt, sb)
end


function reinforce_network!(
    scenario::Dict{String,DataFrame};
    Niter = 10,
    delta_fmax = 100,
    thres = 0.1
)
    # Here we assume that the system should be able
    # strong enough to run a DC-OPF with record demands
    stressed_scenario = copy_scenario(scenario)
    assign_active_demand!(stressed_scenario, national_demand("record_peak"))
    is_line, ps0 = create_PSdata(stressed_scenario) # initial system
    ps_ref = PSOP.copy_psdata(ps0) # reference (varying) system

    while delta_fmax > 0.01
        ps = PSOP.copy_psdata(ps_ref) # "working" system
        ps.line_limit .+= delta_fmax
        dfmax = delta_fmax
        # here we use a dichotomous approach
        # to find at which point the system becomes infeasible

        for k=1:Niter
            th, gen, lmp = run_std_dc_opf(ps)
            if th == nothing
                ps.line_limit .+= delta_fmax / 2^k
                dfmax += delta_fmax / 2^k
            else
                ps.line_limit .-= delta_fmax / 2^k
                dfmax -= delta_fmax / 2^k
            end
        end
        # the following enssures that it can be solved
        dfmax += delta_fmax/2^(Niter-2)
        ps.line_limit .+= delta_fmax/2^(Niter-2)
        delta_fmax = dfmax
        th, gen, lmp = run_std_dc_opf(ps)
        flow = [ps.line_susceptance[k] * (th[ps.line_id[k,1]] - th[ps.line_id[k,2]]) for k = 1:ps.Nline]
        saturated = findall(abs.(vec(flow)) ./ ps.line_limit .> 0.99)

        new_line_id = Int64.(zeros(0,2))
        new_limit = Float64[]
        new_susceptance = Float64[]
        for k in saturated
            isnew = ! any(new_line_id[:,1] .== ps.line_id[k,1] .& new_line_id[:,2] .== ps.line_id[k,2])
            if isnew
                new_line_id = [new_line_id; ps_ref.line_id[[k],:]]
                push!(new_limit, ps_ref.line_limit[k])
                push!(new_susceptance, ps_ref.line_susceptance[k])
                push!(is_line, is_line[k])
            end
        end
        ps_ref = PSOP.PSdata(ps_ref.gen_loc, ps_ref.wind_loc, ps_ref.min_gen, ps_ref.max_gen, [ps_ref.line_id; new_line_id],
            [ps_ref.line_susceptance; new_susceptance], [ps_ref.line_limit; new_limit], ps_ref.demand, ps_ref.wind, ps_ref.ramping_rate,
            ps_ref.lin_cost, ps_ref.quad_cost, ps_ref.on_cost, ps_ref.startup_cost, ps_ref.shutdown_cost,
            ps_ref.min_on_time, ps_ref.min_down_time, ps_ref.Nbus, ps_ref.Nline + size(new_line_id,1), ps_ref.Ngen, ps_ref.Nwind, ps_ref.Nt, ps_ref.sb)
        
        println("The problem becomes insoluble at delta_fmax: $delta_fmax, $(size(new_line_id,1)) lines added.")
    end
    
    Nnew = ps_ref.Nline - ps0.Nline
    new_line_id = ps_ref.line_id[ps0.Nline+1:end,:]
    new_susceptance = ps_ref.line_susceptance[ps0.Nline+1:end,:]
    new_limit = ps_ref.line_limit[ps0.Nline+1:end,:]
    new_is_line = is_line[ps0.Nline+1:end,:]
    iskept = [true for i = 1:Nnew]
    println("\nRemoving new lines one by one to assess if they are critical:")
    for i=1:Nnew
        iskept[i] = false
        mod(i/Nnew, 0.05) < 0.99/Nnew ? println("$(floor(100*i/Nnew))% of new lines checked") : nothing

        ps = PSOP.PSdata(ps0.gen_loc, ps0.wind_loc, ps0.min_gen,
            ps0.max_gen, [ps0.line_id; new_line_id[iskept,:]],
            [ps0.line_susceptance; new_susceptance[iskept]],
            [ps0.line_limit; new_limit[iskept]], ps0.demand, ps0.wind,
            ps0.ramping_rate, ps0.lin_cost, ps0.quad_cost, ps0.on_cost,
            ps0.startup_cost, ps0.shutdown_cost, ps0.min_on_time,
            ps0.min_down_time, ps0.Nbus, ps0.Nline + sum(iskept),
            ps0.Ngen, ps0.Nwind, ps0.Nt, ps0.sb)
        th, gen, lmp = run_std_dc_opf(ps)
        th == nothing ? iskept[i] = true : iskept[i] = false
    end
    
    for k in findall(iskept)
        if new_is_line[k]
            # for line, we increment the circuit (i.e. number of parallel lines) parameter
            id = new_line_id[k,:] |>
                id -> (scenario["bus"].id[id[1]], scenario["bus"].id[id[2]]) |>
                id -> findfirst((scenario["line"].bus_id1 .== id[1]) .& (scenario["line"].bus_id2 .== id[2])) 
            scenario["line"].circuit[id] += 1
        else
            # for trqansformer, we duplicate it
            id = new_line_id[k,:] |>
                id -> (scenario["bus"].id[id[1]], scenario["bus"].id[id[2]]) |>
                id -> findfirst((scenario["trans"].bus_id1 .== id[1]) .& (scenario["trans"].bus_id2 .== id[2])) 
            append!(scenario["trans"], scenario["trans"][[id],:])
        end
    end
    
    println("$(sum(iskept)) new lines (out of $Nnew) were kept.")
    
end
