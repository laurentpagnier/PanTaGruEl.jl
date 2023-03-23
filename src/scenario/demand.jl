export assign_active_demand!, national_demand, assign_demand_freq_coeff!,
    update_active_demand!

function assign_active_demand!(
    scenario::Dict{String, DataFrame},
    demand = national_demand();
    i = 1
)
    active = zeros(size(scenario["bus"],1))
    reactive = zeros(size(scenario["bus"],1))
    
    for c in keys(demand)
        findall(scenario["bus"].country .== c) |> id -> begin
            if !isempty(id) 
                (id, scenario["bus"].population[id] ./ (sum(scenario["bus"].population[id]) + 1E-9) *
                demand[c][i]) |> temp -> active[temp[1]] = temp[2]
            end
        end
    end
    
    scenario["demand"] = DataFrame(active = active, reactive = reactive)
    nothing
end


function update_active_demand!(
    scenario::Dict{String, DataFrame},
    source_folder::String,
    date::String,
    )
    nd = retrieve_entsoe_national_demand(source_folder, date)
    assign_active_demand!(scenario, nd)
    Nothing
end


function assign_demand_freq_coeff!(
    scenario::Dict{String, DataFrame};
    min_value = 0.01,
    alpha = 1.5,
    freq = 50.0,
)
    scenario["demand"][:,"freq coeff"] = alpha / (2 *pi * freq) *
        scenario["demand"][:,"active"]
    nothing
end


function national_demand(
    tag::String = "avg"
)
    
    if tag == "avg"
        return Dict("AL" =>  700, "AT" =>  8300, "AZ" =>  2200,
            "BA" =>  1400, "BE" =>  10200, "BG" =>  4100, "BY" =>  3900,
            "CH" =>  7000, "CZ" =>  7600, "DE" =>  62300, "DK" =>  3700,
            "DZ" =>  5600, "EE" =>  900, "EG" =>  16000, "ES" =>  26700,
            "FI" =>  9200, "FR" =>  54400, "GE" =>  100, "GR" =>  6100,
            "HR" =>  1900, "HU" =>  2500, "IL" =>  6800, "IQ" =>  1,
            "IR" =>  1, "IT" =>  33200, "JO" =>  1800, "KZ" =>  1,
            "LB" =>  1800, "LT" =>  1100, "LU" =>  600, "LV" =>  800,
            "LY" =>  1100, "MA" =>  3300, "MD" =>  500, "ME" =>  300,
            "MK" =>  800, "MT" =>  200, "NL" =>  12300, "NO" =>  14400,
            "PA" =>  500, "PL" =>  16200, "PT" =>  5300, "RO" =>  5500,
            "RS" =>  3100, "RU" =>  59200, "SA" =>  1, "SE" =>  14500,
            "SI" =>  1500, "SK" =>  3200, "SY" =>  1900, "TN" =>  1700,
            "TR" =>  23600, "UA" =>  16300, "GB" =>  42000, "IE" =>  3000,
            "NI" =>  700, "XX" => 0)
    end
    
    
    if tag == "winter_peak"
        # based on ENTSOE data for 2021-01-25 18:00:00.000
        return Dict("AL" => 0.0, "AT" => 8984.1, "AZ" => 0.0, "BA" => 1363.31,
            "BE" => 13287.21, "BG" => 5486.0, "BY" => 0.0, "CH" => 9468.34,
            "CZ" => 9571.01, "DE" => 73104.95, "DK" => 5061.81, "DZ" => 0.0,
            "EE" => 1167.5, "EG" => 0.0, "ES" => 35080.0, "FI" => 11040.0,
            "FR" => 80341.0, "GE" => 0.0, "GR" => 6782.18, "HR" => 2700.0,
            "HU" => 6233.1, "IL" => 0.0, "IQ" => 0.0, "IR" => 0.0,
            "IT" => 43573.0, "JO" => 0.0, "KZ" => 0.0, "LB" => 0.0,
            "LT" => 1666.33, "LU" => 0.0, "LV" => 975.0, "LY" => 0.0,
            "MA" => 0.0, "MD" => 857.0, "ME" => 498.24, "MK" => 0.0, "MT" => 0.0,
            "NL" => 15792.68, "NO" => 22651.95, "PA" => 0.0,
            "PL" => 24449.94, "PT" => 7741.1, "RO" => 8528.0, "RS" => 4981.0,
            "RU" => 0.0, "SA" => 0.0, "SE" => 29216.52, "SI" => 1989.96,
            "SK" => 3953.0, "SY" => 0.0, "TN" => 0.0, "TR" => 0.0,
            "UA" => 20182.0, "GB" => 48324.0, "IE" => 6549.52, "NI" => 0.0, "XX" => 0.0)
    end
    
    if tag == "record_peak"
        return Dict("AL" => 1500, "AT" => 10000, "AZ" => 1, "BA" => 2200, "BE" => 14000,
            "BG" => 7800, "BY" => 1, "CH" => 10800, "CZ" => 10800, "DE" => 86000,
            "DK" => 5500, "DZ" => 1, "EE" => 1, "EG" => 1, "ES" => 46000,
            "FI" => 14800, "FR" => 102000, "GE" => 1, "GR" => 10600, "HR" => 3200,
            "HU" => 6300, "IL" => 13800, "IQ" => 1, "IR" => 1, "IT" => 54000,
            "JO" => 1, "KZ" => 1, "LB" => 1, "LT" => 1, "LU" => 800, "LV" => 1000,
            "LY" => 1, "MA" => 1, "MD" => 1500, "ME" => 600, "MK" => 1500,
            "MT" => 1, "NL" => 20300, "NO" => 24180, "PA" => 1, "PL" => 25800,
            "PT" => 8300, "RO" => 9300, "RS" => 8000, "RU" => 1, "SA" => 1,
            "SE" => 23400, "SI" => 2000, "SK" => 4400, "SY" => 1, "TN" => 1,
            "TR" => 1, "UA" => 30000, "GB" => 52700, "IE" => 4500, "NI" => 1000,
            "XX" => 0)
    end
end

