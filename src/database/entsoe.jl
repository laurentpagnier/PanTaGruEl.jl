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
    countries::Vector{String},
)
# Create a dataframe with load data for the specified countries from all entsoe
# files in the directory $source_folder/entsoe
files = readdir("$source_folder/entsoe")
reg = r"\d{4}_\d{2}_ActualTotalLoad_6\.1\.A\.csv"
reg2 = r"\d{4}_\d{2}_DayAheadTotalLoadForecast_6\.1\.B\.csv"
matches = match.(reg, files)
matches2 = match.(reg2, files)

# Create export DataFrame
df = DataFrame(zeros(0, length(countries)), countries)
insertcols!(df, 1, "Date"=>zeros(0))
df2 = DataFrame(zeros(0, length(countries)), countries)
insertcols!(df2, 1, "Date"=>zeros(0))

for m in matches
    if m === nothing
        continue
    end
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

    # Reformat the database to fit the global one
    dftemp2 = DataFrame(zeros(0, length(countries)), countries)
    insertcols!(dftemp2, 1, "Date"=>zeros(0))
    for row in eachrow(dftemp)
        push!(dftemp2, Dict(:Date => row.DateTime_function, Symbol(row.MapCode) => row.TotalLoadValue_mean), cols=:subset)
    end
    # Set missing entries to zero and combine entries for the same date
    for i in names(dftemp2)
        dftemp2[ismissing.(dftemp2[!, i]), i] .= 0
    end
    dftemp2 = combine(groupby(dftemp2, :Date), (c=>sum=>c for c in countries)...)
    # Finally add to the global dataframe
    df = vcat(df, dftemp2)
end
for m in matches2
    if m === nothing
        continue
    end
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

   
    # Reformat the database to fit the global one
    dftemp2 = DataFrame(zeros(0, length(countries)), countries)
    insertcols!(dftemp2, 1, "Date"=>zeros(0))
    for row in eachrow(dftemp)
        push!(dftemp2, Dict(:Date => row.DateTime_function, Symbol(row.MapCode) => row.TotalLoadValue_mean), cols=:subset)
    end
    # Set missing entries to zero and combine entries for the same date
    for i in names(dftemp2)
        dftemp2[ismissing.(dftemp2[!, i]), i] .= 0
    end
    dftemp2 = combine(groupby(dftemp2, :Date), (c=>sum=>c for c in countries)...)
    # Finally add to the global dataframe
    df2 = vcat(df2, dftemp2)
end
fullix = df.Date
tmp = DataFrame("Date"=>fullix)
leftjoin!(tmp, df2, on=:Date)
tmp = coalesce.(tmp, 0)
sort!(tmp, :Date)
sort!(df, :Date)
# Try to fill zero elements with prediction data
for i in names(df)
    if i == "Date"
        continue
    end
    ix = iszero.(df[!, i])
    df[ix, i] = tmp[ix, i]
end

# Put Date back to DateTime
map!(x->DateTime(x...), df.Date, df.Date)

return df
end