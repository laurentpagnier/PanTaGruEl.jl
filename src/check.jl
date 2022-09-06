function positive_gen_power(
    scenario
)
    return all(scenario["gen"].capacity .> 0.0)
end


function at_least_one_line(
    scenario,
)
    missing = setdiff(scenario["bus"].id,
        unique([scenario["line"].bus_id1; scenario["line"].bus_id2])) 
    return isempty(missing)
end


function abnormal_demand(
    scenario;
    max_demand = 2000.0,
)
    return any(scenario["demand"].active .> max_demand)
end
