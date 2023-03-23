function download_entsoe_data(source_folder)
    create_dir("$source_folder/enstoe")
    println("""Downloading ENTSO-E data can't be easily be automated
        Please,
        1) create an account on at https://transparency.entsoe.eu
        2) sftp <email address you used>@sftp-transparency.entsoe.eu
        3) download /TP_export/ActualTotalLoad_6.1.A/yyyy_mm_ActualTotalLoad_6.1.A.csv
        (where yyyy is the year and mm is the month) and place it in $source_folder/enstoe/
        """)
end


function retrieve_entsoe_national_demand(
    source_folder::String,
    date::String = "2021-01-01 00:00:00",
)
    data = DataFrame(CSV.File("$source_folder/entsoe/$(date[1:4])_$(date[6:7])_ActualTotalLoad_6.1.A.csv"))

    country = ["AL", "AT", "AZ", "BA", "BE", "BG", "BY", "CH", "CZ", "DE",
        "DK", "DZ", "EE", "EG", "ES", "FI", "FR", "GE", "GR", "HR", "HU",
        "IL", "IQ", "IR", "IT", "JO", "KZ", "LB", "LT", "LU", "LV", "LY",
        "MA", "MD", "ME", "MK", "MT", "NL", "NO", "PA", "PL", "PT", "RO",
        "RS", "RU", "SA", "SE", "SI", "SK", "SY", "TN", "TR", "UA", "GB",
        "IE", "NI", "XX"];
    demand = country .|> c -> sum(subset(data,
            :DateTime => d -> d .== date * ".000",
            :AreaTypeCode => c -> c .== "CTY",
            :AreaName => n -> contains.(n,c)).TotalLoadValue)
    return Dict(zip(country,demand) .|> d-> d[1] => d[2])
end


function retrieve_zonal_demand(
    source_folder::String,
    zone::Vector{String} = ["IT-Sardinia"],
    date::Vector{String} = ["2021-01-01 00:00:00"],
)
    file_tag = unique(date .|> d -> d[1:4] * "_" * d[6:7])

    demand = Dict{String, Vector{Float64}}()
    for z in zone
        demand[z] = Float64[]
    end
    for ft in file_tag
        is_in = date .|> d -> d[1:4] * "_" * d[6:7] == ft
        temp_date = date[is_in]
        data = DataFrame(CSV.File("$source_folder/entsoe/$(ft)_ActualTotalLoad_6.1.A.csv"))
        temp = zone .|> z -> subset(data,
                :DateTime => d -> d .|> d -> d[1:end-4] in temp_date,
                :AreaTypeCode => c -> c .== "BZN",
                :AreaName => n -> contains.(n,z)).TotalLoadValue
        for (i,z) in enumerate(zone)
            append!(demand[z], temp[i])
        end
    end
    return demand
end
