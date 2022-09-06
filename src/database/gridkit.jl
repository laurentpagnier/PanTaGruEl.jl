export load_gridkit_data


function download_gridkit_data(source_folder::String)
    create_dir("$source_folder/gridkit")
    download("https://zenodo.org/record/55853/files/entsoe.zip","$source_folder/gridkit/entsoe.zip")
    run(`unzip -o $source_folder/gridkit/entsoe.zip -d $source_folder/gridkit/`)
end


function load_gridkit_data(source_folder::String)
    return Dict{String, DataFrame}("bus" => load_gridkit_bus(source_folder),
        "gen" => load_gridkit_gen(source_folder),
        "line" => load_gridkit_line(source_folder),
        "trans" => load_gridkit_trans(source_folder))
end


function load_gridkit_bus(source_folder::String)
    fid = Base.open("$source_folder/gridkit/buses.csv")

    textline = readline(fid)

    country_tag = String[]
    type_tag = String[]
    name_tag = String[]
    index_tag = Int64[]
    annotation = String[]
    voltage = Float64[]
    is_substation = Bool[]
    coord = "["
    k = 1
    while !eof(fid)
        textline = readline(fid)
        id_q = findall("\"", textline) .|> (x) -> x[1]
        id_p = findall(")", textline) .|> (x) -> x[1]
        id_c = findall(",", textline) .|> (x) -> x[1]
        
        id = findfirst("\"country\"=>\"", textline)
        if id != nothing
            id = id[1] + 12
            id = id:(id_q[findfirst(id_q .> id)] - 1)
            push!(country_tag, textline[id])
        else
            push!(country_tag, "XX")
        end
        
        id = findfirst("\"name_eng\"=>\"", textline)
        if id != nothing
            id = id[1] + 13
            id2 = findfirst(id_q .> id)
            if id2 != nothing
                global name = ""
                try
                    name = textline[id:id_q[id2]-1]
                catch
                    name = textline[id:id_q[id2]-2]
                end
                if !contains(name, "unknown")
                    push!(name_tag, name)
                else
                    push!(name_tag, "Unnamed $k")
                    k += 1
                end
            else
                push!(name_tag, "Unnamed $k")
                k += 1
            end
        else
            push!(name_tag, "Unnamed $k")
            k += 1
        end
        
        id = findfirst("\"mb_symbol\"=>\"", textline)
        if id != nothing
            id = id[1] + 14
            id = id:(id_q[findfirst(id_q .> id)] - 1)
            push!(type_tag, textline[id])
        else
            push!(type_tag, "Null")
        end
        
        id = findfirst("\"annotation\"=>\"", textline)
        if id != nothing
            id = id[1] + 15
            id2 = findfirst(id_q .> id)
            if id2 != nothing
                id2 = id_q[id2]
                try push!(annotation, textline[id:id2-1])
                catch
                    push!(annotation, textline[id:id2-2])
                end
            else
                push!(annotation, "Null")
            end
        else
            push!(annotation, "Null")
        end
        
        push!(index_tag, parse(Int64, textline[1:id_c[1]-1]))
        v = textline[id_c[2]+1:id_c[3]-1]
        !isempty(v) ? push!(voltage, parse(Float64,v)) : push!(voltage, 0.0)   
        
        contains(textline[id_c[4]+1:id_c[5]-1], "station") ? push!(is_substation, true) :
            push!(is_substation, false)
        
        id = findfirst("POINT(", textline)[1] + 6
        id = id:(id_p[findfirst(id_p .> id)] - 1)
        coord *= textline[id] * " "
    end

    coord *= "]"
    coord = eval(Meta.parse(coord)) |> x -> reshape(x, 2, Int64(length(x) / 2)) |> transpose |> Matrix
    return DataFrame(id = index_tag, name = name_tag, country=country_tag, voltage = voltage,
        is_substation = is_substation, longitude=coord[:,1], latitude=coord[:,2], type=type_tag)
end


