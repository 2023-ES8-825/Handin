function [data] = getAllCSVDataInFolder(folder)
    folderinfo = fullfile(folder, '*.csv');
    files = dir(folderinfo);
    data = [];
    for i = 1:length(files)
        data = [data; readtable(strcat(folder,files(i).name))];
    end
end