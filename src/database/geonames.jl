export load_geonames_data


function download_geonames_data(source_folder)
    create_dir("$source_folder/geonames")
    download("http://download.geonames.org/export/dump/cities1000.zip",
        "$source_folder/geonames/cities1000.zip")
    run(`unzip -o $source_folder/geonames/cities1000.zip -d $source_folder/geonames/`)
end


function load_geonames_data(source_folder;region = "")
    cities1000 = DataFrame(CSV.File("$source_folder/geonames/cities1000.txt", header=false))
    rename!(cities1000,:Column2 => :name, :Column5 => :latitude,
        :Column6 => :longitude, :Column9 => :country, :Column15 => :population,
        :Column18 => :region)
    cities1000 = cities1000[:,[:name, :latitude, :longitude, :country, :population, :region]]
    if isempty(region)
        return cities1000
    else
        return subset(cities1000, :region => r -> contains.(r,region))
    end
end

