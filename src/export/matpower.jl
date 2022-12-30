function export_matpower(
    filename::String,
    scenario::Dict{String, DataFrame};
    Sb = 100,
    vmax = 1.1,
    vmin = 0.9,
    extended::Bool =false,
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
    
    if extended
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
    end
    close(fid)
end
