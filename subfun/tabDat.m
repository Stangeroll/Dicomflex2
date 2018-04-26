classdef tabDat
    properties
        version_tabDat  = '1.1';
        imgs = img.empty;   % will store all loaded raw images
        dataName = '';      % any kind of string describing the data (use for application specific stuff only)
        history = [];       % store history --- not implemented
        standardImgType = '';   % an arbitary defined name for the standard image of the specific appliaction
        
        patientName = '';
        sliceLocation = '';
        Various = {};   % used for application specific unspecific storage
    end
        
    methods(Static)
        % % % Segmentation functions % % %
        function boundMask = getBoundMask(imgData, coord)
            % create binary mask from image and coordiatne values
            % imgData       - 2D array
            % coord         - 2xN array with x,y coordinates
            imgSize = size(imgData);
            mask = zeros(imgSize);
            try coord = coord{1}; end
            
            mask(sub2ind(imgSize, coord(:,1), coord(:,2))) = 1;
            boundMask = imfill(mask,'holes');
        end
        
    end
        
    methods
        %% initialization
        function imgPathes = getImgPathes(tabDat, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            imgPathes = [];
            patDir = cfgDM.lastLoadPath;
            % search folders and images for each cfg.imgName
            for i = 1:size(cfgDM.imgNames,2)
                % check with which search string the correct folder is
                % found and search for images in the found folder
                % first found -> done:-)
                imgDir = []; j = 0;
                while ~(numel(imgDir)>0 | j==numel(cfgDM.imgSearchDir{i}))
                    j = j + 1;
                    imgDir = dir(fullfile(patDir, cfgDM.imgSearchDir{i}{j}));
                end
                
                % what to do if more than one entry
                if numel(imgDir)>1
                    Ind = listdlg('PromptString',{'Please select the correct ' cfgDM.imgNames{i} ' path:'},...
                        'SelectionMode','single', 'ListString', {imgDir.name},...
                        'ListSize', [550 150], 'OKString', 'Use Directory', 'CancelString', 'Abord');
                elseif numel(imgDir)==0
                    Ind = [];
                else
                    Ind = 1;
                end
                
                % select dir or stop if no entry found
                if isempty(Ind)
                    return
                else
                    imgDir = imgDir(Ind);
                    imgDir = fullfile(patDir, imgDir.name);
                end
                
                % gather all image infos
                % check with which search string is correct
                % first found -> done:-)
                imgPath = []; j = 0;
                while ~(numel(imgPath)>0 | j==numel(cfgDM.imgSearchName{i}))
                    j = j + 1;
                    imgPath = dir(fullfile(imgDir, cfgDM.imgSearchName{i}{j}));
                end
                
                imgTmp = feval(eval(['@(img) ' cfgDM.imgFcn '(imgDir, imgPath, cfgDM.imgNames{i})']));
                imgPathes = [imgPathes imgTmp];
            end
        end
        
        function d = initTabDat(tabDat, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            %% find possible data files
            datDirs = []; j = 0;
                while ~(numel(datDirs)>0 | j==numel(cfgDM.datFileSearchString))
                    j = j + 1;
                    datDirs = subdir(fullfile(cfgDM.lastLoadPath, cfgDM.datFileSearchString{j}));
                end
            
            %% if multiple data files found select one
            if isempty(datDirs)
                Ind = [];
            else
                for i = 1:numel(datDirs)
                    datDirs(i).filename = datDirs(i).name(numel(datDirs(i).folder)+2:end);
                end
                Ind = listdlg('PromptString',{'More than one file found. Please select a file or start new session:'},...
                    'SelectionMode','single', 'ListString', {datDirs.filename},...
                    'ListSize', [550 150], 'OKString', 'Use Segmentation File', 'CancelString', 'Start New Session');
            end

            %% start new session or load one
            if isempty(Ind)
                % START NEW SESSION
                imgPathes = tabDat.getImgPathes(d);
                if isempty(imgPathes)
                    return
                end
                %% first: read all images
                imgCount = numel(imgPathes);
                wb = waitbar(0, ['Image 1 of ' num2str(imgCount) '. Time left: inf']);
                wb.Name = 'reading image data';
                for i=1:numel(imgPathes)
                    t1 = tic;
                    imgs(i) = imgPathes(i).readDicom;
                    t2 = toc(t1);
                    time(i) = t2;
                    timeLeft = mean(time(i))*(imgCount-i);
                    waitbar(i/imgCount, wb, ['Image ' num2str(i) ' of ' num2str(imgCount) '. Time left: ' num2str(timeLeft, '%.0f') ' sec']);
                end
                close(wb);
            
                %% sort images and modify according to mode
                tabDat = tabDat.initImgArray(imgs, d);
                
                %% set the field "standardImgType" to the name in Cfg file
                tabDat = setStructArrayField(tabDat, 'standardImgType', {cfgDM.standardImgType});
                
                %% tabDat creation done
                
                d.dat = tabDat;
                d.saveDate = datetime.empty;
                
                %% set version infos
                % update d.version struct for classes
                d = tabDat.updateIsatVersionInfo(d);
                d = tabDat(1).imgs(1).updateIsatVersionInfo(d);
                
                % update d.version struct for cfg files
                d.setVersionInfo('DataModeCfg', cfgDM.cfgModeVersion, '');
                d.setVersionInfo('MasterModeCfg', cfgMM.cfgMasterVersion, '');
            else
                % LOAD SESSION FILE
                load(datDirs(Ind).name);
                
                %% release from class definition if it is object
                if ~exist('data')   % take care about old data files <20170107
                    % make struct from object -> probably information gets
                    % lost if the current tabDat class does not involve
                    % certain properties
                    data = arrayfun(@struct ,tabDat);
                    tabDat = tabDat(1);
                end
                
                if isfield(data, 'fatTresh')    % take care about old data files >20170107 & <20170113
                    % change fatTresh to fatThresh
                    data = setStructArrayField(data, 'fatThresh', {data.fatTresh});
                    data = arrayfun(@(x) rmfield(x, 'fatTresh'), data);
                end
                
                %% care about version info in data files <20170118 and <20170228                
                % version_tabDatFat
                if isfield(data, 'versionTabDatFat')
                    data = setStructArrayField(data, 'version_tabDatFat', {data.versionTabDatFat});
                    data = arrayfun(@(x) rmfield(x, 'versionTabDatFat'), data);
                end
                if isfield(data, 'tabDatChild1_version')
                    data = setStructArrayField(data, 'version_tabDatFat', {data.tabDatChild1_version});
                    data = arrayfun(@(x) rmfield(x, 'tabDatChild1_version'), data);
                end
                
                % version_tabDat
                if isfield(data, 'versionTabDat')
                    data = setStructArrayField(data, 'version_tabDat', {data.versionTabDat});
                    data = arrayfun(@(x) rmfield(x, 'versionTabDat'), data);
                end
                if isfield(data, 'tabDatParent_version')
                    data = setStructArrayField(data, 'version_tabDat', {data.tabDatParent_version});
                    data = arrayfun(@(x) rmfield(x, 'tabDatParent_version'), data);
                end
                
                % className
                if isfield(data, 'className')
                    data = arrayfun(@(x) rmfield(x, 'className'), data);
                end
                
                % saveDate
                if ~exist('saveDate')
                    saveDate = datetime.empty;
                end
                
                %% merge data in tabDat object: 
                % go to updateFcn of class and there go back to update Fcn of superclass
                tabDat = tabDat.(['update' class(tabDat)])(data, saveDate);
                
                if isempty(tabDat(1).dataName)
                    tabDat = setStructArrayField(tabDat, 'dataName', {[tabDat.patientName tabDat.imgs(1).dicomInfo.AcquisitionDate]}); % important for Figure Name
                end
                
                %% update version infos
                % update d.version struct for classes
                d = tabDat.updateIsatVersionInfo(d);
                d = tabDat(1).imgs(1).updateIsatVersionInfo(d);
                
                % update d.version struct for cfg files
                d.setVersionInfo('DataModeCfg', cfgDM.cfgModeVersion, '');
                d.setVersionInfo('MasterModeCfg', cfgMM.cfgMasterVersion, '');
                
                d.dat = tabDat;
                
            end
            
        end
        
        function d = updateIsatVersionInfo(tabDat, d)
            sc = superclasses(class(tabDat));
            sc = [{class(tabDat)}; sc];
            for i = 1:numel(sc)
                d.setVersionInfo(sc{i}, tabDat(1).(['version_' sc{i}]), ['update' sc{i}]);
                %                     removed at 20170228
                %                     d.setVersionInfo('tabDat', tabDat(1).tabDatParent_version, ['update' sc{1}]);
                %                     d.setVersionInfo(tabDat(1).tabDatChild1_name, tabDat(1).tabDatChild1_version, ['update' class(tabDat)]);
            end
        end
        
        %% GUI
        function d = plotIt(tabDat, d)
            imgAxis = d.handles.imgAxis;
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            datInd = d.tableRow;
            tabDat = d.dat(datInd);
            if ishandle(imgAxis)
                % Axis already exists!
                %% determine image to be shown
                imgDisplay = tabDat.getImg2Display(d);
                tabDat.history.plotImg = imgDisplay;
                imgDisplay.data = uint8(imgDisplay.data);
                
                %% crop image as defined in ZoomView
%                 if isfield(d.handles, 'zoomRect') && isvalid(d.handles.zoomRect)
%                     pos = d.handles.zoomRect.getPosition;
%                     imgDisplay.data = imgDisplay.data(pos(2):pos(2)+pos(4), pos(1):pos(1)+pos(3));
%                 end
                    
                %% update imgAxis with imgDisplay
                axes(imgAxis);
                axChilds = get(imgAxis, 'Children');
                if numel(axChilds)==0
                    hold all;    % without hold the ButtonDownFcn would be deleted
                    d.handles.imgDisplay = imshow(imgDisplay.data, 'DisplayRange', [], 'parent', imgAxis);
                    hold off;
                    d.handles.imgDisplay.ButtonDownFcn = d.handles.imgAxis.ButtonDownFcn;
                    d.handles.imgDisplay.HitTest = 'on';
                elseif numel(axChilds)==1
                    d.handles.imgDisplay = get(imgAxis, 'Children');
                    d.handles.imgDisplay.CData = imgDisplay.data;
                elseif numel(axChilds)>1
                    for i = 1:numel(axChilds)
                        delete(axChilds(i));
                    end
                    hold all;    % without hold the ButtonDownFcn would be deleted
                    d.handles.imgDisplay = imshow(imgDisplay.data, 'DisplayRange', []);
                    hold off;
                    d.handles.imgDisplay.ButtonDownFcn = d.handles.imgAxis.ButtonDownFcn;
                    d.handles.imgDisplay.HitTest = 'on';
                end
                
                %% define Display size
                if isfield(d.handles, 'zoomRect') && isvalid(d.handles.zoomRect)
                    pos = d.handles.zoomRect.getPosition;
                else
                    pos = [0 0 size(d.handles.imgDisplay.CData)];
                end
                d.handles.imgAxis.XLim = [pos(1) pos(1)+pos(4)];
                d.handles.imgAxis.YLim = [pos(2) pos(2)+pos(3)];
                
                %% post modifications with tabDatMODE
                tabDat.postPlot(d);
                
            else
                msgbox('no image Axis found')
            end
            d.dat(datInd) = tabDat;
            drawnow
        end
        
        function d = textIt(tabDat, d)
            textBox = d.handles.textBox;
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            tabDat = d.dat(d.tableRow);
            
            textBox.String = tabDat.getTextBoxLines(d);
            textBox.HorizontalAlignment = 'left';
            
        end
        
        function tabDat = showHotkeyInfo(tabDat, d)
            names = fieldnames(d.cfgDM.key);
            txt = (cellfun(@(x) string([d.cfgDM.key.(x) ' - ' x]), names, 'un', false));
            msgbox(txt)
        end
        
        %% Boundary management
        function d = useDraw(tabDat, d)
            if strcmp(d.activeKey, '')
                msgbox(['Use one of the following keys to select a Boundary to be changed first:'...
                    cell2mat(d.cfgDM.contour.names)]);
            else
                %% determine which contour type
                %nameInd = ismember(d.cfgDM.contour.keyAssociation, d.activeKey);
                contourName = d.cfgDM.contour.names{find(ismember(d.cfgDM.contour.keyAssociation, d.activeKey))};
                
                %% prepare variables
                datInd = d.tableRow;
                tabDat = d.dat(datInd);
                imgBase = tabDat.imgs(1);
                imgZero = zeros(size(imgBase.data));
                newCoord = round(d.lineCoord);
                BoundInd = tabDat.Boundaries.getBoundInd(tabDat.selectedBound);
                
                if BoundInd == 0;
                    % this gets executed if no old bound exists
                    % fill from newS to newE with pixel points and mit it
                    % old bound
                    emptyTabDat = feval(str2func(d.cfgDM.tabDatFcn));
                    cBound = emptyTabDat.Boundaries;
                    BoundInd = numel(tabDat.Boundaries)+1;
                    cBound(1).name = contourName;
                    [x y] = makeLinePoints(newCoord(1,1), newCoord(1,2), newCoord(end,1), newCoord(end,2));
                    oldCoord = [x' y'];
                else
                    cBound = tabDat.Boundaries(BoundInd);
                    oldCoord = tabDat.Boundaries(BoundInd).coord;
                end
                
                %% Connect newCoord to oldCoord
                % find start- end-point connection from new to old
                newS = newCoord(1,:);
                newE = newCoord(end,:);
                
                distS = pointDist(oldCoord, newS);
                [a indS] = min(distS);
                
                distE = pointDist(oldCoord, newE);
                [a indE] = min(distE);
                
                oldS = oldCoord(indS,:);
                oldE = oldCoord(indE,:);
                
                % fill new coordinates with pixel points
                for i=1:size(newCoord,1)-1
                    [x y] = makeLinePoints(newCoord(i,1), newCoord(i,2), newCoord(i+1,1), newCoord(i+1,2));
                    newCoord = [newCoord; [x; y]'];
                end
                
                % get connecting line coordinates
                [lineSX lineSY] = makeLinePoints(newS(1), newS(2), oldS(1), oldS(2));
                [lineEX lineEY] = makeLinePoints(newE(1), newE(2), oldE(1), oldE(2));
                newCoord = [newCoord; [lineEX; lineEY]'];
                newCoord = [newCoord; [lineSX; lineSY]'];
                newCoord = unique(newCoord, 'rows');
                
                %% Collect initially important AreaMasks
                % merge new and old Coords and generate allCoordMask
                allCoord = unique([newCoord; oldCoord], 'rows');
                
                % make all coordinate image
                Pxls = allCoord;
                allCoordMask = imgZero;
                for i=1:size(Pxls,1)
                    allCoordMask(Pxls(i,1),Pxls(i,2))=1;
                end
                allMask = imfill(allCoordMask, 'holes');
                
                % make new coordinate image
                Pxls = newCoord;
                newCoordMask = imgZero;
                for i=1:size(Pxls,1)
                    newCoordMask(Pxls(i,1),Pxls(i,2))=1;
                end
                
                % make old coordinate image
                Pxls = oldCoord;
                oldCoordMask = imgZero;
                for i=1:size(Pxls,1)
                    oldCoordMask(Pxls(i,1),Pxls(i,2))=1;
                end
                oldMask = imfill(oldCoordMask, 'holes');
                
                %% Generate all possible areas prepare them for merge
                % prepare areas
                allAreasMask = allMask&~allCoordMask;
                comp = bwconncomp(allAreasMask, 4);
                PixelIdxList = comp.PixelIdxList;
                % also take areas that consist only of new coord pxls
                newCoordAreaMask = newCoordMask&~oldCoordMask;
                comp = bwconncomp(newCoordAreaMask, 4);
                PixelIdxList = [PixelIdxList comp.PixelIdxList];
                areas = struct('areaPxls', [], 'areaMask', [], 'memberOfOld', [], 'memberOfExterior', []);
                
                % determine if area is inside, ouside or mainOldPart
                for i = 1:numel(PixelIdxList)
                    areas(i).areaPxls = PixelIdxList{i};
                    % now sort to oldMask or exterior
                    if sum(oldMask(areas(i).areaPxls)) == numel(areas(i).areaPxls)
                        areas(i).memberOfOld = 1;
                        areas(i).memberOfExterior = 0;
                    elseif sum(oldMask(areas(i).areaPxls)) == 0
                        areas(i).memberOfOld = 0;
                        areas(i).memberOfExterior = 1;
                    else
                        msgbox('area could not be associated to interior or exterior of mask')
                    end
                end
                
                % include coordinate points
                tic
                kernel3x3 = ones(3,3);
                kernel5x3 = ones(5,3);
                for i = 1:numel(areas)
                    
                    areas(i).areaMask = zeros(size(oldMask));
                    areas(i).areaMask(areas(i).areaPxls) = 1;
                    area = areas(i).areaMask;
                    
                    % merge with oldCoordMask
                    areaC = area|oldCoordMask; % area and Coordinates
                    areaC = uint8(areaC);
                    
                    % filter with
                    imgTmp1 = imfilter(areaC, kernel5x3);
                    imgTmp1 = imgTmp1>4;
                    imgTmp2 = imfilter(areaC, kernel5x3');
                    imgTmp2 = imgTmp2>4;
                    imgTmp = uint8(imgTmp1&imgTmp2);
                    
                    imgTmp(areaC==0) = 0;
                    imgTmp = imfilter(imgTmp, kernel3x3);
                    imgTmp = imgTmp>2;
                    imgTmp(areaC==0) = 0;
                    imgTmpO = imgTmp;
                    
                    % merge with newCoordMask
                    areaC = area|newCoordMask; % area and Coordinates
                    areaC = uint8(areaC);
                    
                    % filter with
                    imgTmp1 = imfilter(areaC, kernel5x3);
                    imgTmp1 = imgTmp1>4;
                    imgTmp2 = imfilter(areaC, kernel5x3');
                    imgTmp2 = imgTmp2>4;
                    imgTmp = uint8(imgTmp1&imgTmp2);
                    
                    imgTmp(areaC==0) = 0;
                    imgTmp = imfilter(imgTmp, kernel3x3);
                    imgTmp = imgTmp>2;
                    imgTmp(areaC==0) = 0;
                    imgTmpN = imgTmp;
                    
                    imgTmp = imgTmpN|imgTmpO;
                    
                    
                    
                    if areas(i).memberOfOld
                        areas(i).areaMask = uint8(imgTmp&oldMask);
                    elseif areas(i).memberOfExterior
                        areas(i).areaMask = uint8(imgTmp&~oldMask);
                    end
                end
                toc
                
                %% merge Areas
                Fmask = uint8(zeros(size(oldMask)));
                oldAreasInd = find([areas.memberOfOld]);
                [a ind] = max(arrayfun(@(x) numel(x.areaPxls), areas(oldAreasInd)));
                oldAreaInd = oldAreasInd(ind);
                
                for i = 1:numel(areas)
                    currAreaMask = logical(areas(i).areaMask);
                    if i==oldAreaInd
                        % if area is the biggest are in the region of the
                        % old mask, than keep it
                        Fmask(currAreaMask) = 1;
                    else
                        if areas(i).memberOfOld
                            % if area is not the biggest are in the region of the
                            % old mask, than dont keep it
                            % additional: if the area gets rejected, the
                            % coordinates must be excluded from rejection
                            
                            Fmask(currAreaMask&~allCoordMask) = 0;
                        elseif areas(i).memberOfExterior
                            % if area is in the region of the exterior, than keep it
                            Fmask(currAreaMask) = 1;
                        end
                    end
                end
                
                % use biggest Fmask area as Fmask
                comp = bwconncomp(Fmask, 4);
                [a ind] = max(arrayfun(@(x) numel(x{1}), comp.PixelIdxList));
                FmaskPxls = comp.PixelIdxList{ind};
                Fmask = uint8(zeros(size(oldMask)));
                Fmask(FmaskPxls) = 1;
                Fmask = imfill(Fmask, 'holes');
                
                %% store new bound
                b = bwboundaries(Fmask);
                cBound.coord = b{1};
                tabDat.Boundaries(BoundInd) = cBound;
                %tabDat.Boundaries(find(nameInd)).coord = ;
                %tabDat = tabDat.updateAllVol;
                %tabDat.segmentDone = 1;
                
                %% write back to isat object
                d.dat(datInd) = tabDat;
                
            end
        end
        
        function d = copyBound(tabDat, d)
            d.history.copyTabDat = d.dat(d.tableRow);
        end
        
        function d = pasteBound(tabDat, d)
            nBounds = d.history.copyTabDat.Boundaries;
            oBounds = d.dat(d.tableRow).Boundaries;
            tmp = tabDat;
            emptyBound = tmp.Boundaries;
            
            for i=1:numel(nBounds)
                nBound = nBounds(i);
                tmpBound = eval(class(nBound));
                tmpBound(1).name = nBound.name;
                tmpBound.coord = nBound.coord;
                ind = oBounds.getBoundInd(nBound.name); % find same name in oBounds to replace bound
                if ind == 0
                    % create new bound
                    oBounds(end+1) = tmpBound;
                else
                    % replace bound
                    oBounds(i) = tmpBound;
                    
                end
            end
            d.dat(d.tableRow).Boundaries = oBounds;
        end
        
        %% Image Management
        function img = getImgOfType(tabDat, type)
            typeInd = find(ismember({tabDat.imgs.imgType}, type));
            if isempty(typeInd)
                msgbox(['Images of type ' type ' not found!']);
            else
                img = tabDat.imgs(typeInd);
            end
        end
        
        function img = getStandardImg(tabDat)
            typeInd = arrayfun(@(x) find(ismember({x.imgs.imgType}, {x.standardImgType})), tabDat, 'un', false); typeInd = typeInd{1};
            if numel(typeInd)>1
                %msgbox(['More than one ' tabDat.standardImgType ' image found! First image is used.'], 'unspecific image information');
                typeInd = typeInd(1);
            end
            for i = 1:numel(tabDat)
                img(i) = tabDat(i).imgs(typeInd(i));
            end
            
        end
        
        %% Processing
        function saveTabDat(tabDat, path, d)
            path2 = dir(path);
            try
            if path2.isdir
                path = fullfile(path, 'tmpdata.m');
            else
            end
            end
            
            data = arrayfun(@struct ,tabDat); % release from class definition (think about verion flexibility)
            saveDate = datetime('now');
            versions = d.versions;
            save(path, 'data', 'saveDate', 'versions');
        end
        
        %% Fitting and so
        function d = showFitInFitTool(tabDat, d)
            boundInd = tabDat.Boundaries.getBoundInd(tabDat.selectedBound);
            if ~isempty(boundInd)
                cBound = tabDat.Boundaries(boundInd);
                if isfield(d.handles, 'FT') && isvalid(d.handles.FT) && ishandle(d.handles.FT.handles.figure)
                    tabDat.updateFitTool(d, cBound);
                else
                    tabDat.startFitTool(d, cBound);
                end
            else
            end
            d.handles.FT.handles.sendData.Callback = @(varargin)tabDat.useFitToolData(d, d.handles.FT,varargin);
            figure(d.handles.figure);
        end
        
        function d = startFitTool(tabDat, d, cBound)
            d.handles.FT = FitTool(cBound.FitObj.getDepParNames{1}, cBound.FitObj.yData, cBound.FitObj.getIndepParNames{1}, cBound.FitObj.xData, 'fittype', cBound.FitObj.ftype);
            figure(d.handles.figure);
            d.handles.FT.fitInfo.current = cBound.FitObj.values;
            d.handles.FT.fittype2fitInfo;
            d.handles.FT.fitInfo2gui;
        end
        
        function d = updateFitTool(tabDat, d, cBound)
            d.handles.FT.fitInfo.current = cBound.FitObj.values;
            d.handles.FT.fitInfo.ftype = cBound.FitObj.ftype;
            d.handles.FT.newRawData(cBound.FitObj.getDepParNames{1}, cBound.FitObj.yData, cBound.FitObj.getIndepParNames{1}, cBound.FitObj.xData);
            d.handles.FT.fittype2fitInfo;
            d.handles.FT.fitInfo2gui;
        end
        
        function tabDat = useFitToolData(tabDat, d, dFT, varargin)
            % update current and fittype data
            %tabDat.fitData.current = dFT.fitInfo.current;
            %tabDat.fitData.ftype = dFT.fitInfo.ftype;
            %d.dat(d.tableRow) = tabDat;
            
            tabDat.BoundData(tabDat.selectedBound).ftype = dFT.fitInfo.ftype;
            tabDat.BoundData(tabDat.selectedBound).current = dFT.fitInfo.current;
            tabDat.BoundData(tabDat.selectedBound).gof = dFT.fitInfo.gof;
            d.dat(d.tableRow) = tabDat;
            d.tableCellSelect;
        end
        
        %% class methods
        function tabDat = updatetabDat(tabDat)
            tabDat;
        end
        
        function tabDat = tabDat(tabArray)
            
        end
    end
end
