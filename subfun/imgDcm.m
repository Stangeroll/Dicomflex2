classdef imgDcm < img
    properties
        dicomInfo = struct([]);
        version_imgDcm = '0.1';
    end
    
    methods (Static)
        function [img1, img2] = determineSpacingBetweenSlices(img1, img2)
            SpacingBetweenSlices = abs(img1.dicomInfo.sliceLocation-img1.dicomInfo.sliceLocation);
            img1.dicomInfo.SpacingBetweenSlices = SpacingBetweenSlices;
            img2.dicomInfo.SpacingBetweenSlices = SpacingBetweenSlices;
        end
    end
    
    methods
        function imgs = readDicom(imgs)
            for i = 1:numel(imgs)
                imgs(i).dicomInfo = dicominfo(imgs(i).path);
                imgs(i).data = dicomread(imgs(i).path);
                imgs(i).imgType = imgs(i).imgType;
                imgs(i).name = imgs(i).name;
                imgs(i).date = imgs(i).date;
                imgs(i).datenum = imgs(i).datenum;
                imgs(i).path = imgs(i).path;
            end

        end
        
        function imgs = rescaleDicom(imgs)
            for j = 1:numel(imgs)
                imgs(j).data = double(imgs(j).data).*imgs(j).dicomInfo.RescaleSlope + imgs(j).dicomInfo.RescaleIntercept;
            end
        end
                
        function voxVol = getVoxelVolume(imgs)
            imgInfo = {imgs.dicomInfo};
            for i = 1:numel(imgInfo)
                voxVol(i) = 0.001*imgInfo{i}.SpacingBetweenSlices*imgInfo{i}.PixelSpacing(1)*imgInfo{i}.PixelSpacing(2); % voxel volume in cm^3
                
            end
        end
        
        function img = imgDcm(path, imgPathes, imgName)
            if nargin ~= 0
                for j = 1:numel(imgPathes)
                    if iscell(path)
                        file = fullfile(path{j}, imgPathes(j).name);
                    else
                        file = fullfile(path, imgPathes(j).name);
                    end
                    a = dir(file);
                    try a = rmfield(a, 'bytes'); end
                    try a = rmfield(a, 'isdir'); end
                    try a = rmfield(a, 'folder'); end
                    
                    img(j) = imgDcm;
                    for fn = fieldnames(a)'
                        img(j).(fn{1}) = a.(fn{1});
                    end
                    img(j).imgType = imgName;
                    img(j).path = file;
                end
            end
        end
        
    end
end