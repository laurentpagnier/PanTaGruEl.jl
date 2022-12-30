using XLSX

function export_oats(
    filename::String,
    scenario::Dict{String, DataFrame};
    Sb = 100,
    vmax = 1.1,
    vmin = 0.9,
)

    i2abc = Dict(1 => "A", 2 => "B", 3 => "C", 4 => "D", 5 => "E", 6 => "F",
        7 => "G", 8 => "H", 9 => "I", 10 => "J", 11 => "K", 12 => "L",
        13 => "M", 14 => "N", 15 => "O", 16 => "P", 17 => "Q", 18 => "R",
        19 => "S", 20 => "T", 21 => "U", 22 => "V", 23 => "W", 24 => "X",
        25 => "Y", 26 => "Z")


    XLSX.openxlsx(filename, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "bus")
        sheet_label = ["demand", "branch", "transformer", "wind",
            "shunt", "zonalNTC", "generator", "baseMVA", "timeseries",
            "zone", "storage"]
        for i=1:length(sheet_label)
            XLSX.addsheet!(xf, sheet_label[i])
        end
            
        label = ["name", "location", "baseKV", "type", "zone", "VM",
            "VA", "VNLB", "VNUB", "VELB", "VEUB"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        
        for i=1:size(scenario["bus"],1)
            sheet["A$(i+1)"] = scenario["bus"].id[i]
            sheet["B$(i+1)"] = scenario["bus"].name[i]
            #sheet["B$(i+1)"] = "B$i"
            sheet["C$(i+1)"] = scenario["bus"].voltage[i]
            sheet["D$(i+1)"] = 1
            sheet["E$(i+1)"] = 1
            sheet["F$(i+1)"] = 1
            sheet["G$(i+1)"] = 0
            sheet["H$(i+1)"] = 0.975
            sheet["I$(i+1)"] = 1.025
            sheet["J$(i+1)"] = 0.9
            sheet["K$(i+1)"] = 1.1
            sheet["G$(i+1)"] = 0
        end
        
        
        sheet = xf[2]
        label = ["name", "busname", "real", "reactive", "stat", "VOLL"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        
        for i=1:size(scenario["demand"],1)
            sheet["A$(i+1)"] = "D$i"
            sheet["B$(i+1)"] = scenario["bus"].id[i]
            sheet["C$(i+1)"] = scenario["demand"].active[i]
            sheet["D$(i+1)"] = scenario["demand"].reactive[i]
            sheet["E$(i+1)"] = 1
            sheet["F$(i+1)"] = 7000
        end
        
        sheet = xf[3]
        label = ["name", "from_busname", "to_busname", "stat", "r", "x",
            "b", "ShortTermRating", "ContinousRating", "angLB", "angUB",
            "contingency", "probablity"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        
        k = 2
        for i=1:size(scenario["line"],1)
            r = Sb * scenario["line"].r[i] / scenario["line"].voltage[i]^2
            x = Sb * scenario["line"].x[i] / scenario["line"].voltage[i]^2
            for _ = 1:scenario["line"].circuit[i]
                sheet["A$(k)"] = "L$(k-1)"
                sheet["B$(k)"] = scenario["line"].bus_id1[i]
                sheet["C$(k)"] = scenario["line"].bus_id2[i]
                sheet["D$(k)"] = 1
                sheet["E$(k)"] = r
                sheet["F$(k)"] = x
                sheet["G$(k)"] = 0.0
                sheet["H$(k)"] = scenario["line"].fmax[i]
                sheet["I$(k)"] = scenario["line"].fmax[i]
                sheet["J$(k)"] = -360
                sheet["K$(k)"] = 360
                sheet["L$(k)"] = 0
                sheet["M$(k)"] = 0.001
                k += 1
            end
        end
        
        
        sheet = xf[4]
        label = ["name", "from_busname", "to_busname", "type", "stat",
            "r", "x", "b",  "ShortTermRating", "ContinousRating",
            "angLB", "angUB", "PhaseShift", "TapRatio", "TapLB", "TapUB",
            "contingency", "probability"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        

        for i=1:size(scenario["trans"],1)
            v = max(scenario["trans"].voltage1[i], scenario["trans"].voltage2[i])
            r = Sb * scenario["trans"].r[i] / v^2
            x = Sb * scenario["trans"].x[i] / v^2
            sheet["A$(i+1)"] = "T$i"
            sheet["B$(i+1)"] = scenario["trans"].bus_id1[i]
            sheet["C$(i+1)"] = scenario["trans"].bus_id2[i]
            sheet["D$(i+1)"] = 1
            sheet["E$(i+1)"] = 1
            sheet["F$(i+1)"] = r # TODO 
            sheet["G$(i+1)"] = x
            sheet["H$(i+1)"] = 0.0
            sheet["I$(i+1)"] = scenario["trans"].fmax[i]
            sheet["J$(i+1)"] = scenario["trans"].fmax[i]
            sheet["K$(i+1)"] = -360
            sheet["L$(i+1)"] = 360
            sheet["M$(i+1)"] = 0
            sheet["N$(i+1)"] = 1
            sheet["O$(i+1)"] = 0.95
            sheet["P$(i+1)"] = 1.05
            sheet["Q$(i+1)"] = 0
            sheet["R$(i+1)"] = 0.001
        end
        
        
        
        sheet = xf[5]
        label = ["busname", "name", "stat", "PG", "QG", "PGLB", "PGUB",
            "QGLB", "QGUB", "VS", "contingency", "failure_rate(1/yr)",
            "offer"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        
        sheet = xf[6]
        label = ["busname", "name", "GL", "BL", "stat"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        
        
        sheet = xf[7]
        label = label = ["interconnection_ID", "from_zone", "to_zone",
            "TransferCapacityTo(MW)", "TransferCapacityFr(MW)"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        
        sheet = xf[8]
        label = ["busname", "location", "name", "stat", "type", "PG", "QG",
            "PGLB", "PGUB", "QGLB", "QGUB", "VS", "RampDown(MW/hr)",
            "RampUp(MW/hr)", "MinDownTime(hr)", "MinUpTime(hr)", "FuelType",
            "contingency", "probabality", "startup", "shutdown", "costc2",
            "costc1", "costc0", "bid", "offer"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
            
        for i=1:size(scenario["gen"],1)
            sheet["A$(i+1)"] = scenario["gen"].bus_id[i]
            sheet["B$(i+1)"] = scenario["gen"].name[i]
            sheet["C$(i+1)"] = "G$i"
            sheet["D$(i+1)"] = 1
            sheet["E$(i+1)"] = 1
            sheet["F$(i+1)"] = 0.0
            sheet["G$(i+1)"] = 0.0
            sheet["H$(i+1)"] = 0.0
            sheet["I$(i+1)"] = scenario["gen"].capacity[i]
            sheet["J$(i+1)"] = -scenario["gen"].capacity[i] / 2
            sheet["K$(i+1)"] = scenario["gen"].capacity[i] / 2
            sheet["L$(i+1)"] = 1.0
            sheet["M$(i+1)"] = 100
            sheet["N$(i+1)"] = 100
            sheet["O$(i+1)"] = 2
            sheet["P$(i+1)"] = 2
            sheet["Q$(i+1)"] = scenario["gen"].long_type[i]
            sheet["R$(i+1)"] = 0
            sheet["S$(i+1)"] = 0.001
            sheet["T$(i+1)"] = 100
            sheet["U$(i+1)"] = 100
            sheet["V$(i+1)"] = 0.0
            sheet["W$(i+1)"] = scenario["gen"].marginal_cost[i]
            sheet["X$(i+1)"] = 0.0
            sheet["Y$(i+1)"] = 40
            sheet["Z$(i+1)"] = 80
        end
        
        sheet = xf[9]
        label = ["baseMVA"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        sheet["A2"] = Sb
        
        sheet = xf[11]
        label = ["zone", "reserve(MW)"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
        
        sheet = xf[12]
        label = ["name", "zone", "stat", "Minoperatingcapacity(MW)", "capacity(MW)",
            "chargingrate(MW/hr)", "dischargingrate(MW/hr)", "ChargingEfficieny(%)",
            "DischargingEfficieny(%)", "InitialStoredPower(MW)", "FinalStoredPower(MW)"]
        for i=1:length(label)
            sheet["$(i2abc[i])1"] = label[i]
        end
    end

end
