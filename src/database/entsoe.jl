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


function retreave_entsoe_national_demand(
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
