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
