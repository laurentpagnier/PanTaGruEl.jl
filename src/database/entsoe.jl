export create_entsoe_list

function download_entsoe_data(source_folder)
    create_dir("$source_folder/entsoe")
    println("""Downloading ENTSO-E data can't be easily be automated
        Please,
        1) create an account on at https://transparency.entsoe.eu
        2) sftp <email address you used>@sftp-transparency.entsoe.eu
        3) download /TP_export/ActualTotalLoad_6.1.A/yyyy_mm_ActualTotalLoad_6.1.A.csv
        (where yyyy is the year and mm is the month) and place it in $source_folder/entsoe/
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

function create_entsoe_list(
    source_folder::String,
    output_folder::String,
    file_name::String,
    countries::Vector{String},
)
# Create a CSV file with load data for the specified countries from all entsoe
# files in the directory $source_folder/entsoe
files = readdir("$source_folder/entsoe")
reg = r"\d{4}_\d{2}_ActualTotalLoad_6\.1\.A\.csv"
matches = match.(reg, files)

# Create export DataFrame
df = DataFrame(zeros(0, length(countries)), countries)
insertcols!(df, 1, "Date"=>Tuple)

i = 0
for m in matches
    if m === nothing
        continue
    end
    i += 1
    println("Handling file $i")
    # Create temporary dataframe holding current file
    dftemp = DataFrame(CSV.File("$source_folder/entsoe/$(m.match)"))
    subset!(dftemp, :AreaTypeCode => a -> a.=="CTY", :MapCode => a -> [i in countries for i in a])
    dftemp.DateTime = Dates.DateTime.(
        dftemp.DateTime, Dates.DateFormat("y-m-d H:M:S.s"))
    transform!(dftemp, :DateTime => x -> tuple.(Dates.year.(x),
            Dates.month.(x), Dates.day.(x), Dates.hour.(x)))
    dftemp = dftemp[!, ["DateTime_function", "MapCode", "TotalLoadValue"]]
    dftemp = combine(groupby(dftemp, ["MapCode", "DateTime_function"], sort=true),
    :TotalLoadValue => mean)

    # Enter everything in the global database
    for row in eachrow(dftemp)
        ix = findfirst(d -> d == row.DateTime_function, df.Date)
        if ix === nothing
            push!(df, Dict(:Date => row.DateTime_function, Symbol(row.MapCode) => row.TotalLoadValue_mean), cols=:subset)
        else
            df[ix, row.MapCode] = row.TotalLoadValue_mean
        end
    end
    # Drop rows that are missing entries
    dropmissing!(df)
end

# Put Date back to DateTime and sort
map!(x->DateTime(x...), df.Date, df.Date)
sort!(df, :Date)

# Write to file
CSV.write("$output_folder/$file_name.csv", df)
end