export export_matpower, export_csv, export_pandapower, export_pandapower

function export_matpower(
    filename::String,
    scenario::Dict{String, DataFrame};
    Sb = 100,
    vmax = 1.1,
    vmin = 0.9,
)

    fid = open(filename, "w")
    casename = filename[1:end-2]

    casename = contains(casename,"/") ? findlast("/", casename)[1] |>
        id -> casename[id+1:end] : casename
        
    write(fid, "function mpc = $casename() \n\n")
    write(fid, "mpc.version = '2';\n\n")
    write(fid, "mpc.baseMVA = $Sb;\n\n")

    write(fid, "mpc.bus = [\n")
    vmax = string(vmax)
    vmin = string(vmin)

    for i=1:size(scenario["bus"],1)
        id = scenario["bus"].id[i]
        t = get_matpower_type(scenario["bus"].type[i])
        demand_p = scenario["demand"].active[i]
        demand_q = scenario["demand"].reactive[i]
        v = scenario["bus"].voltage[i]
        write(fid,"\t$id\t$t\t$demand_p\t$demand_q\t0\t0\t1\t1.0\t0\t$v\t1\t$vmax\t$vmin;\n")
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.gen = [\n")
    for i=1:size(scenario["gen"], 1)
        if !(scenario["gen"].type[i]  in ["WD", "XX", "SO", "PV"])
            pg = 0.0 
            qg = 0.0
            qlim = min(0.5 * scenario["gen"].capacity[i], 1000)
            pmin = 0.
            status = 1
            pmax = scenario["gen"].capacity[i]
            id = scenario["gen"].bus_id[i]
            ramp = 0.0
            write(fid,"\t$id\t$pg\t$qg\t$qlim\t$(-qlim)\t1.0\t$Sb\t$status\t$pmax\t$pmin\t0\t0\t0\t0\t0\t0\t0\t0\t$ramp\t0\t0;\n")
        end
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.branch = [\n")
    
    for i=1:size(scenario["line"], 1)
        id1 = scenario["line"].bus_id1[i]
        id2 = scenario["line"].bus_id2[i]
        r = Sb * scenario["line"].r[i] / scenario["line"].voltage[i]^2
        x = Sb * scenario["line"].x[i] / scenario["line"].voltage[i]^2
        b = Sb * scenario["line"].b[i] / scenario["line"].voltage[i]^2
        fmax = scenario["line"].fmax[i]
        for i=1:scenario["line"].circuit[i]
            write(fid, "\t$id1\t$id2\t$r\t$x\t$b\t$fmax\t0\t0\t0\t0\t1\t-360\t360;\n")       
        end
    end
    
    for i=1:size(scenario["trans"], 1)
        id1 = scenario["trans"].bus_id1[i]
        id2 = scenario["trans"].bus_id2[i]
        v = max(scenario["trans"].voltage1[i], scenario["trans"].voltage2[i])
        r = Sb * scenario["trans"].r[i] / v^2
        x = Sb * scenario["trans"].x[i] / v^2
        b = 0.0
        fmax = scenario["trans"].fmax[i]
        write(fid, "\t$id1\t$id2\t$r\t$x\t$b\t$fmax\t0\t0\t0\t0\t1\t-360\t360;\n")       
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.gencost = [\n")
    for i=1:size(scenario["gen"], 1)
        if !(scenario["gen"].type[i]  in ["WD", "XX", "SO", "PV"])
            m = scenario["gen"].marginal_cost[i]
            write(fid, "\t2\t0\t0\t2\t$m\t0;\n")
        end
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.bus_coord = [\n")
    for i=1:size(scenario["bus"], 1)
        lat = scenario["bus"].latitude[i]
        lon = scenario["bus"].longitude[i]
        write(fid, "\t$lon\t$lat;\n")
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.bus_name = [\n")
    for i=1:size(scenario["bus"], 1)
        n = scenario["bus"].name[i]
        write(fid, "\t\"$n\";\n")
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.gen_type = [\n")
    for i=1:size(scenario["gen"], 1)
        t = scenario["gen"].type[i]
        write(fid, "\t\"$t\";\n")
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.gen_inertia = [\n")
    for i=1:size(scenario["gen"], 1)
        m = scenario["gen"].inertia[i] / Sb
        write(fid, "\t$m;\n")
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.gen_prim_ctrl = [\n")
    for i=1:size(scenario["gen"], 1)
        d = scenario["gen"].damping[i] / Sb
        write(fid, "\t$d;\n")
    end
    write(fid, "];\n\n")
    
    write(fid, "mpc.load_freq_coef = [\n")
    for i=1:size(scenario["demand"], 1)
        d = scenario["demand"][i, "freq coeff"] / Sb
        write(fid, "\t$d;\n")
    end
    write(fid, "];\n\n")
    
    
    close(fid)
end


function get_matpower_type(t)
    if t == "PQ"
        return 1
    elseif t == "PV"
        return 2
    elseif t == "Vθ"
        return 3
    end
end


function export_csv(foldername, scenario)
    create_dir(foldername)
    for k in keys(scenario)
        CSV.write("$foldername/$k.csv", scenario[k])  
    end
    nothing
end


function export_pandapower(filename, scenario)
    # create a json  in the same format as what get form
    # pp.to_json function

    fid = open(filename, "w")

    bus_field = [("in_service", "bool"), ("max_vm_pu", "float64"), ("min_vm_pu", "float64"),
        ("name", "object"), ("type", "object"), ("vn_kv", "float64"), ("zone", "object")]

    Nbus = size(scenario["bus"], 1)
    Ndemand = size(scenario["demand"], 1)
    Ngen = size(scenario["gen"], 1)
    Nline = size(scenario["line"], 1)
    Ntrans = size(scenario["trans"], 1)
    sn_mva = 100.0
    
    write(fid, "{\n\"_module\": \"pandapower.auxiliary\",\n\"_class\": \"pandapowerNet\",\n")
    write(fid, "\"_object\": {\n\t\"sn_mva\": $sn_mva,\n\t\"bus\": {\n\t\t\"_module\": \"pandas.core.frame\",\n")
    write(fid, "\t\t\"_class\": \"DataFrame\",\n\t\t\"_object\": \"{\\\"columns\\\":[")
    
    for i=1:size(bus_field,1)
        write(fid, "\\\"$(bus_field[i][1])\\\"")
        i < size(bus_field,1) ? write(fid, ",") : nothing
    end

    write(fid, "],\\\"index\\\":[")
    for i = 1:size(scenario["bus"], 1)
        write(fid, "$(i-1)")
        i < Nbus ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"data\\\":[")
    for i = 1:size(scenario["bus"], 1)
        v = scenario["bus"].voltage[i]
        n = scenario["bus"].name[i]
        write(fid, "[true,1.06,0.94,\\\"$n\\\",\\\"b\\\",$v,1.0]")
        i < Nbus ? write(fid, ",") : nothing
    end
    write(fid, "]}\",\n")
    write(fid, "\t\t\"orient\": \"split\",\n\t\t\"dtype\": {\n")
    for i=1:size(bus_field,1)
        write(fid, "\t\t\"$(bus_field[i][1])\": \"$(bus_field[i][2])\"") 
        i < size(bus_field,1) ? write(fid, ",\n") : write(fid, "\n")
    end
    write(fid, "\t\t}\n")
    write(fid, "\t},\n") # end of bus

    load_field = [("bus", "uint32"), ("const_i_percent", "float64"), ("const_z_percent", "float64"),
        ("controllable", "bool"),("in_service", "bool"), ("name", "object"), ("p_mw", "float64"),
        ("q_mvar", "float64"), ("scaling", "float64"), ("sn_mva", "float64"), ("type", "object")]

    write(fid, "\n\t\"load\": {\n\t\t\"_module\": \"pandas.core.frame\",\n")
    write(fid, "\t\t\"_class\": \"DataFrame\",\n\t\t\"_object\": \"{\\\"columns\\\":[")
    for i=1:size(load_field,1)
        write(fid, "\\\"$(load_field[i][1])\\\"")
        i < size(load_field,1) ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"index\\\":[")
    for i = 1:size(scenario["demand"], 1)
        write(fid, "$(i-1)")
        i < Ndemand ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"data\\\":[")
    for i = 1:size(scenario["demand"], 1)
        p = scenario["demand"].active[i]
        q = scenario["demand"].reactive[i]
        write(fid, "[$(i-1),0.0,0.0,false,true,null,$p,$q,1.0,null,null]")
        i < Ndemand ? write(fid, ",") : nothing
    end
    write(fid, "]}\",\n")
    write(fid, "\t\t\"orient\": \"split\",\n\t\t\"dtype\": {\n")
    for i=1:size(load_field,1)
        write(fid, "\t\t\"$(load_field[i][1])\": \"$(load_field[i][2])\"") 
        i < size(load_field,1) ? write(fid, ",\n") : write(fid, "\n")
    end
    write(fid, "\t\t}\n")
    write(fid, "\t},\n") # end of load

    gen_field = [("bus", "uint32"), ("controllable", "bool"), ("in_service", "bool"),
        ("name", "object"), ("p_mw", "float64"), ("scaling", "float64"),
        ("sn_mva", "float64"), ("type", "object"), ("vm_pu", "float64"),
        ("slack", "bool"), ("max_p_mw", "float64"), ("min_p_mw", "float64"),
        ("max_q_mvar", "float64"), ("min_q_mvar", "float64"), ("slack_weight", "float64")]

    write(fid, "\n\t\"gen\": {\n\t\t\"_module\": \"pandas.core.frame\",\n")
    write(fid, "\t\t\"_class\": \"DataFrame\",\n\t\t\"_object\": \"{\\\"columns\\\":[")
    for i=1:size(gen_field,1)
        write(fid, "\\\"$(gen_field[i][1])\\\"")
        i < size(gen_field,1) ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"index\\\":[")
    for i = 1:size(scenario["gen"], 1)
        write(fid, "$(i-1)")
        i < Ngen ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"data\\\":[")
    for i = 1:size(scenario["gen"], 1)
        id = scenario["gen"].bus_id[i] |>
            id -> findfirst(scenario["bus"].id .== id) - 1
        pg = scenario["gen"].capacity[i]
        qlim = min(0.5 * scenario["gen"].capacity[i], 1000)
        write(fid, "[$id,true,true,null,0.0,1.0,$sn_mva,null,1.0,false,$pg,0.0,$qlim,$(-qlim),0.0]")
        i < Ngen ? write(fid, ",") : nothing
    end
    write(fid, "]}\",\n")
    write(fid, "\t\t\"orient\": \"split\",\n\t\t\"dtype\": {\n")
    for i=1:size(gen_field,1)
        write(fid, "\t\t\"$(gen_field[i][1])\": \"$(gen_field[i][2])\"") 
        i < size(gen_field,1) ? write(fid, ",\n") : write(fid, "\n")
    end
    write(fid, "\t\t}\n")
    write(fid, "\t},\n") # end of gen

    line_field = [("c_nf_per_km", "float64"), ("df", "float64"), ("from_bus", "uint32"),
        ("g_us_per_km", "float64"), ("in_service", "bool"), ("length_km", "float64"),
        ("max_i_ka", "float64"), ("max_loading_percent", "float64"), ("name", "object"),
        ("parallel", "uint32"), ("r_ohm_per_km", "float64"), ("std_type", "object"),
        ("to_bus", "uint32"), ("type", "object"), ("x_ohm_per_km", "float64")]

    write(fid, "\n\t\"line\": {\n\t\t\"_module\": \"pandas.core.frame\",\n")
    write(fid, "\t\t\"_class\": \"DataFrame\",\n\t\t\"_object\": \"{\\\"columns\\\":[")
    for i=1:size(line_field,1)
        write(fid, "\\\"$(line_field[i][1])\\\"")
        i < size(line_field,1) ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"index\\\":[")
    temp = 0
    for i = 1:size(scenario["line"], 1)
        n = scenario["line"].circuit[i]
        for j = 1:n
            write(fid, "$temp")
            j < n ? write(fid, ",") : nothing
            temp += 1
        end
        i < Nline ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"data\\\":[")
    for i = 1:size(scenario["line"], 1)
        
        id1 = scenario["line"].bus_id1[i] |>
            id -> findfirst(scenario["bus"].id .== id) - 1
        id2 = scenario["line"].bus_id2[i] |>
            id -> findfirst(scenario["bus"].id .== id) - 1
        n = scenario["line"].circuit[i]
        r = scenario["line"].r[i]
        x = scenario["line"].x[i]
        imax = scenario["line"].fmax[i] / scenario["line"].voltage[i] / sqrt(3) 
        for j = 1:n
            write(fid, "[0.0,1.0,$id1,0.0,true,1.0,$imax,100.0,null,1,$r,null,$id2,\\\"ol\\\",$x]")
            j < n ? write(fid, ",") : nothing
        end
        i < Nline ? write(fid, ",") : nothing
    end
    write(fid, "]}\",\n")
    write(fid, "\t\t\"orient\": \"split\",\n\t\t\"dtype\": {\n")
    for i=1:size(line_field,1)
        write(fid, "\t\t\"$(line_field[i][1])\": \"$(line_field[i][2])\"") 
        i < size(line_field,1) ? write(fid, ",\n") : write(fid, "\n")
    end
    write(fid, "\t\t}\n")
    write(fid, "\t},\n") # end of line

    trans_field = [("df", "float64"), ("hv_bus", "uint32"), ("i0_percent", "float64"),
        ("in_service", "bool"), ("lv_bus", "uint32"), ("max_loading_percent", "float64"),
        ("name", "object"), ("parallel", "uint32"), ("pfe_kw", "float64"),
        ("shift_degree", "float64"), ("sn_mva", "float64"), ("std_type", "object"),
        ("tap_max", "float64"), ("tap_neutral", "float64"), ("tap_min", "float64"),
        ("tap_phase_shifter", "bool"), ("tap_pos", "float64"), ("tap_side", "object"),
        ("tap_step_degree", "float64"), ("tap_step_percent", "float64"), ("vn_hv_kv", "float64"),
        ("vn_lv_kv", "float64"), ("vk_percent", "float64"), ("vkr_percent", "float64")]

    write(fid, "\n\t\"trafo\": {\n\t\t\"_module\": \"pandas.core.frame\",\n")
    write(fid, "\t\t\"_class\": \"DataFrame\",\n\t\t\"_object\": \"{\\\"columns\\\":[")
    for i=1:size(trans_field,1)
        write(fid, "\\\"$(trans_field[i][1])\\\"")
        i < size(trans_field,1) ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"index\\\":[")
    for i = 1:size(scenario["trans"], 1)
        write(fid, "$(i-1)")
        i < Ntrans ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"data\\\":[")
    for i = 1:size(scenario["trans"], 1)
        id1 = scenario["trans"].bus_id1[i]
        id2 = scenario["trans"].bus_id2[i]
        r = scenario["trans"].r[i]
        x = scenario["trans"].x[i]
        v1 = scenario["trans"].voltage1[i]
        v2 = scenario["trans"].voltage2[i]
        id1 = scenario["trans"].bus_id1[i] |>
            id -> findfirst(scenario["bus"].id .== id) - 1
        id2 = scenario["trans"].bus_id2[i] |>
            id -> findfirst(scenario["bus"].id .== id) - 1
        fmax = scenario["trans"].fmax[i]
        hv_id, lv_id, hv_v, lv_v = v1 > v2 ? (id1, id2, v1, v2) : (id2, id1, v2, v1)
        vk_percent = x / (hv_v^2 / sn_mva) * fmax
        write(fid, "[1.0,$hv_id,0.0,true,$lv_id,100.0,null,1,0.0,0.0,$fmax,null,null,")
        write(fid, "null,null,false,null,null,null,null,$hv_v,$lv_v,$vk_percent,0.0]")
        i < Ntrans ? write(fid, ",") : nothing
    end
    write(fid, "]}\",\n")
    write(fid, "\t\t\"orient\": \"split\",\n\t\t\"dtype\": {\n")
    for i=1:size(trans_field,1)
        write(fid, "\t\t\"$(trans_field[i][1])\": \"$(trans_field[i][2])\"") 
        i < size(trans_field,1) ? write(fid, ",\n") : write(fid, "\n")
    end
    write(fid, "\t\t}\n")
    write(fid, "\t},\n") # end of trans


    poly_field = [("element", "uint32"), ("et", "object"), ("cp0_eur", "float64"),
        ("cp1_eur_per_mw", "float64"), ("cp2_eur_per_mw2", "float64"),
        ("cq0_eur", "float64"), ("cq1_eur_per_mvar", "float64"), ("cq2_eur_per_mvar2", "float64")]

    write(fid, "\n\t\"poly_cost\": {\n\t\t\"_module\": \"pandas.core.frame\",\n")
    write(fid, "\t\t\"_class\": \"DataFrame\",\n\t\t\"_object\": \"{\\\"columns\\\":[")
    for i=1:size(poly_field,1)
        write(fid, "\\\"$(poly_field[i][1])\\\"")
        i < size(poly_field,1) ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"index\\\":[")
    for i = 1:size(scenario["gen"], 1)
        write(fid, "$(i-1)")
        i < Ngen ? write(fid, ",") : nothing
    end
    write(fid, "],\\\"data\\\":[")
    for i = 1:size(scenario["gen"], 1)
        c1 = Float64(scenario["gen"].marginal_cost[i])
        write(fid, "[$i,\\\"gen\\\",0.0,$c1,0.0,0.0,0.0,0.0]")
        i < Ngen ? write(fid, ",") : nothing
    end
    write(fid, "]}\",\n")
    write(fid, "\t\t\"orient\": \"split\",\n\t\t\"dtype\": {\n")
    for i=1:size(poly_field,1)
        write(fid, "\t\t\"$(poly_field[i][1])\": \"$(poly_field[i][2])\"") 
        i < size(poly_field,1) ? write(fid, ",\n") : write(fid, "\n")
    end
    write(fid, "\t\t}\n")
    write(fid, "\t}\n") # end of poly

    write(fid, "}\n") # end of _object

    write(fid, "}") # end of json
    close(fid)
end

