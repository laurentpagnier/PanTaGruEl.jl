function download_naturalearth_data(source_folder; scale = 50)
    create_dir("$source_folder/naturalearth")
    download("https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/$(scale)m/cultural/ne_$(scale)m_admin_0_countries_lakes.zip",
        "$(source_folder)/naturalearth/ne_$(scale).zip")
    run(`unzip -o $(source_folder)/naturalearth/ne_$(scale).zip -d $source_folder/naturalearth/`)
end


function get_borders(source_folder, scale = 50)
    table = Shapefile.Table("$source_folder/naturalearth/ne_$(scale)m_admin_0_countries_lakes.shp")
    table = DataFrame(table)
    label = table.SU_A3 .|>  a -> begin
        try l3_to_l2[a]
        catch l2
            if typeof(l2) == KeyError
                return "XX"
            else
                return l2
            end
        end
    end
    borders = Dict{String,Vector{Matrix{Float64}}}()
    for i=1:size(table,1)
        temp = table.geometry[i].points .|> p -> (p.x, p.y)
        coord = zeros(0,2)
        for i=1:length(temp)
            coord = [coord; temp[i][1] temp[i][2]]
        end
        d = coord[2:end,:] - coord[1:end-1,:]
        d = d[:,1].^2 + d[:,2].^2
        thres = max(10. * sum(d) / length(d), 1)
        id_cut = [0;findall(d .> thres); size(coord,1)]
        chunk = Matrix{Float64}[]
        for i=2:length(id_cut)
           push!(chunk, coord[id_cut[i-1]+1:id_cut[i],:]) 
        end
        borders[label[i]] = chunk
    end
    return borders
end

