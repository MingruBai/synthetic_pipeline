function main_test(ID)

sceneMetadata_job = [];

similarityOutputDir = '/n/fs/sunhome/Yinda_2303/output/';
synResultDir = '/n/fs/sunhome/results_yinda/';

addpath(genpath('.'));
load('/n/fs/sunhome/SUNRGBDSynToolbox/Metadata/SUNRGBDMeta_best_Oct19.mat');

Rt = [1 0 0 0;0 1 0 0;0 0 1 0];

topN = 3;
prime1 = 15485867;
prime2 = 32452843;


for imageId = (ID-1)*10+1:ID*10
    
    disp(['Processing ',num2str(imageId),': ',SUNRGBDMeta_best_Oct19(imageId).sequenceName,'...']);
    
    %Hashset that makes sure no identical scenes are produced:
    VPhashset = [];
    
    %Skip scene if no .txt file in output folder:
    if ~any(size(dir([similarityOutputDir,'scene',num2str(imageId),'/*.txt']),1))
        disp(['Skip scene ',num2str(imageId),'.']);
        continue;
    end
    
    %Create folder for depth map and mat:
    sequenceName = SUNRGBDMeta_best_Oct19(imageId).sequenceName;
    destination = [synResultDir,sequenceName];
    system(['mkdir -p ', destination]);
    
    %Image data and object data:
    imageData = SUNRGBDMeta_best_Oct19(imageId);
    objDataset = imageData.groundtruth3DBB;
    
    %Get rotation and translation matrix:
    dist = 0;
    maxObjArea = 0;
    for i = 1:length(objDataset)
        objData = objDataset(i);
        objX = 2*objData.coeffs(1);
        objY = 2*objData.coeffs(2);
        objArea = objX*objY;
        if (objArea > maxObjArea)
            maxObjArea = objArea;
            centr = objData.centroid;
            dist = (centr(1)^2+centr(2)^2+centr(3)^2)^0.5;
        end
    end
    
    RtMatrices = {};
    for i = 1:3
        delta = -0.1 + (i-1)*0.1;
        rMatrix = [cos(delta), -sin(delta), 0; sin(delta), cos(delta), 0; 0, 0, 1];
        shiftVector = [-2*dist*sin(delta/2.0),0,0];
        RtMatrices{end+1} = [rMatrix shiftVector'];
    end
    
    %Create rank vectors:
    [rankVectors] = genRankVectors(topN, objDataset);
    
    %Get similarity output data:
    similarityOutputPath = [similarityOutputDir,'scene',num2str(imageId)];
    outputFilelist = [];
    for o=1:length(objDataset)
        temp = dir([similarityOutputPath,'/',num2str(o),'_',objDataset(o).classname,'_list.txt']);
        outputFilelist = [outputFilelist;temp];
    end
    all_output_data = {};
    all_output_data_best = [];
    
    if length(objDataset)~=length(outputFilelist)
        disp(['objDataset and outputFilelist not equal: ',num2str(imageId)]);
        continue;
    end
    
    for i = 1:length(objDataset)
        fname = outputFilelist(i).name;
        fpath = [similarityOutputPath,'/',fname];
        fid = fopen(fpath,'r');
        file_text=fread(fid, inf, 'uint8=>char')';
        fclose(fid);
        all_output_data{end+1} = file_text;
        
        file_lines = regexp(file_text, '\n+', 'split');
        if length(file_lines) <= 1
            bestScore = 1000;
        else
            line1 = file_lines{1};
            line1list = strsplit(line1);
            bestScore = str2num(line1list{2});
        end
        all_output_data_best = [all_output_data_best; bestScore];
    end
    
    %Cache:
    VCache = cell(length(objDataset),topN);
    FCache = cell(length(objDataset),topN);
    RVCache = cell(length(objDataset),topN);
    CCache = cell(length(objDataset),topN);
    RMCache = cell(length(objDataset),topN);
    
    %For each rank vector, try generating an image:
    for r = 1:size(rankVectors,1)
        
        sceneMetadata = imageData;
        
        rankVector = rankVectors(r,:);
        bestModelPath = {};
        shouldStop = false;
        
        obj_metadata = [];
        
        for i = 1:length(outputFilelist)
            
            file_text=all_output_data{i};
            
            
            objname = objDataset(i).classname;
            bestScore = all_output_data_best(i);
            for objid = 1:length(objDataset)
                if strcmp(objname,objDataset(objid).classname)
                    
                    %If two same objects have different rank, disgard:
                    if rankVector(objid)~=rankVector(i)
                        shouldStop = true;
                        break;
                    end
                    
                    %same obj use same list of models:
                    if all_output_data_best(objid) < all_output_data_best(i)
                        file_text = all_output_data{objid};
                    end
                end
            end
            
            
            file_lines = regexp(file_text, '\n+', 'split');
            
            if length(file_lines) - 1 < rankVector(i)
                bestPath = 'no_model';
            else
                line1 = file_lines{rankVector(i)};
                line1list = strsplit(line1);
                bestPath = line1list{1};
            end
            
            bestModelPath{end+1}=bestPath;
        end
        
        if shouldStop
            continue;
        end
        
        allV = [];
        allF = [];
        
        wallData = imageData.gtCorner3D;
        
        if length(wallData ~= 0)
            [wallV, wallF] = create_wall(wallData);
            allV = [allV; wallV];
            allF = [allF; wallF];
        end
        
        totalPrevV = length(allV);
        %create objects:
        nomodel = false;
        
        for i = 1:length(objDataset)
            objId = i;
            objData = objDataset(objId);
            keyword = objData.classname;
            
            bestPath = bestModelPath{i};
            
            if strcmp(bestPath,'no_model')
                nomodel = true;
                continue;
            end
            
            if length(VCache{i,rankVector(i)})==0
                bestPath = ['/n/fs/sunhome/Yinda_2303/',bestPath];
                [vList,fList,ratioVector,centroid,rMatrix] = create_obj(objData, bestPath);
                
                sceneMetadata.groundtruth3DBB(i).coeffs = ratioVector;
                
                VCache{i,rankVector(i)} = vList;
                FCache{i,rankVector(i)} = fList;
                RVCache{i,rankVector(i)} = ratioVector;
                CCache{i,rankVector(i)} = centroid;
                RMCache{i,rankVector(i)} = rMatrix;
            else
                vList = VCache{i,rankVector(i)};
                fList = FCache{i,rankVector(i)};
                ratioVector = RVCache{i,rankVector(i)};
                centroid = CCache{i,rankVector(i)};
                rMatrix = RMCache{i,rankVector(i)};
            end
            
            pathlist = regexp(bestPath,'/','split');
            objclassname = pathlist{end-1};
            objfilename = pathlist{end};
            if findstr('_',objfilename)
                objsource = 'ModelNet40';
            else
                objsource = 'ShapeNetCore';
            end
            
            obj_metadata(i).source = objsource;
            obj_metadata(i).modelID = objfilename;
            obj_metadata(i).class = objclassname;
            obj_metadata(i).coeffs = ratioVector;
            obj_metadata(i).centroid = centroid;
            obj_metadata(i).rMatrix = rMatrix;
            
            
            allV = [allV;vList];
            fList = fList + totalPrevV;
            allF = [allF;fList];
            totalPrevV = totalPrevV + size(vList,1);
        end
        
        
        hash = length(allV)*prime1+length(allF)*prime2;
        if ismember(hash,VPhashset)
            continue;
        end
        
        VPhashset = [VPhashset,hash];
        
        tensorname = [num2str(rankVector(1))];
        for t=2:length(rankVector)
            tensorname = [tensorname,'_',num2str(rankVector(t))];
        end
        
        for m = 2:2%1:3
            Rt = RtMatrices{m};
            sceneMetadata.depthpath = [destination,'/',tensorname,'_angle',num2str(m),'.png'];
            sceneMetadata.Rt = Rt;
            sceneMetadata_job = [sceneMetadata_job;sceneMetadata];
            write_img(sceneMetadata.depthpath,allV,allF,imageData,Rt);
            write_img_tensor([destination,'/',tensorname,'_angle',num2str(m),'.tensor'],allV,allF,imageData,Rt);
            %save([destination,'/',tensorname,'_angle',num2str(m),'.mat'],'obj_metadata');
        end
        %write_obj([fixed_angle_dest,'/',tensorname,'.png'],allV,allF);
        
        
    end
    
    
end
save(['/n/fs/sunhome/results_yinda/Metadata/job',num2str(ID),'.mat'],'sceneMetadata_job');
end
