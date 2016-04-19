load('../Metadata/SUNRGBDMeta_1992_all_info.mat')
data_bed_vis = [];

for i = 1:length(SUNRGBDMeta_1992_all_info)
    disp(i);
    imageData = SUNRGBDMeta_1992_all_info(i);
    [vList, fList, wallVisData] = create_wall_vis(imageData);
    data_bed_vis = [data_bed_vis;wallVisData];
end