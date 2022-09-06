function download_hifld_data(source_folder)
    println("HIFLD TODO")
end



function load_hifld_data()
    return load_hifld_bus(), load_hifld_gen(),
        load_hifld_line()
end


function load_hifld_bus(vmin = 100)
    substation = DataFrame(CSV.File("sources/hifld/Electric_Substations.csv"))
    rename!(substation, :ID => :id, :NAME => :name, :STATE => :state, :MIN_VOLT => :vmin,
        :MAX_VOLT => :vmax, :LATITUDE => :latitude, :LONGITUDE => :longitude, :TYPE => :type,
        :STATUS => :status)
    substation = substation[!,[:id, :name, :type, :latitude, :longitude, :vmin, :vmax, :status, :state]]
    return subset(substation, :vmin => v -> v .> vmin)
end


function load_hifld_line(vmin = 100)
    line = DataFrame(CSV.File("sources/hifld/Electric_Power_Transmission_Lines.csv"))
    rename!(line, :SUB_1 => :sub1, :SUB_2 => :sub2, :VOLTAGE => :voltage,
        :SHAPE__Length => :line_length, :STATUS => :status, :TYPE => :type)
    line = line[!,[:sub1, :sub2, :voltage, :line_length, :status, :type]]
    return subset(line, :vmin => v -> v .> vmin)
end


function load_hifld_gen()
    gen = DataFrame(CSV.File("sources/hifld/Power_Plants.csv"))
    rename!(gen, :NAME => :name, :SUB_1 => :sub1, :SUB_2 => :sub2,
        :PRIM_FUEL => :type, :NET_GEN => :capacity, :LATITUDE => :latitude,
        :LONGITUDE => :longitude)
    return gen[!,[:name, :sub1, :sub2, :type, :capacity, :latitude, :longitude]]
end


western = [-119.06645 31.797572
-102.414173 31.034876
-101.633762053706 40.0499272989929
-103.118356536008 49.6346787265775
-108.589397176027 60.9311264252563
-144.436110463848 60.6250856818046
-132.087023908378 39.8094146225842]
