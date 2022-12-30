export get_line_parameters!, allow_full_gen!, reinforce_network!,
    differentiate_line_and_dc_cable!


function get_line_parameters!(
    scenario::Dict{String,DataFrame};
    Rkm = Dict(110 => 0.145, 220 => 0.063, 380 => 0.028, 700 => 0.013),
    Xkm = Dict(110 => 0.4, 220 => 0.36, 380 => 0.265, 700 => 0.28),
    Bkm = Dict(110 => 0.0, 220 => 0.0, 380 => 0.0, 700 => 0.0),
    limit = Dict(110 => 140., 220 => 490., 380 => 1700., 700 => 5400.),
)
    r = Float64[]
    x = Float64[]
    b = Float64[]
    fmax = Float64[]

    for i=1:size(scenario["line"], 1)
        if scenario["line"].voltage[i] == 132
            push!(r, scenario["line"].line_length[i] * Rkm[110])
            push!(x, scenario["line"].line_length[i] * Xkm[110])
            push!(b, scenario["line"].line_length[i] * Bkm[110])
            push!(fmax, limit[110])
    
        elseif scenario["line"].voltage[i] == 220
            push!(r, scenario["line"].line_length[i] * Rkm[220])
            push!(x, scenario["line"].line_length[i] * Xkm[220])
            push!(b, scenario["line"].line_length[i] * Bkm[220])
            push!(fmax, limit[220])
        
        elseif scenario["line"].voltage[i] == 300
            push!(r, scenario["line"].line_length[i] * (Rkm[220] + Rkm[380]) / 2)
            push!(x, scenario["line"].line_length[i] * (Xkm[220] + Xkm[380]) / 2)
            push!(b, scenario["line"].line_length[i] * (Bkm[220] + Bkm[380]) / 2)
            push!(fmax, ceil((limit[220] + limit[380]) / 2))
        
        elseif scenario["line"].voltage[i] == 380
            push!(r, scenario["line"].line_length[i] * Rkm[380])
            push!(x, scenario["line"].line_length[i] * Xkm[380])
            push!(b, scenario["line"].line_length[i] * Bkm[380])
            push!(fmax, limit[380])
                            
        elseif scenario["line"].voltage[i] == 500
            push!(r, scenario["line"].line_length[i] * (Rkm[380] + Rkm[700]) / 2)
            push!(x, scenario["line"].line_length[i] * (Xkm[380] + Xkm[700]) / 2)
            push!(b, scenario["line"].line_length[i] * (Bkm[380] + Bkm[700]) / 2)
            push!(fmax, ceil((limit[380] + limit[700]) / 2))
                                                
        elseif scenario["line"].voltage[i] == 750
            push!(r, scenario["line"].line_length[i] * Rkm[700])
            push!(x, scenario["line"].line_length[i] * Xkm[700])
            push!(b, scenario["line"].line_length[i] * Bkm[700])
            push!(fmax, limit[700])
        else
            push!(r, 0.0)
            push!(x, 0.0)
            push!(b, 0.0)
            push!(fmax, 0.0)
        end
    end
    scenario["line"].r = r
    scenario["line"].x = x
    scenario["line"].b = b
    scenario["line"].fmax = fmax
    nothing
end


function differentiate_line_and_dc_cable!(
    scenario::Dict{String,DataFrame}
)
    scenario["dc_cable"] = subset(scenario["line"], :is_dc => dc -> dc .== true)
    subset!(scenario["line"], :is_dc => dc -> dc .== false)
end


function rectify_line_parameter!(
    scenario::Dict{String,DataFrame};
    xmin = 0.05,
)
    scenario["line"].x .= max.(scenario["line"].x, xmin)
end


function disacard_m220_line!(
    scenario::Dict{String,DataFrame},
)
    subset!(scenario["line"], :voltage => v -> v .>= 220)
    nothing
end


function allow_full_gen!(
    scenario::Dict{String,DataFrame},
)
    max_export = scenario["bus"].id .|>
        id -> findall((scenario["line"].bus_id1 .== id) .|
        (scenario["line"].bus_id2 .== id)) |>
        id -> sum(scenario["line"].circuit[id] .* scenario["line"].fmax[id])

    max_export += scenario["bus"].id .|>
        id -> findall((scenario["trans"].bus_id1 .== id) .|
        (scenario["trans"].bus_id2 .== id)) |>
        id -> sum(scenario["line"].fmax[id])

    max_gen = zeros(size(scenario["bus"],1))
    zip(scenario["gen"].bus_id,scenario["gen"].capacity) .|>
        temp -> max_gen[findfirst(scenario["bus"].id .== temp[1])] += temp[2]
    bus_id = scenario["bus"].id[findall(max_gen .> max_export)]
    for b = bus_id
        i =  findfirst(scenario["bus"].id .== b)
        mg = max_gen[i]
        me = max_export[i]
        id_pick = 0
        while mg > me
            id_l = findall((scenario["line"].bus_id1 .== b) .|
                (scenario["line"].bus_id2 .== b))
            id_sort = sortperm(scenario["line"].fmax[id_l])
            id_pick = id_sort[1]
            scenario["line"].circuit[id_l[id_pick]] += 1
            me += scenario["line"].fmax[id_l[id_pick]]
        end
    end
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

