function [rankVectors] = genRankVectors(topN, objDataset)

    num = length(objDataset);
    
    mapObj = containers.Map;
    
    for i = 1:length(objDataset)
        classname = objDataset(i).classname;
        if isKey(mapObj, classname)
            mapObj(classname) = [mapObj(classname),i];
        else
            mapObj(classname) = [i]; 
        end
    end
    
    allKeys = keys(mapObj);

    rankVectors = [];
    temp = [];
    for i = 1:num
        temp = [temp,1];
    end

    rankVectors = [rankVectors;temp];

    if length(allKeys) > 10
        return;
    end

    for i = 1:length(allKeys)
        newVectors = [];
        key = allKeys{i};
        value = mapObj(key);
        for m = 1:size(rankVectors,1)
            temp = rankVectors(m,:);
            for k = 1:topN
                temp(value) = k;
                newVectors = [newVectors;temp];
            end
            
        end
        rankVectors = newVectors;
    end
    
end