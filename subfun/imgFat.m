classdef imgFat < imgDcm
    properties
        version_imgFat = '0.1';
    end
    
    methods (Static)
    end
    
    methods
        function patientName = patientName(img)
            dcmInfo = img.dicomInfo;
                if isfield(dcmInfo.PatientName, 'FamilyName') && isfield(dcmInfo.PatientName, 'GivenName')
                    patientName = [dcmInfo.PatientName.FamilyName '_' dcmInfo.PatientName.GivenName];
                elseif isfield(dcmInfo.PatientName, 'FamilyName') && ~isfield(dcmInfo.PatientName, 'GivenName')
                    patientName = [dcmInfo.PatientName.FamilyName];
                elseif ~isfield(dcmInfo.PatientName, 'FamilyName') && isfield(dcmInfo.PatientName, 'GivenName')
                    patientName = [dcmInfo.PatientName.GivenName];
                elseif ~isfield(dcmInfo.PatientName, 'FamilyName') && ~isfield(dcmInfo.PatientName, 'GivenName')
                    patientName = [];
                end
                if isempty(patientName)
                    hdialog = msgbox({'There exits no patient name!' 'Please fill out the following form after pressing OK' 'In case of problems contact the developer.'});
                    uiwait(hdialog);
                    Names = inputdlg({'Family Name:', 'Given Name:'}, 'Enter patient name')
                    patientName = [Names{1} '_' Names{2}];
                end
        end
        
        function sliceLocation = sliceLocation(img)
            sliceLocation = sprintf('%.1f', img.dicomInfo.SliceLocation);
        end
        
        function sliceThickness = sliceThickness(img)
            sliceThickness = sprintf('%.1f', img.dicomInfo.SliceThickness);
        end
        
        function slicePosition = slicePosition(img)
            slicePosition = sprintf('%.1f', img.dicomInfo.ImagePositionPatient(3));
        end        
        
        function img = imgFat(path, imgPathes, imgName)
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
                    
                    img(j) = imgFat;
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