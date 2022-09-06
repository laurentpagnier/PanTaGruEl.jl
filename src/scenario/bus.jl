export retreave_country!, assign_bus_type!, distribute_population!


function retreave_country!(
    source_folder::String,
    scenario::Dict{String,DataFrame},
    scale=50
)
    borders = get_borders(source_folder, scale)
    id_missing = findall(scenario["bus"].country .== "XX")
    coord = [scenario["bus"].longitude[id_missing] scenario["bus"].latitude[id_missing]]
    for k in keys(borders)
        for i=1:length(borders[k])
            id = in_polygon(coord, borders[k][i])
            scenario["bus"].country[id_missing[id]] .= k
        end
    end
end


function assign_bus_type!(
    scenario::Dict{String,DataFrame}
)
    t = repeat(["PQ"], size(scenario["bus"],1))
    scenario["gen"].bus_id .|>
        b -> findfirst(scenario["bus"].id .== b) |> i -> t[i] = "PV"     
    id = findmax(scenario["gen"].capacity)[2] |>
        id -> findfirst(scenario["bus"].id .== scenario["gen"].bus_id[id])
    t[id] = "Vθ"
    scenario["bus"].type = t
    nothing
end


function distribute_population!(
    source_folder::String,
    scenario::Dict{String,DataFrame};
    region = "",
    avg_dist = 50.0,
    max_dist = 100.0,
    enforce_country = true,
)
    
    cities1000 = load_geonames_data(source_folder, region = region)
    
    population = zeros(size(scenario["bus"],1))
    coord1 = [scenario["bus"].longitude scenario["bus"].latitude] 
    coord2 = [cities1000.longitude cities1000.latitude] 
    
    country = unique(scenario["bus"].country)

    for i=1:size(cities1000, 1) 
        
        mod(i,10000) == 0 ? println("$i locations checked") : nothing
        
        if enforce_country
            if cities1000.country[i] in country
                id_c = findall(scenario["bus"].country .== cities1000.country[i])
                dist = vec(get_distance(coord1[id_c,:], coord2[[i],:]))
                id = findall(dist .<= avg_dist)
                if !isempty(id)
                    v = scenario["bus"].voltage[id_c[id]]
                    weight = 1*(v .== 220) + 3*(v .== 380) + 3*(v .== 300) + 0.5*(v .== 220) .+ 1E-9
                    population[id_c[id]] .+= weight*cities1000.population[i] / sum(weight)
                else
                    d, id = findmin(dist)
                    if(d < max_dist)
                        population[id_c[id]] += cities1000.population[i]
                    end
                end
            end
        else
            dist = vec(get_distance(coord1, coord2[[i],:]))
            id = findall(dist .<= max_dist)
            if !isempty(id)
                v = scenario["bus"].voltage[id]
                weight = 1*(v .== 220) + 3*(v .== 380) + 3*(v .== 300) + 0.5*(v .== 220) .+ 1E-9
                population[id] .+= weight*cities1000.population[i] / sum(weight)

            end
        end
    end
    scenario["bus"].population = population
    nothing
end
