export extract_grid_from_polygon, extract_grid_from_country

function extract_connected_grid(
    scenario::Dict{String,DataFrame},
    start = nothing
)
    edge = [
        scenario["line"].bus_id1 scenario["line"].bus_id2;
        scenario["trans"].bus_id1 scenario["trans"].bus_id2
        ]
    if start == nothing
        start = 1
    else
        start = findfirst(scenario["bus"][!,start[1]] .== start[2])
    end
    queue = Vector{Int64}([scenario["bus"].id[start]])
    visited = [false for i=1:size(scenario["bus"],1)]
    visited[start] = true

    while ~isempty(queue) 
        point = popfirst!(queue)
        neighbour = unique([edge[findall(edge[:,1] .== point), 2];
            edge[findall(edge[:,2] .== point), 1]])
        for k = 1:length(neighbour)
            id = findfirst(scenario["bus"].id .== neighbour[k])
            if id != nothing
                if !visited[id]
                    push!(queue, neighbour[k])
                    visited[id] = true
                end
            end
        end
    end

    red_bus = scenario["bus"][visited,:]
     
    is_part_of = scenario["gen"].bus_id .|>
        id -> findfirst(red_bus.id .== id) .|> id -> id != nothing
    red_gen = scenario["gen"][is_part_of,:]
    
    is_part_of = scenario["renew"].bus_id .|>
        id -> findfirst(red_bus.id .== id) .|> id -> id != nothing
    red_renew = scenario["renew"][is_part_of,:]
    
    is_part_of = zip(scenario["line"].bus_id1, scenario["line"].bus_id2) .|>
        id -> id[1] in red_bus.id && id[2] in red_bus.id
    red_line = scenario["line"][is_part_of,:]
    
    is_part_of = zip(scenario["trans"].bus_id1, scenario["trans"].bus_id2) .|>
        id -> id[1] in red_bus.id && id[2] in red_bus.id
    red_trans = scenario["trans"][is_part_of,:]

    return Dict{String,DataFrame}("bus" => red_bus, "gen" => red_gen,
        "line" => red_line, "trans" => red_trans, "renew" => red_renew)
end


function extract_grid_from_polygon(
    scenario::Dict{String,DataFrame},
    poly::Matrix{Float64};
    start = nothing,
    add_neighbour::Bool = true,
)
    coord = [scenario["bus"].longitude scenario["bus"].latitude]
    id0 = findall(in_polygon(coord, poly[:,2:-1:1]))
    s = discard_non_selected_bus(scenario, id0, add_neighbour=add_neighbour)
    return extract_connected_grid(s, start)
end


function extract_grid_from_country(
    scenario::Dict{String,DataFrame},
    country::Vector{String};
    start = nothing,
    add_neighbour::Bool = true,
)
    id0 = findall(scenario["bus"].country .|> c -> c in country)
    s = discard_non_selected_bus(scenario, id0, add_neighbour=add_neighbour)
    return extract_connected_grid(s, start)
end


function discard_non_selected_bus(
    scenario,
    id0;
    add_neighbour::Bool = true,
)
    s = copy_scenario(scenario)
    # add outside neighbours
    if add_neighbour
        edge = [
            scenario["line"].bus_id1 scenario["line"].bus_id2;
            scenario["trans"].bus_id1 scenario["trans"].bus_id2
            ]
        temp = id0 .|> id -> scenario["bus"].id[id] .|>
            id -> [id; edge[edge[:,1] .== id,2]; edge[edge[:,2] .== id,1]] .|>
            id -> findfirst(scenario["bus"].id .== id)
        id = Int64[]
        for i = 1:length(temp)
            append!(id, temp[i])
        end
        
        # set neighbours' country to XX, this prevents demand to be distributed
        # to these buses
        setdiff(id, id0) |> id_neigh -> s["bus"].country[id_neigh] .= "XX"
    else
        id = id0
    end
    delete!(s["bus"], Not(id))
    return s
end
