export copy_scenario, reindexing!

function in_polygon(
    p::Matrix{Float64},
    poly::Matrix{Float64},
)
    N = size(poly, 1)
    isin = falses(size(p, 1))
    for k = 1:size(p, 1)
        j = N
        for i = 1:N
            if (
                ((poly[i, 2] < p[k, 2]) & (poly[j, 2] >= p[k, 2])) |
                ((poly[j, 2] < p[k, 2]) & (poly[i, 2] >= p[k, 2]))
            )
                if (
                    poly[i, 1] +
                    (p[k, 2] - poly[i, 2]) / (poly[j, 2] - poly[i, 2]) *
                    (poly[j, 1] - poly[i, 1]) < p[k, 1]
                )
                    isin[k] = !isin[k]
                end
            end
            j = i
        end
    end
    return isin
end


function mercator(
    coord::Matrix{<:Number};
    long0::Number = 0,
    R::Number = 1,
)
    lon = coord[:,1]
    lat = coord[:,2]
    x = R * pi * (lon .- long0) / 180
    y = R * log.(tan.(pi/4 .+ lat * pi / 360))
    return [x y]
end


function copy_scenario(scenario::Dict{String,DataFrame})
    copied_scenario = Dict{String,DataFrame}()
    for k in keys(scenario)
        copied_scenario[k] = copy(scenario[k])
    end
    return copied_scenario
end


function create_dir(dirname)
    if !isdir(dirname)
        mkpath(dirname)
    end
end


function reindexing!(scenario::Dict{String,DataFrame})
    id = copy(scenario["bus"].id)
    scenario["bus"].id = 1:length(id)
    to_new_id = Dict(id .=> 1:length(id))
    scenario["line"].bus_id1 = scenario["line"].bus_id1 .|> id -> to_new_id[id]
    scenario["line"].bus_id2 = scenario["line"].bus_id2 .|> id -> to_new_id[id]
    scenario["trans"].bus_id1 = scenario["trans"].bus_id1 .|> id -> to_new_id[id]
    scenario["trans"].bus_id2 = scenario["trans"].bus_id2 .|> id -> to_new_id[id]
    scenario["gen"].bus_id = scenario["gen"].bus_id .|> id -> to_new_id[id]
    scenario["renew"].bus_id = scenario["renew"].bus_id .|> id -> to_new_id[id]
    nothing
end


function get_distance(coord1::Matrix{Float64}, coord2::Matrix{Float64})
    Rearth = 6371.0
    dlat = pi * ( repeat(coord1[:,2], 1, size(coord2,1)) 
        - repeat(coord2[:,2]', size(coord1,1), 1)) / 180
    dlon = pi * (repeat(coord1[:,1], 1, size(coord2,1)) 
        - repeat(coord2[:,1]', size(coord1,1), 1)) / 180
    a = sin.(dlat/2).^2 + cos.(repeat(coord1[:,2], 1, size(coord2,1)) * pi/180) .*
        cos.(repeat(coord2[:,2]', size(coord1,1), 1)*pi/180) .* sin.(dlon / 2).^2
    c = 2 * atan.(sqrt.(a), sqrt.(1 .- a))
    return Rearth * c
end

