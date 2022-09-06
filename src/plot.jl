export create_map


function create_map(
    filename::String,
    scenario::Dict{String, DataFrame};
    shape::Vector{Matrix{Float64}} = Matrix{Float64}[],
)
    coord = mercator([scenario["bus"].longitude scenario["bus"].latitude])
    s = Matrix{Float64}[]
    for i=1:length(shape)
        push!(s, mercator(shape[i]))
    end
    e1 = scenario["line"].bus_id1 .|> b -> findfirst(scenario["bus"].id .== b) 
    e2 = scenario["line"].bus_id2 .|> b -> findfirst(scenario["bus"].id .== b)
    ec = repeat(["#000000"], size(scenario["line"], 1), 1)
    ec[scenario["line"].voltage .== 220] .= "#00751a"
    ec[scenario["line"].voltage .== 380] .= "#ff0000"
    ew = copy(scenario["line"].circuit)
    svg_graph(filename, coord, [e1 e2], shape = s, edge_color = ec, edge_width = ew)
end


function svg_graph(
    filename::String,
    node_coord::Matrix{<:Number},
    edge::Matrix{Int64};
    node_radius = [1.0],
    edge_width = [1.0],
    node_color = ["#000000"],
    edge_color = ["#000000"],
    sizes = (950, 800, 30),
    shape::Vector{Matrix{Float64}} = Matrix{Float64}[], 
)
    x = node_coord[:,1]
    y = node_coord[:,2]
    
    x_min = minimum(x)
    x_max = maximum(x)
    y_min = minimum(y)
    y_max = maximum(y)
    
    width, height, margin = sizes
    
    length(node_color) <= 1 ? node_color = repeat(node_color, length(x)) : nothing
    length(edge_color) <= 1 ? edge_color = repeat(edge_color, size(edge, 1)) : nothing
    length(edge_width) <= 1 ? edge_width = repeat(edge_width, size(edge, 1)) : nothing
    length(node_radius) <= 1 ? node_radius = repeat(node_radius, length(x)) : nothing

    if(width / height < (x_max - x_min) / (y_max - y_min))
        dx = (width - 2*margin) / (x_max - x_min)
        xoff = 0;
    else
        dx = (height - 2*margin) / (y_max - y_min);
        xoff = 0
    end

    fid = open(filename, "w")
    write(fid,"<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" width=\"$width\" height=\"$height\">\n")
    
    for i = 1:length(shape)
        write(fid, "<polygon points=\"")
        for k=1:size(shape[i], 1)
            x1 = dx * (shape[i][k,1] - x_min) + margin + xoff
            y1 = dx * (shape[i][k,2] - y_min) - height + margin
            write(fid, "$x1,$(-y1) ")
        end
        write(fid, "\" style=\"fill:none;stroke:black;stroke-width:1\" />")
    end
    for i = 1:size(edge,1)
        if edge_width[i] > 0
            x1 = dx * (x[edge[i,1]] - x_min) + margin + xoff
            y1 = dx * (y[edge[i,1]] - y_min) - height + margin
            x2 = dx * (x[edge[i,2]] - x_min) + margin + xoff
            y2 = dx * (y[edge[i,2]] - y_min) - height + margin
            write(fid, "<line x1=\"$x1\" y1=\"$(-y1) \" x2=\"$x2\" y2=\"$(-y2)\" style=\"stroke:$(edge_color[i]);stroke-width: $(edge_width[i]) \" />\n")
        end
    end
    
    for i = 1:length(x)
        if node_radius[i] > 0
            xb = dx * (x[i] - x_min) + margin + xoff
            yb = dx * (y[i] - y_min) - height + margin
            write(fid, "<circle cx=\"$xb\" cy=\"$(-yb)\" r=\"$(node_radius[i])\" fill=\" $(node_color[i]) \" stroke=\"black\" stroke-width=\"0.0\" />\n")
        end
    end
    write(fid, "</svg>")
    close(fid)
    nothing
end
