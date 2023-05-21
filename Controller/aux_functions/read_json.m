function jsonStruct = read_json(filename)
    fid = fopen(filename); 
    raw = fread(fid,inf); 
    str = char(raw'); 
    fclose(fid); 
    jsonStruct = jsondecode(str);
end