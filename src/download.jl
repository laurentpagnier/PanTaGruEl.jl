export download_data

function download_data(
    source_folder::String,
)
    create_dir(source_folder)
    download_bundesnetzagentur_data(source_folder)
    download_datagouvfr_data(source_folder)
    download_entsoe_data(source_folder)
    download_geonames_data(source_folder)
    download_gridkit_data(source_folder)
    download_hifld_data(source_folder)
    download_naturalearth_data(source_folder)
    download_wri_data(source_folder)
    nothing
end