function load_gridkit_line(source_folder::String)
    fid = Base.open("$source_folder/gridkit/links.csv")

    textline = readline(fid)

    country_tag1 = String[]
    country_tag2 = String[]
    bus_id1 = Int64[]
    bus_id2 = Int64[]

    tie_line_tag = String[]
    index_tag = Int64[]
    line_length = Float64[]
    circuit = Int64[]
    voltage = Float64[]
    is_underground = Bool[]
    is_dc = Bool[]
    is_under_construction = Bool[]
    
    while !eof(fid)
        textline = readline(fid)
        id_q = findall("\"", textline) .|> (x) -> x[1]
        id_p = findall(")", textline) .|> (x) -> x[1]
        id_c = findall(",", textline) .|> (x) -> x[1]
        
        l = textline[id_c[8]+1:id_c[9]-1]
        !isempty(l) ? push!(line_length, parse(Float64,l)/1000) : push!(line_length, 0.0) 
        
        id = findfirst("\"country_1\"=>\"", textline)
        if id != nothing
            id = id[1] + 14
            id = id:(id_q[findfirst(id_q .> id)]- 1)
            push!(country_tag1, textline[id])
        else
            push!(country_tag1, "XX")
        end
        
        id = findfirst("\"country_2\"=>\"", textline)
        if id != nothing
            id = id[1] + 14
            id = id:(id_q[findfirst(id_q .> id)]- 1)
            push!(country_tag2, textline[id])
        else
            push!(country_tag2, "XX")
        end
        
        id = findfirst("\"tie_line\"=>\"", textline)
        if id != nothing
            id = id[1] + 13
            id = id:(id_q[findfirst(id_q .> id)]- 1)
            push!(tie_line_tag, textline[id])
        else
            push!(tie_line_tag, "2")
        end
        
        push!(bus_id1, parse(Int64, textline[id_c[1]+1:id_c[2]-1]))
        push!(bus_id2, parse(Int64, textline[id_c[2]+1:id_c[3]-1]))
        v = textline[id_c[3]+1:id_c[4]-1]
        !isempty(v) ? push!(voltage, parse(Float64, v)) : push!(voltage, 0.0)
        push!(circuit, parse(Int64, textline[id_c[4]+1:id_c[5]-1]))
        push!(is_dc, textline[id_c[5]+1:id_c[6]-1] == "t")
        push!(is_underground, textline[id_c[6]+1:id_c[7]-1] == "t")
        push!(is_under_construction, textline[id_c[7]+1:id_c[8]-1] == "t")
    end

    return DataFrame(bus_id1 = bus_id1, bus_id2 = bus_id2, country1 = country_tag1,
        country2 = country_tag2, circuit=circuit, underground = is_underground,
        in_construction = is_under_construction, is_dc= is_dc, voltage = voltage,
        line_length = line_length)

end


function load_gridkit_trans(source_folder::String)
    fid = Base.open("$source_folder/gridkit/transformers.csv")

    textline = readline(fid)

    bus_id1 = Int64[]
    bus_id2 = Int64[]
    index_tag = Int64[]
    voltage1 = Float64[]
    voltage2 = Float64[]
    is_transformer = Bool[]
    while !eof(fid)
        textline = readline(fid)
        id_q = findall("\"", textline) .|> (x) -> x[1]
        id_p = findall(")", textline) .|> (x) -> x[1]
        id_c = findall(",", textline) .|> (x) -> x[1]
        
        push!(bus_id1, parse(Int64, textline[id_c[2]+1:id_c[3]-1]))
        push!(bus_id2, parse(Int64, textline[id_c[3]+1:id_c[4]-1]))
        contains(textline[id_c[1]+1:id_c[2]-1], "transformer") ? push!(is_transformer, true) :
            push!(is_transformer, false)
        v1 = textline[id_c[4]+1:id_c[5]-1]
        v2 = textline[id_c[5]+1:id_c[6]-1]
        !isempty(v1) ? push!(voltage1, parse(Float64, v1)) : push!(voltage1, 0.0)
        !isempty(v2) ? push!(voltage2, parse(Float64, v2)) : push!(voltage2, 0.0)
    end
    
    return DataFrame(bus_id1 = bus_id1, bus_id2 = bus_id2,
        voltage1 = voltage1, voltage2 = voltage2,
        is_transformer = is_transformer)
end


function load_gridkit_gen(source_folder::String)
    fid = Base.open("$source_folder/gridkit/generators.csv")

    textline = readline(fid)

    country_tag = String[]
    type_tag = String[]
    name_tag = String[]
    bus_tag = Int64[]
    power = Float64[]
    coord = "["
    k = 1
    while !eof(fid)
        textline = readline(fid)
        id_q = findall("\"", textline) .|> (x) -> x[1]
        id_p = findall(")", textline) .|> (x) -> x[1]
        id_c = findall(",", textline) .|> (x) -> x[1]
        
        id = findfirst("\"country\"=>\"", textline)[1] + 12
        id = id:(id_q[findfirst(id_q .> id)]- 1)
        push!(country_tag, textline[id])
        
        id = findfirst("\"name_eng\"=>\"", textline)
        if id != nothing
            id = id[1] + 13
            id2 = findfirst(id_q .> id)
            if id2 != nothing
                try push!(name_tag, textline[id:id_q[id2]-1])
                catch
                    push!(name_tag, textline[id:id_q[id2]-2])
                end
            else
                push!(name_tag, "Unnamed $k")
                k += 1
            end
        else
            push!(name_tag, "Unnamed $k")
            k += 1
        end
        
        id = findfirst("\"mb_symbol\"=>\"", textline)
        if id != nothing
            id = id[1] + 14
            id = id:(id_q[findfirst(id_q .> id)] - 1)
            push!(type_tag, textline[id])
        else
            push!(type_tag, "Null")
        end
        
        push!(bus_tag, parse(Int64, textline[id_c[1]+1:id_c[2]-1]))
        
        id = findfirst("POINT(", textline)[1] + 6
        id = id:(id_p[findfirst(id_p .> id)] - 1)
        coord *= textline[id] * " "
        
        
        contains(textline, "under construction") ? (id = id_c[4]+1:id_c[5]-1) : (id = id_c[3]+1:id_c[4]-1)
        !isempty(id) ? push!(power, parse(Float64, textline[id])) : push!(power, 0.0)
    end

    coord *= "]"
    coord = eval(Meta.parse(coord)) |> x -> reshape(x, 2, Int64(length(x) / 2)) |> transpose |> Matrix

    return DataFrame(bus_id = bus_tag, name = name_tag, country = country_tag, long_type = type_tag, capacity = power,
        longitude = coord[:,1], latitude = coord[:,2])
end

