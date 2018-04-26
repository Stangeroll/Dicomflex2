classdef tabDatFatSegmentIOphase<tabDat
    properties
        %% these properties must exist
        version_tabDatFatSegmentIOphase = '1.2';
        
        %% these properties are just for application specific use
        Boundaries = boundary.empty;
        BoundData = {}; % open for enties to be come
        selectedBound = '';
        segmentDone = logical.empty;    % 0 means not semented, 1 means segemented
        Loc1 = '';
        Loc2 = '';
        fatThresh = 0;
    end
    
    methods(Static)
        
    end
    
    methods
        % % % data loading % % %
        function tabDat = initImgArray(tabDat, imgs, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            % sort images and init dat struct
            sliceLocs = arrayfun(@(x) x.sliceLocation, imgs, 'un', false);
                % determine SpacingBetweenSlices
            sliceLocsSort = sort(unique(cellfun(@str2num, sliceLocs)), 'ascend');
            SpacingBetweenSlices = diff(sliceLocsSort);
            SpacingBetweenSlices(end+1) = SpacingBetweenSlices(end);
            SpacingBetweenSlices = round(SpacingBetweenSlices*1000)/1000;   % round to 0.000
            if sum(SpacingBetweenSlices-min(SpacingBetweenSlices))~=0
                uiwait(warndlg('Spacings between slices are not consistent! Do not ingnore this message!'));
            else
                SpacingBetweenSlices = SpacingBetweenSlices(1);
            end
            for i =1:numel(imgs)
                if ~isfield(imgs(i).dicomInfo, 'SpacingBetweenSlices')
                    imgs(i).dicomInfo.SpacingBetweenSlices = SpacingBetweenSlices;
                end
            end
                % END determine SpacingBetweenSlices
            i=0;
            for sliceLoc = unique(sliceLocs)
                i=i+1;
                indImg = find(ismember(sliceLocs, sliceLoc(1)));
                tabDat(i) = feval(str2func(cfgDM.tabDatFcn));
                tabDat(i).imgs = imgs(indImg);
                tabDat(i).imgs.dicomInfo
                tabDat(i).patientName = imgs(indImg(1)).patientName;
                tabDat(i).dataName = tabDat(i).patientName;
                tabDat(i).sliceLocation = imgs(indImg(1)).sliceLocation;
                tabDat(i).segmentDone = false;
            end
            [a sortInd] = sort(cellfun(@(x) str2num(x) ,{tabDat.sliceLocation}), 'ascend');
            tabDat = tabDat(sortInd);
            tabDat = setStructArrayField(tabDat, 'Loc1', {cfgDM.table.ColumnFormat{5}{1}});
            tabDat = setStructArrayField(tabDat, 'Loc2', {cfgDM.table.ColumnFormat{6}{1}});
        end
        
        % % % GUI update % % %
        function imgDisplay = getImg2Display(tabDat, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            tabDat = d.dat(d.tableRow);
            %% determine image to be shown
            stdImgType = cfgDM.standardImgType;
            switch cfgDM.imageDisplayMode
                case 'Water only'
                    imgDisplay = tabDat.waterImg;
                case 'Fat only'
                    imgDisplay = tabDat.fatImg;
                case 'Out Phase only'
                    imgDisplay = tabDat.getImgOfType('OutPhase');
                case 'In Phase only'
                    imgDisplay = tabDat.getImgOfType('InPhase');
                case 'All Four'
                    msgbox('All Four: not implementet!');
                case stdImgType
                    imgDisplay = tabDat.getImgOfType(stdImgType);
                    
            end
            
            %% convert
            
            imgDisplay = imgDisplay.scale2([0 255]);
        end
                
        function postPlot(tabDat, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            tabDat = d.dat(d.tableRow);
            imgAxis = d.handles.imgAxis;
            %% plot segmentation
            contCoord = {};
            colors = {};
            for i=1:numel(tabDat.Boundaries)
                cBound = tabDat.Boundaries(i);
                contCoord{i} = {cBound.coord};
                colors(i) = cfgDM.contour.colors(find(ismember(cfgDM.contour.names, cBound.name)));
            end
            % plot contours
            d.handles.contour = isat.drawContour(imgAxis, contCoord, colors);
            %% plot line for miror axis
            if cfgDM.contour.showMirrorAxis
                coord = [d.dat.Various];
                if numel(coord)>1
                    msgbox('to many axes found in all data! check at saveMirroredXls.');
                elseif numel(coord)==1
                    
                    isat.drawContour(imgAxis, {{[coord{1}.mirrorAxisY{1} coord{1}.mirrorAxisX{1}]}}, {'green'});
                end
            end
            %% plot rect
            if cfgDM.contour.showFemurBox
                try 
                    coord = bwboundaries(d.dat(d.Various.femurBoxInd).Various.femurBox);
                    isat.drawContour(imgAxis, {coord}, {[1 1 1]});
                    
                    pos = d.Various.femurBoxSize;
                    T1 = text(0, 0, '', 'Parent', d.handles.imgAxis, 'Color', 'white');
                    T2 = text(0, 0, '', 'Parent', d.handles.imgAxis, 'Color', 'white');
                    T1.String = num2str(round(pos(3)));
                    T1.Position = [pos(1)+pos(3)/2-5, pos(2)-6];
                    T2.String = num2str(round(pos(4)));
                    T2.Position = [pos(1)+pos(3)+2, pos(2)+pos(4)/2];
                catch
                    uiwait(msgbox('could not draw box'));
                end
            end
            %% TopLeft text in Image
            imgText = [cfgDM.imageDisplayMode ' - Slice ' num2str(d.tableRow)];
            d.handles.imgText = text(10,10, imgText, 'Parent', imgAxis, 'Color', 'white');
            d.handles.imgText.HitTest = 'off';
            %% boundary text im image
            for i = 1:numel(tabDat.Boundaries)
                if ~isempty(tabDat.Boundaries(i).coord)
                    % plot annotation
                    txt = tabDat.Boundaries(i).name;
                    text(max(tabDat.Boundaries(i).coord(:,2)), max(tabDat.Boundaries(i).coord(:,1)), txt, 'Parent', d.handles.imgAxis, 'Color', colors{i});
                end
            end
        end
        
        function d = histIt(tabDat, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            datInd = d.tableRow;
            ctabDat = d.dat(datInd);
            histAxis = d.handles.histAxis;
            axes(histAxis);
            visInd = ctabDat.Boundaries.getBoundInd('visceralBound');
            
            % determine histData to be plotted in hist
            if visInd==0
                histData = ctabDat.waterImg.data;
            else
                visBound = ctabDat.Boundaries(visInd);
                VatMask = logical(ctabDat.getBoundMask(ctabDat.imgs(1).data, ctabDat.Boundaries(visInd).coord));
                histData = ctabDat.waterImg.data(VatMask);
            end
            
            % plot hist with as many bars as the data has possible values
            if isfield(d.handles, 'histPlot') && ishandle(d.handles.histPlot)   % use current histogram
                %[histDat histInd] = histcounts(histData, 'NumBins', max(histData)/10)
                d.handles.histPlot.Data = histData;
                d.handles.histPlot.NumBins = max(max(histData))/10;
                d.handles.histPlot.BinLimitsMode = 'manual';
                d.handles.histPlot.BinLimits = [min(min(histData)) max(max(histData))];
                d.handles.histAxis.YLim = [0 max(d.handles.histPlot.Values)];
                
            else    % create histogram because not created, yet
                hold all;
                d.handles.histPlot = histogram(histData);
                d.handles.histPlot.NumBins = max(max(histData))/10;
                d.handles.histPlot.BinLimitsMode = 'manual';
                d.handles.histPlot.BinLimits = [min(min(histData)) max(max(histData))];
                d.handles.histPlot.EdgeColor = d.cfgMM.apperance.color4;
                d.handles.histPlot.FaceColor = d.cfgMM.apperance.color4;
                d.handles.histAxis.YTick = [];
                d.handles.histAxis.Color = d.cfgMM.apperance.color3;
                d.handles.histAxis.Box = 'on';
                d.handles.histPlot.HitTest = 'off';
                hold off;
            end
            
            if visInd==0   % set hist line to fatThresh value
                try delete(d.handles.histLine); end
            else
                % update histogram threshold line
                d = ctabDat.updateHistLine(d);
            end
            drawnow
            
            %% check if slice is done
            ctabDat = ctabDat.setSegmentDone;
            d.dat(datInd) = ctabDat;
        end
        
        function d = updateHistLine(tabDat, d)
            if isfield(d.handles, 'histLine') && isvalid(d.handles.histLine)    % use existing line
                d.handles.histLine.XData = [tabDat.fatThresh tabDat.fatThresh];
                d.handles.histLine.YData = [0 d.handles.histAxis.YLim(2)];
            else    % create new line
                d.handles.histLine = line([tabDat.fatThresh tabDat.fatThresh], [0 d.handles.histAxis.YLim(2)], 'parent', d.handles.histAxis);
                d.handles.histLine.LineWidth = 3;
                d.handles.histLine.LineStyle = ':';
                d.handles.histLine.Color = 'green';
                d.handles.histLine.HitTest = 'off';
            end
        end
        
        function lines = getTextBoxLines(tabDat, d)
            textBox = d.handles.textBox;
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            tabDat = d.dat(d.tableRow);
            
            % are fat values up to date?
            if tabDat.segmentDone == true % 1 means segmented, but not fitted
                [d tabDat] = tabDat.calcFatAveraged(d);
            end
            
            lines = string.empty;
            count = 0;
            for i=1:numel(tabDat.Boundaries)
                cBound = tabDat.Boundaries(i);
                parameters = cBound.FitObj.parameters;
                values = cBound.FitObj.values;
                for j = 1:numel(parameters)
                    count = count+1;
                    lines(count) = string([cBound.name ' ' parameters{j} ': ' sprintf('%.1f', values(j))]);
                end
            end
        end
        
        % % % GUI Interaction % % %
        function tabDat = tableEdit(tabDat, select)
            switch select.Source.ColumnName{select.Indices(2)}
                case 'Done'
                    if select.NewData == false
                        tabDat = tabDat.clearSegment
                    end
            end
        end
        
        function tabDat = keyPress(tabDat, d, key)
            cfgDM = d.cfgDM;
            key = key.Key;
            d.handles.figure.WindowKeyReleaseFcn = {@d.keyRelease};
            %d.handles.figure.WindowKeyPressFcn = '';
            switch key
                case cfgDM.contour.keyAssociation  % normal grayed out contour display
                    tabDat.selectedBound = cfgDM.contour.names(find(ismember(cfgDM.contour.keyAssociation, key)));
                    imgAxis = d.handles.imgAxis;
                    % delete axis childs
                    if exist('d.handles.contour')
                        for a = d.handles.contour
                            delete(a);
                        end
                    end
                    
                    %% Plot Contours grayed out
                    contCoord = {};
                    colors = {};
                    for i=1:numel(tabDat.Boundaries)
                        cBound = tabDat.Boundaries(i);
                        contCoord{i} = {cBound.coord};
                        if isequal({cBound.name}, tabDat.selectedBound)
                            colors(i) = cfgDM.contour.colors(find(ismember(cfgDM.contour.names, tabDat.selectedBound)));
                        else
                            colors{i} = [0.1 0.1 0.1];
                        end
                    end
                    % plot contours
                    d.handles.contour = isat.drawContour(imgAxis, contCoord, colors);
                    
                    pause(0);
                    
                case cfgDM.key.DeleteContour  % delete selected contour
                    disp('keyDelCont')
                    % delete contour if one contour is selected
                    otherKeys = d.activeKey(~ismember(d.activeKey, {key}))
                    if numel(otherKeys) > 1
                        disp('to many keys pressed');
                    else
                        switch otherKeys{1}
                            case cfgDM.contour.keyAssociation
                                contourName = cfgDM.contour.names(find(ismember(d.cfgDM.contour.keyAssociation, otherKeys{1})))
                                
                                boundInd = tabDat.Boundaries.getBoundInd(tabDat.selectedBound);
                                if ~isempty(boundInd)
                                    tabDat.Boundaries(boundInd) = [];
                                    tabDat.segmentDone = false;
                                end
                                
                        end
                    end

                case cfgDM.key.ShowVat  % show vat
                    tabDat.vatOverlay(d);
            end
            d.cfgDM = cfgDM;
        end
        
        function keyRelease(tabDat, d, keys)
            keys;
            d.handles.figure.WindowKeyPressFcn = @d.keyPress;
            
            
            d.handles.imgDisplay.AlphaData = 1;
            d.tableCellSelect;
        end
        
        function imgAxisButtonDown(tabDat, d, hit)
            switch d.activeKey{1}
                case ''
                otherwise
                d.lineCoord = [d.handles.imgAxis.CurrentPoint(1,2) d.handles.imgAxis.CurrentPoint(1,1)];
                d.activeMouse = d.handles.figure.SelectionType;
                
                d.handles.draw = isat.drawContour(d.handles.imgAxis, {{d.lineCoord}}, {'green'});
                d.handles.draw = d.handles.draw{1};
                if isempty(d.handles.figure.WindowButtonMotionFcn) | isempty(d.handles.figure.WindowButtonMotionFcn)
                    d.handles.figure.WindowButtonMotionFcn = {@tabDat.imgAxisButtonMotion, d};
                    d.handles.figure.WindowButtonUpFcn = {@tabDat.imgAxisButtonUp, d};
                else
                    msgbox('WindowButtonMotionFcn and WindowButtonUpFcn are already set');
                end
            end
        end
        
        function imgAxisButtonMotion(tabDat, a, b, d)
            newC = [d.handles.imgAxis.CurrentPoint(1,2) d.handles.imgAxis.CurrentPoint(1,1)];
            d.lineCoord = [d.lineCoord; newC];
            d.handles.draw.XData = d.lineCoord(:,2);
            d.handles.draw.YData = d.lineCoord(:,1);
            drawnow;
        end
        
        function imgAxisButtonUp(tabDat, a, b, d)
            d.handles.figure.WindowButtonMotionFcn = '';
            d.handles.figure.WindowButtonUpFcn = '';
            d = d.dat.useDraw(d);
        end
        
        function histAxisButtonDown(tabDat, d, hit)
            % calc VAT
            tabDat.fatThresh = d.handles.histAxis.CurrentPoint(1,1);
            
            d.dat(d.tableRow) = tabDat;
            
            tabDat.updateHistLine(d);
            
            tabDat.vatOverlay(d);
            
            if isempty(d.handles.figure.WindowButtonMotionFcn) | isempty(d.handles.figure.WindowButtonMotionFcn)
                d.handles.figure.WindowButtonMotionFcn = {@tabDat.histAxisButtonMotion, d};
                d.handles.figure.WindowButtonUpFcn = {@tabDat.histAxisButtonUp, d};
            else
                msgbox('WindowButtonMotionFcn and WindowButtonUpFcn are already set');
            end
        end
        
        function histAxisButtonMotion(tabDat, a, b, d)
            tabDat.fatThresh = d.handles.histAxis.CurrentPoint(1,1);
            tabDat.vatOverlay(d);
            
            d.dat(d.tableRow) = tabDat;
            tabDat.updateHistLine(d);
        end
        
        function histAxisButtonUp(tabDat, a, b, d)
            d.handles.figure.WindowButtonMotionFcn = '';
            d.handles.figure.WindowButtonUpFcn = '';
            d.handles.imgDisplay.AlphaData = 1;
            d.tableCellSelect;
        end
        
        % % % Experimental % % %
        % % Mirror Axis % %
        function tabDat = showMirrorAxis(tabDat, d)
            d.cfgDM.contour.showMirrorAxis = ~d.cfgDM.contour.showMirrorAxis;
            if d.cfgDM.contour.showMirrorAxis == 0
                uiwait(msgbox('Mirror axis not visible'));
            elseif d.cfgDM.contour.showMirrorAxis == 1
                uiwait(msgbox('Mirror axis now visible'));
            end
        end
        
        function tabDat = setMirrorAxis(tabDat, d)
            tabDat = setStructArrayField(tabDat, 'Various.mirrorAxisX', {});
            tabDat = setStructArrayField(tabDat, 'Various.mirrorAxisY', {});
            
            datInd = d.tableRow;
            ctabDat = d.dat(datInd);
            [x y] = getline(d.handles.imgAxis); % replace by "imline" if to be improved
            ctabDat.Various.mirrorAxisX = {x};
            ctabDat.Various.mirrorAxisY = {y};
            tabDat(datInd) = ctabDat;
            d.tableCellSelect;
        end
                
        function tabDat = delMirrorAxis(tabDat, d)
            tabDat = setStructArrayField(tabDat, 'Various', {});
            
            datInd = d.tableRow;
            ctabDat = d.dat(datInd);
            [x y] = getline(d.handles.imgAxis); % replace by "imline" if to be improved
            ctabDat.Various.mirrorAxisX = {x};
            ctabDat.Various.mirrorAxisY = {y};
            tabDat(datInd) = ctabDat;
            d.tableCellSelect;
        end
        
        function d = saveMirroredXls(tabDat, d)
            wb = waitbar(0, 'saving XLS Hemi results');
            wb.Name = 'saving....';
            % find mirror axis
            coord = [tabDat.Various];
            if numel(coord)>1
                msgbox('to many axes found in all data! check at saveMirroredXls.');
            elseif numel(coord)==1
                x1 = coord{1}.mirrorAxisX{1}(1);
                x2 = coord{1}.mirrorAxisX{1}(2);
                y1 = coord{1}.mirrorAxisY{1}(1);
                y2 = coord{1}.mirrorAxisY{1}(2);
                
                %% start saving xls
                
                %% collect infos
                dicomInfo = tabDat(1).getStandardImg.dicomInfo;
                try info.comment = dicomInfo.StudyComments; end
                try info.description = dicomInfo.RequestedProcedureDescription; end
                try info.physicianName = dicomInfo.ReferringPhysicianName.FamilyName; end
                try info.institution = dicomInfo.InstitutionName; end
                try info.stationName = dicomInfo.StationName; end
                try info.manufacturer = dicomInfo.Manufacturer; end
                try info.manufacturerModelName = dicomInfo.ManufacturerModelName; end
                
                try info.patientName = [dicomInfo.PatientName.FamilyName '_' dicomInfo.PatientName.GivenName];
                catch
                    try info.patientName = dicomInfo.PatientName.FamilyName;
                    catch
                        info.patientName = 'NoName';
                    end
                end
                try info.patientWeight = num2str(dicomInfo.PatientWeight); end
                try info.patientAge = dicomInfo.PatientAge; end
                try info.patientSex = dicomInfo.PatientSex; end
                try info.patientBirthDat = dicomInfo.PatientBirthDate; end
                try info.patientID = dicomInfo.PatientID; end
                
                try info.creationDate = datestr(datenum(dicomInfo.InstanceCreationDate, 'yyyymmdd'), 'dd.mm.yyyy'); end
                
                % remove empty entries
                emptyInd = structfun(@isempty, info);
                infoFields = fieldnames(info);
                for i = 1:numel(emptyInd)
                    if emptyInd(i)
                        info = rmfield(info, infoFields(i));
                    end
                end
                
                waitbar(0.3, wb);
%% create struct with tabDat Rechts°!
                img = tabDat(1).getStandardImg;
                imgSize = size(img.data);
                    %% preparation
                xlsPath = fullfile(d.cfgDM.lastLoadPath, [d.getSaveFilePrefix 'mirroredRECHTS_data.xlsx']);
                
                    %% get line masks
                % get points at upper and lower edge of image according to y=mx+t
                m = (y2-y1)/(x2-x1);
                t = y1-m*x1;
                y11 = 1;
                x11 = (y11-t)/m;
                y22 = imgSize(2);
                x22 = (y22-t)/m;
                
                [x y] = makeLinePoints(x11, y11, x22, y22);
                lineMask = zeros(imgSize);
                lineMask = tabDat.getBoundMask(lineMask, [y' x']);
                
                rightMask = lineMask;
                rightMask(1, x11:end) = 1;
                rightMask(end, x22:end) = 1;
                rightMask(:, end) = 1;
                rightMask = imfill(rightMask,'holes');
                
                leftMask = lineMask;
                leftMask(1, 1:x11) = 1;
                leftMask(end, 1:x22) = 1;
                leftMask(:, 1) = 1;
                leftMask = imfill(leftMask,'holes');
                
                    %% read values from tabDat to s struct left side
                for i = 1:numel(tabDat)
                    ctabDat = tabDat(i);
                    %% modify Boundaries for left side only
                    if ctabDat.segmentDone
                    mask = leftMask;
                    try
                        oBoundInd = ctabDat.Boundaries.getBoundInd('outerBound');
                        oBound = ctabDat.Boundaries(oBoundInd);
                        oBoundMask = ctabDat.getBoundMask(img.data, oBound.coord);
                        oBoundMask = oBoundMask&mask;
                        tmp = bwboundaries(oBoundMask);
                        oBound.coord = tmp{1};
                    catch
                        oBound = [];
                    end
                    
                    try
                        iBoundInd = ctabDat.Boundaries.getBoundInd('innerBound');
                        iBound = ctabDat.Boundaries(iBoundInd);
                        iBoundMask = ctabDat.getBoundMask(img.data, iBound.coord);
                        iBoundMask = iBoundMask&mask;
                        tmp = bwboundaries(iBoundMask);
                        iBound.coord = tmp{1};
                    catch
                        iBound = [];
                    end
                    
                    try
                        vBoundInd = ctabDat.Boundaries.getBoundInd('visceralBound');
                        vBound = ctabDat.Boundaries(vBoundInd);
                        vBoundMask = ctabDat.getBoundMask(img.data, vBound.coord);
                        vBoundMask = vBoundMask&mask;
                        tmp = bwboundaries(vBoundMask);
                        vBound.coord = tmp{1};
                    catch
                        vBound = [];
                    end
                    
                    
                    
                    ctabDat.Boundaries = [oBound iBound vBound];
                    
                    end
                    
                    s.voxVol(i) = ctabDat.imgs(1).getVoxelVolume;
                    s.fatThresh(i) = ctabDat.fatThresh;
                    try 
                        oBoundCoord = ctabDat.Boundaries(ctabDat.Boundaries.getBoundInd('outerBound')); 
                    catch
                        oBoundCoord = []; 
                    end
                    try 
                        oBoundMask = ctabDat.getBoundMask(ctabDat.waterImg.data, oBoundCoord.coord); 
                    catch
                        oBoundMask = [];
                    end
                    tmp = regionprops(oBoundMask , 'Area', 'Perimeter');
                    if isempty(tmp)
                        tmp(1).Area = 0;
                        tmp(1).Perimeter = 0;
                    end
                    s.bodyArea(i) = tmp.Area;
                    s.bodyPerimeter(i) = tmp.Perimeter;
                    
                    s.SatArea(i) = ctabDat.volumeSAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.VatArea(i) = ctabDat.volumeVAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.SatVol(i) = ctabDat.volumeSAT;
                    s.VatVol(i) = ctabDat.volumeVAT;
                    s.Loc1(i) = {ctabDat.Loc1};
                    s.Loc2(i) = {ctabDat.Loc2};
                    s.sliceLoc(i) = str2num(ctabDat.sliceLocation);
                    s.sliceNr(i) = i;
                end
                % postprocessing
                s.Loc1(ismember(s.Loc1, 'none')) = {''};
                s.Loc2(ismember(s.Loc2, 'none')) = {''};
                
                sFlip = structfun(@(x) x', s, 'Uniformoutput', 0);
                
                    %% write to xls sheet (use all available data)
                writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
                writetable(struct2table(sFlip), xlsPath, 'Sheet', 'allFatData');
                
                    %% write to xls sheet (xls file like <nikita 2016)
                if ~isnan(d.cfgDM.sliceSpacingInterpolationDistance) && any(abs(diff(s.sliceLoc) - d.cfgDM.sliceSpacingInterpolationDistance) > 0.5)
                    % prepare data: interpolate to equidistant slice loc
                    x = s.sliceLoc;
                    sliceLocOld = x;
                    window = d.cfgDM.sliceSpacingInterpolationDistance;
                    xn = [x(1):window:x(end)];
                    sliceLocNew = xn;
                    % find correct slice width (description available (drawIO)) for volume calculation
                    sliceWidth = diff(sliceLocNew);
                    sW1 = sliceWidth./2; sW1(end+1) = 0;
                    sW2 = sliceWidth./2; sW2 = [0 sW2];
                    sliceWidth = sW1+sW2;
                    % now special treatment for boundary images (1 and end)
                    sliceWidth(1) = sliceWidth(1)+str2num(d.dat(1).imgs(1).sliceThickness)/2;
                    sliceWidth(end) = sliceWidth(end)+str2num(d.dat(end).imgs(end).sliceThickness)/2;
                    % slice Width done!
                    
                    %_Calc VatVol
                    y = s.VatArea;  % mm^2
                    [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                    ynVatArea = interp1(x2, y2, sliceLocNew);
                    VatVol = ynVatArea.*sliceWidth*0.001;
                    
                    %_Calc SatVol
                    y = s.SatArea;  % mm^2
                    [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                    ynSatArea = interp1(x2, y2, sliceLocNew);
                    SatVol = ynSatArea.*sliceWidth*0.001;
                    
                    %_Set WKs
                    LocsInd = find(~ismember(s.Loc1,''));
                    LocsVal = s.Loc1(LocsInd);
                    LocsPosOrig = s.sliceLoc(LocsInd);
                    Loc1 = cell(1, numel(sliceLocNew)); Loc1(:) = {''};
                    for i = 1:numel(LocsPosOrig)
                        [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                        Loc1(ind) = LocsVal(i);
                    end
                    
                    %_Set Landmarks
                    LocsInd = find(~ismember(s.Loc2,''));
                    LocsVal = s.Loc2(LocsInd);
                    LocsPosOrig = s.sliceLoc(LocsInd);
                    Loc2 = cell(1, numel(sliceLocNew)); Loc2(:) = {''};
                    for i = 1:numel(LocsPosOrig)
                        [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                        Loc2(ind) = LocsVal(i);
                    end
                    
                    %_Set sliceNr
                    sliceNr = 1:numel(sliceLocNew);
                    
                    %_Plot Interpolation Reults
                    figure();
                    plot(diff(x),'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                    hold on
                    plot(diff(x2),'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                    plot(diff(xn),'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                    drawnow;
                    a = gca;
                    a.XLabel.String = 'sliceLocation';
                    a.YLabel.String = 'VatArea';
                    legend('show');
                    
                    figure();
                    plot(x, y, 'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                    hold on
                    plot(x2,y2,'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                    plot(xn,ynSatArea,'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                    drawnow;
                    a = gca;
                    a.XLabel.String = 'sliceLocation';
                    a.YLabel.String = 'VatArea';
                    legend('show');
                    
                    
                    
                    
                    waitfor(msgbox('Slice locations are not equally distributed -> interpolation was done as shown in figure!'));
                    
                    
                else
                    sliceLocNew = s.sliceLoc;
                    SatVol = s.SatVol;
                    VatVol = s.VatVol;
                    sliceNr = s.sliceNr;
                    Loc1 = s.Loc1;
                    Loc2 = s.Loc2;
                end
                
                
                Pos = 1;
                xlswrite(xlsPath, {info.patientName} , 'FAT', 'A1');
                xlswrite(xlsPath, {info.creationDate} , 'FAT', 'A2');
                xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', 'A3');
                xlswrite(xlsPath, sliceNr', 'FAT', 'A4');
                xlswrite(xlsPath, sliceLocNew', 'FAT', 'B4');
                xlswrite(xlsPath, [0 diff(sliceLocNew)]', 'FAT', 'C4');
                xlswrite(xlsPath, round(SatVol)', 'FAT', 'D4');
                xlswrite(xlsPath, round(VatVol)', 'FAT', 'E4');
                xlswrite(xlsPath, Loc1', 'FAT', 'F4');
                xlswrite(xlsPath, Loc2', 'FAT', 'G4');
                Pos = 3+numel(VatVol)+1;
                xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', ['A' num2str(Pos)]);
                Pos = Pos+2;
                xlswrite(xlsPath, {'Summe'}, 'FAT', ['A' num2str(Pos)]);
                xlswrite(xlsPath, round(sum(SatVol)), 'FAT', ['D' num2str(Pos)]);
                xlswrite(xlsPath, round(sum(VatVol)), 'FAT', ['E' num2str(Pos)]);
                
                waitbar(0.6, wb);
%% create struct with tabDat Links°!
                img = tabDat(1).getStandardImg;
                imgSize = size(img.data);
                    %% preparation
                xlsPath = fullfile(d.cfgDM.lastLoadPath, [d.getSaveFilePrefix 'mirroredLINKS_data.xlsx']);
%                 %[file, path] = uiputfile(xlsPath);
%                 if path==0
%                     return
%                 end
%                 xlsPath = fullfile(path,file);
                
                    %% get line masks
                % get points at upper and lower edge of image according to y=mx+t
                m = (y2-y1)/(x2-x1);
                t = y1-m*x1;
                y11 = 1;
                x11 = (y11-t)/m;
                y22 = imgSize(2);
                x22 = (y22-t)/m;
                
                [x y] = makeLinePoints(x11, y11, x22, y22);
                lineMask = zeros(imgSize);
                lineMask = tabDat.getBoundMask(lineMask, [y' x']);
                
                rightMask = lineMask;
                rightMask(1, x11:end) = 1;
                rightMask(end, x22:end) = 1;
                rightMask(:, end) = 1;
                rightMask = imfill(rightMask,'holes');
                
                leftMask = lineMask;
                leftMask(1, 1:x11) = 1;
                leftMask(end, 1:x22) = 1;
                leftMask(:, 1) = 1;
                leftMask = imfill(leftMask,'holes');
                
                    %% read values from tabDat to s struct right side
                for i = 1:numel(tabDat)
                    ctabDat = tabDat(i);
                    %% modify Boundaries for left side only
                    if ctabDat.segmentDone
                    mask = rightMask;
                    try
                        oBoundInd = ctabDat.Boundaries.getBoundInd('outerBound');
                        oBound = ctabDat.Boundaries(oBoundInd);
                        oBoundMask = ctabDat.getBoundMask(img.data, oBound.coord);
                        oBoundMask = oBoundMask&mask;
                        tmp = bwboundaries(oBoundMask);
                        oBound.coord = tmp{1};
                    catch
                        oBound = [];
                    end
                    
                    try
                        iBoundInd = ctabDat.Boundaries.getBoundInd('innerBound');
                        iBound = ctabDat.Boundaries(iBoundInd);
                        iBoundMask = ctabDat.getBoundMask(img.data, iBound.coord);
                        iBoundMask = iBoundMask&mask;
                        tmp = bwboundaries(iBoundMask);
                        iBound.coord = tmp{1};
                    catch
                        iBound = [];
                    end
                    
                    try
                        vBoundInd = ctabDat.Boundaries.getBoundInd('visceralBound');
                        vBound = ctabDat.Boundaries(vBoundInd);
                        vBoundMask = ctabDat.getBoundMask(img.data, vBound.coord);
                        vBoundMask = vBoundMask&mask;
                        tmp = bwboundaries(vBoundMask);
                        vBound.coord = tmp{1};
                    catch
                        vBound = [];
                    end
                        
                    
                    
                    ctabDat.Boundaries = [oBound iBound vBound];
                    %ctabDat.volumeVAT
% %                     
%                     figure();
%                     imshow(oBoundMask);
                    
                    
                    
                    end
                    
                    s.voxVol(i) = ctabDat.imgs(1).getVoxelVolume;
                    s.fatThresh(i) = ctabDat.fatThresh;
                    try 
                        oBoundCoord = ctabDat.Boundaries(ctabDat.Boundaries.getBoundInd('outerBound')); 
                    catch
                        oBoundCoord = []; 
                    end
                    try 
                        oBoundMask = ctabDat.getBoundMask(ctabDat.waterImg.data, oBoundCoord.coord); 
                    catch
                        oBoundMask = [];
                    end
                    tmp = regionprops(oBoundMask , 'Area', 'Perimeter');
                    if isempty(tmp)
                        tmp(1).Area = 0;
                        tmp(1).Perimeter = 0;
                    end
                    s.bodyArea(i) = tmp.Area;
                    s.bodyPerimeter(i) = tmp.Perimeter;
                    
                    s.SatArea(i) = ctabDat.volumeSAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.VatArea(i) = ctabDat.volumeVAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.SatVol(i) = ctabDat.volumeSAT;
                    s.VatVol(i) = ctabDat.volumeVAT;
                    s.Loc1(i) = {ctabDat.Loc1};
                    s.Loc2(i) = {ctabDat.Loc2};
                    s.sliceLoc(i) = str2num(ctabDat.sliceLocation);
                    s.sliceNr(i) = i;
                end
                % postprocessing
                s.Loc1(ismember(s.Loc1, 'none')) = {''};
                s.Loc2(ismember(s.Loc2, 'none')) = {''};
                
                sFlip = structfun(@(x) x', s, 'Uniformoutput', 0);
                
                    %% write to xls sheet (use all available data)
                writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
                writetable(struct2table(sFlip), xlsPath, 'Sheet', 'allFatData');
                
                    %% write to xls sheet (xls file like <nikita 2016)
                if ~isnan(d.cfgDM.sliceSpacingInterpolationDistance) && any(abs(diff(s.sliceLoc) - d.cfgDM.sliceSpacingInterpolationDistance) > 0.5)
                    % prepare data: interpolate to equidistant slice loc
                    x = s.sliceLoc;
                    sliceLocOld = x;
                    window = d.cfgDM.sliceSpacingInterpolationDistance;
                    xn = [x(1):window:x(end)];
                    sliceLocNew = xn;
                    % find correct slice width (description available (drawIO)) for volume calculation
                    sliceWidth = diff(sliceLocNew);
                    sW1 = sliceWidth./2; sW1(end+1) = 0;
                    sW2 = sliceWidth./2; sW2 = [0 sW2];
                    sliceWidth = sW1+sW2;
                    % now special treatment for boundary images (1 and end)
                    sliceWidth(1) = sliceWidth(1)+str2num(d.dat(1).imgs(1).sliceThickness)/2;
                    sliceWidth(end) = sliceWidth(end)+str2num(d.dat(end).imgs(end).sliceThickness)/2;
                    % slice Width done!
                    
                    %_Calc VatVol
                    y = s.VatArea;  % mm^2
                    [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                    ynVatArea = interp1(x2, y2, sliceLocNew);
                    VatVol = ynVatArea.*sliceWidth*0.001;
                    
                    %_Calc SatVol
                    y = s.SatArea;  % mm^2
                    [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                    ynSatArea = interp1(x2, y2, sliceLocNew);
                    SatVol = ynSatArea.*sliceWidth*0.001;
                    
                    %_Set WKs
                    LocsInd = find(~ismember(s.Loc1,''));
                    LocsVal = s.Loc1(LocsInd);
                    LocsPosOrig = s.sliceLoc(LocsInd);
                    Loc1 = cell(1, numel(sliceLocNew)); Loc1(:) = {''};
                    for i = 1:numel(LocsPosOrig)
                        [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                        Loc1(ind) = LocsVal(i);
                    end
                    
                    %_Set Landmarks
                    LocsInd = find(~ismember(s.Loc2,''));
                    LocsVal = s.Loc2(LocsInd);
                    LocsPosOrig = s.sliceLoc(LocsInd);
                    Loc2 = cell(1, numel(sliceLocNew)); Loc2(:) = {''};
                    for i = 1:numel(LocsPosOrig)
                        [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                        Loc2(ind) = LocsVal(i);
                    end
                    
                    %_Set sliceNr
                    sliceNr = 1:numel(sliceLocNew);
                    
                    %_Plot Interpolation Reults
                    figure();
                    plot(diff(x),'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                    hold on
                    plot(diff(x2),'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                    plot(diff(xn),'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                    drawnow;
                    a = gca;
                    a.XLabel.String = 'sliceLocation';
                    a.YLabel.String = 'VatArea';
                    legend('show');
                    
                    figure();
                    plot(x, y, 'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                    hold on
                    plot(x2,y2,'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                    plot(xn,ynSatArea,'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                    drawnow;
                    a = gca;
                    a.XLabel.String = 'sliceLocation';
                    a.YLabel.String = 'VatArea';
                    legend('show');
                    
                    
                    
                    
                    waitfor(msgbox('Slice locations are not equally distributed -> interpolation was done as shown in figure!'));
                    
                    
                else
                    sliceLocNew = s.sliceLoc;
                    SatVol = s.SatVol;
                    VatVol = s.VatVol;
                    sliceNr = s.sliceNr;
                    Loc1 = s.Loc1;
                    Loc2 = s.Loc2;
                end
                
                
                Pos = 1;
                xlswrite(xlsPath, {info.patientName} , 'FAT', 'A1');
                xlswrite(xlsPath, {info.creationDate} , 'FAT', 'A2');
                xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', 'A3');
                xlswrite(xlsPath, sliceNr', 'FAT', 'A4');
                xlswrite(xlsPath, sliceLocNew', 'FAT', 'B4');
                xlswrite(xlsPath, [0 diff(sliceLocNew)]', 'FAT', 'C4');
                xlswrite(xlsPath, round(SatVol)', 'FAT', 'D4');
                xlswrite(xlsPath, round(VatVol)', 'FAT', 'E4');
                xlswrite(xlsPath, Loc1', 'FAT', 'F4');
                xlswrite(xlsPath, Loc2', 'FAT', 'G4');
                Pos = 3+numel(VatVol)+1;
                xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', ['A' num2str(Pos)]);
                Pos = Pos+2;
                xlswrite(xlsPath, {'Summe'}, 'FAT', ['A' num2str(Pos)]);
                xlswrite(xlsPath, round(sum(SatVol)), 'FAT', ['D' num2str(Pos)]);
                xlswrite(xlsPath, round(sum(VatVol)), 'FAT', ['E' num2str(Pos)]);
                
                waitbar(0.9, wb);
                pause(0.3);
                close(wb);
            end
            
            uiwait(msgbox('mirror save xls Done!!'));
            
        end
        
        % % Femur Box % %
        function tabDat = showFemurBox(tabDat, d)
            d.cfgDM.contour.showFemurBox = ~d.cfgDM.contour.showFemurBox;
            if d.cfgDM.contour.showFemurBox == 0
                uiwait(msgbox('Femur Box not visible'));
            elseif d.cfgDM.contour.showFemurBox == 1
                uiwait(msgbox('Femur Box now visible'));
            end
        end
       
        function showFemurBoxSize(tabDat, hBox, T1, T2)
            pos = hBox.getPosition;
            T1.String = num2str(round(pos(3)));
            T1.Position = [pos(1)+pos(3)/2-5, pos(2)-6];
            T2.String = num2str(round(pos(4)));
            T2.Position = [pos(1)+pos(3)+2, pos(2)+pos(4)/2];
        end
        
        function tabDat = setFemurBox(tabDat, d)
            hBox = imrect(d.handles.imgAxis);
            pos = hBox.getPosition;
            Message = text(0, 0, '', 'Parent', d.handles.imgAxis, 'Color', 'green');
            Message.String = 'Double click on box to confirm!';
            Message.Position = [pos(1)+pos(3)/2-40, pos(2)+pos(4)/2-3];
            Message.FontSize = 14;
            T1 = text(0, 0, '', 'Parent', d.handles.imgAxis, 'Color', 'green');
            T1.FontSize = 14;
            T2 = text(0, 0, '', 'Parent', d.handles.imgAxis, 'Color', 'green');
            T2.FontSize = 14;
            addNewPositionCallback(hBox, @(varargout)tabDat.showFemurBoxSize(hBox, T1, T2));
            
            wait(hBox);
            pos = hBox.getPosition;
            datInd = d.tableRow;
            ctabDat = d.dat(datInd);
            ctabDat.Various.femurBox = createMask(hBox);
            tabDat(datInd) = ctabDat;
            
            d.Various.femurBoxInd = datInd;
            d.Various.femurBoxSize = pos;
            d.cfgDM.contour.showFemurBox = 1;
            %d.tableCellSelect;
        end
        
        function tabDat = delFemurBox(tabDat, d)
            d.dat(d.Various.femurBoxInd).Various = rmfield(d.dat(d.Various.femurBoxInd).Various, 'femurBox');
            d.Various.femurBoxInd = 0;
            d.cfgDM.contour.showFemurBox = 0;
        end
        
        function tabDat = saveBoxResults(tabDat, d)
            wb = waitbar(0, 'saving XLS box results');
            wb.Name = 'saving....';
            %% collect infos
                dicomInfo = tabDat(1).getStandardImg.dicomInfo;
                try info.comment = dicomInfo.StudyComments; end
                try info.description = dicomInfo.RequestedProcedureDescription; end
                try info.physicianName = dicomInfo.ReferringPhysicianName.FamilyName; end
                try info.institution = dicomInfo.InstitutionName; end
                try info.stationName = dicomInfo.StationName; end
                try info.manufacturer = dicomInfo.Manufacturer; end
                try info.manufacturerModelName = dicomInfo.ManufacturerModelName; end
                
                try info.patientName = [dicomInfo.PatientName.FamilyName '_' dicomInfo.PatientName.GivenName];
                catch
                    try info.patientName = dicomInfo.PatientName.FamilyName;
                    catch
                        info.patientName = 'NoName';
                    end
                end
                try info.patientWeight = num2str(dicomInfo.PatientWeight); end
                try info.patientAge = dicomInfo.PatientAge; end
                try info.patientSex = dicomInfo.PatientSex; end
                try info.patientBirthDat = dicomInfo.PatientBirthDate; end
                try info.patientID = dicomInfo.PatientID; end
                
                try info.creationDate = datestr(datenum(dicomInfo.InstanceCreationDate, 'yyyymmdd'), 'dd.mm.yyyy'); end
                
                % remove empty entries
                emptyInd = structfun(@isempty, info);
                infoFields = fieldnames(info);
                for i = 1:numel(emptyInd)
                    if emptyInd(i)
                        info = rmfield(info, infoFields(i));
                    end
                end
                
                waitbar(0.3, wb);
            %% create struct with tabDat!
                img = tabDat(1).getStandardImg;
                imgSize = size(img.data);
                    %% preparation
                xlsPath = fullfile(d.cfgDM.lastLoadPath, [d.getSaveFilePrefix 'FemurBox_data.xlsx']);
                
                    %% get masks
                mask = d.dat(d.Various.femurBoxInd).Various.femurBox;
                
                    %% read values from tabDat to s struct
                for i = 1:numel(tabDat)
                    ctabDat = tabDat(i);
                    %% modify Boundaries for left side only
                    if ctabDat.segmentDone
                    try
                        oBoundInd = ctabDat.Boundaries.getBoundInd('outerBound');
                        oBound = ctabDat.Boundaries(oBoundInd);
                        oBoundMask = ctabDat.getBoundMask(img.data, oBound.coord);
                        oBoundMask = oBoundMask&mask;
                        tmp = bwboundaries(oBoundMask);
                        oBound.coord = tmp{1};
                    catch
                        oBound = [];
                    end
                    
                    try
                        iBoundInd = ctabDat.Boundaries.getBoundInd('innerBound');
                        iBound = ctabDat.Boundaries(iBoundInd);
                        iBoundMask = ctabDat.getBoundMask(img.data, iBound.coord);
                        iBoundMask = iBoundMask&mask;
                        tmp = bwboundaries(iBoundMask);
                        iBound.coord = tmp{1};
                    catch
                        iBound = [];
                    end
                    
                    try
                        vBoundInd = ctabDat.Boundaries.getBoundInd('visceralBound');
                        vBound = ctabDat.Boundaries(vBoundInd);
                        vBoundMask = ctabDat.getBoundMask(img.data, vBound.coord);
                        vBoundMask = vBoundMask&mask;
                        tmp = bwboundaries(vBoundMask);
                        vBound.coord = tmp{1};
                    catch
                        vBound = [];
                    end
                    
                    
                    
                    ctabDat.Boundaries = [oBound iBound vBound];
                    
                    end
                    
                    s.voxVol(i) = ctabDat.imgs(1).getVoxelVolume;
                    s.fatThresh(i) = ctabDat.fatThresh;
                    try 
                        oBoundCoord = ctabDat.Boundaries(ctabDat.Boundaries.getBoundInd('outerBound')); 
                    catch
                        oBoundCoord = []; 
                    end
                    try 
                        oBoundMask = ctabDat.getBoundMask(ctabDat.waterImg.data, oBoundCoord.coord); 
                    catch
                        oBoundMask = [];
                    end
                    tmp = regionprops(oBoundMask , 'Area', 'Perimeter');
                    if isempty(tmp)
                        tmp(1).Area = 0;
                        tmp(1).Perimeter = 0;
                    end
                    s.bodyArea(i) = tmp.Area;
                    s.bodyPerimeter(i) = tmp.Perimeter;
                    
                    s.SatArea(i) = ctabDat.volumeSAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.VatArea(i) = ctabDat.volumeVAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.SatVol(i) = ctabDat.volumeSAT;
                    s.VatVol(i) = ctabDat.volumeVAT;
                    s.Loc1(i) = {ctabDat.Loc1};
                    s.Loc2(i) = {ctabDat.Loc2};
                    s.sliceLoc(i) = str2num(ctabDat.sliceLocation);
                    s.sliceNr(i) = i;
                end
                % postprocessing
                s.Loc1(ismember(s.Loc1, 'none')) = {''};
                s.Loc2(ismember(s.Loc2, 'none')) = {''};
                
                sFlip = structfun(@(x) x', s, 'Uniformoutput', 0);
                
                    %% write to xls sheet (use all available data)
                writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
                writetable(struct2table(sFlip), xlsPath, 'Sheet', 'allFatData');
                waitbar(0.6, wb);
                    %% write to xls sheet (xls file like <nikita 2016)
                if ~isnan(d.cfgDM.sliceSpacingInterpolationDistance) && any(abs(diff(s.sliceLoc) - d.cfgDM.sliceSpacingInterpolationDistance) > 0.5)
                    % prepare data: interpolate to equidistant slice loc
                    x = s.sliceLoc;
                    sliceLocOld = x;
                    window = d.cfgDM.sliceSpacingInterpolationDistance;
                    xn = [x(1):window:x(end)];
                    sliceLocNew = xn;
                    % find correct slice width (description available (drawIO)) for volume calculation
                    sliceWidth = diff(sliceLocNew);
                    sW1 = sliceWidth./2; sW1(end+1) = 0;
                    sW2 = sliceWidth./2; sW2 = [0 sW2];
                    sliceWidth = sW1+sW2;
                    % now special treatment for boundary images (1 and end)
                    sliceWidth(1) = sliceWidth(1)+str2num(d.dat(1).imgs(1).sliceThickness)/2;
                    sliceWidth(end) = sliceWidth(end)+str2num(d.dat(end).imgs(end).sliceThickness)/2;
                    % slice Width done!
                    
                    %_Calc VatVol
                    y = s.VatArea;  % mm^2
                    [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                    ynVatArea = interp1(x2, y2, sliceLocNew);
                    VatVol = ynVatArea.*sliceWidth*0.001;
                    
                    %_Calc SatVol
                    y = s.SatArea;  % mm^2
                    [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                    ynSatArea = interp1(x2, y2, sliceLocNew);
                    SatVol = ynSatArea.*sliceWidth*0.001;
                    
                    %_Set WKs
                    LocsInd = find(~ismember(s.Loc1,''));
                    LocsVal = s.Loc1(LocsInd);
                    LocsPosOrig = s.sliceLoc(LocsInd);
                    Loc1 = cell(1, numel(sliceLocNew)); Loc1(:) = {''};
                    for i = 1:numel(LocsPosOrig)
                        [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                        Loc1(ind) = LocsVal(i);
                    end
                    
                    %_Set Landmarks
                    LocsInd = find(~ismember(s.Loc2,''));
                    LocsVal = s.Loc2(LocsInd);
                    LocsPosOrig = s.sliceLoc(LocsInd);
                    Loc2 = cell(1, numel(sliceLocNew)); Loc2(:) = {''};
                    for i = 1:numel(LocsPosOrig)
                        [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                        Loc2(ind) = LocsVal(i);
                    end
                    
                    %_Set sliceNr
                    sliceNr = 1:numel(sliceLocNew);
                    
                    %_Plot Interpolation Reults
                    figure();
                    plot(diff(x),'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                    hold on
                    plot(diff(x2),'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                    plot(diff(xn),'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                    drawnow;
                    a = gca;
                    a.XLabel.String = 'sliceLocation';
                    a.YLabel.String = 'VatArea';
                    legend('show');
                    
                    figure();
                    plot(x, y, 'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                    hold on
                    plot(x2,y2,'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                    plot(xn,ynSatArea,'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                    drawnow;
                    a = gca;
                    a.XLabel.String = 'sliceLocation';
                    a.YLabel.String = 'VatArea';
                    legend('show');
                    
                    
                    
                    
                    waitfor(msgbox('Slice locations are not equally distributed -> interpolation was done as shown in figure!'));
                    
                    
                else
                    sliceLocNew = s.sliceLoc;
                    SatVol = s.SatVol;
                    VatVol = s.VatVol;
                    sliceNr = s.sliceNr;
                    Loc1 = s.Loc1;
                    Loc2 = s.Loc2;
                end
                
                
                Pos = 1;
                xlswrite(xlsPath, {info.patientName} , 'FAT', 'A1');
                xlswrite(xlsPath, {info.creationDate} , 'FAT', 'A2');
                xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', 'A3');
                xlswrite(xlsPath, sliceNr', 'FAT', 'A4');
                xlswrite(xlsPath, sliceLocNew', 'FAT', 'B4');
                xlswrite(xlsPath, [0 diff(sliceLocNew)]', 'FAT', 'C4');
                xlswrite(xlsPath, round(SatVol)', 'FAT', 'D4');
                xlswrite(xlsPath, round(VatVol)', 'FAT', 'E4');
                xlswrite(xlsPath, Loc1', 'FAT', 'F4');
                xlswrite(xlsPath, Loc2', 'FAT', 'G4');
                Pos = 3+numel(VatVol)+1;
                xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', ['A' num2str(Pos)]);
                Pos = Pos+2;
                xlswrite(xlsPath, {'Summe'}, 'FAT', ['A' num2str(Pos)]);
                xlswrite(xlsPath, round(sum(SatVol)), 'FAT', ['D' num2str(Pos)]);
                xlswrite(xlsPath, round(sum(VatVol)), 'FAT', ['E' num2str(Pos)]);
                waitbar(0.9, wb);
                pause(0.3);
                close(wb);
        end
        
        % % other % %
        function d = importNikitaBound(tabDat, d)
            % import only roi data from old Nikita tool < 2016
            mb = msgbox('klick OK to load an old Nikita mat file <2016 with Bound data to be imported.');
            waitfor(mb);
            [file folder] = uigetfile(fullfile(d.cfgDM.lastLoadPath, '*.mat'));
            load(fullfile(folder, file), 'threshold');
            load(fullfile(folder, file), 'X_seg');
            names = {'outerBound', 'innerBound', 'visceralBound'};
            for i = 1:numel(names) %run through names
                for j = 1:numel(X_seg(1,1,1,:,i))   %run through slices
                    cBoundCoords = bwboundaries(X_seg(:,:,1,j,i));
                    if isempty(cBoundCoords)
                    else
                        cBoundIn = tabDat(j).Boundaries.empty;
                        cBoundIn(1).name = names{i};
                        cBoundIn.coord = cBoundCoords{1};
                        
                        cBounds = tabDat(j).Boundaries;
                        cBounds = setBound(cBounds, cBoundIn);
                        tabDat(j).Boundaries = cBounds;
                        tabDat(j).fatThresh = threshold(j);
                        
                        %% check if slice is done
                        tabDat(j) = tabDat(j).setSegmentDone;
                    end
                    
                end
                
            end
            
            d.dat = tabDat;
            d.tableCellSelect;
        end
        
        % % % Image Organisation % % %
        function img = fatImg(tabDat)
            img = imgFat;
            inPhaseImg = tabDat.getImgOfType('InPhase');
            outPhaseImg = tabDat.getImgOfType('OutPhase');
            
            img.data = inPhaseImg.data-outPhaseImg.data;
            img.imgType = 'Fat';
        end
        
        function img = waterImg(tabDat)
            img = imgFat;
            inPhaseImg = tabDat.getImgOfType('InPhase');
            outPhaseImg = tabDat.getImgOfType('OutPhase');
            
            img.data = (inPhaseImg.data+outPhaseImg.data)./2;
            img.imgType = 'Water';
        end
        
        function vatOverlay(tabDat, d)
            vbInd = tabDat.Boundaries.getBoundInd('visceralBound');
            VatImg = tabDat.waterImg;
            VatMask = ~logical(tabDat.getBoundMask(VatImg.data, tabDat.Boundaries(vbInd).coord));
            VatImg.data(VatMask) = 0;   % only Vat pxls are not 0
            VatFatPxl = VatImg.data>tabDat.fatThresh;  % Vat is only pxlValues bigger than hist cursor
            % indicate the VatFat pixels with overlay
            maskInd = find(VatFatPxl);
            color = 1-d.cfgDM.color3;
            tabDat.history.plotImgRGB = tabDat.history.plotImg.conv2RGB;
            img = tabDat.history.plotImg.data;
%             if isfield(tabDat.history, 'vatOverlay') && ~isempty(tabDat.history.vatOverlay)
%                 img = d.handles.imgDisplay.CData;
%                 % remove overlay
%                 oldInd = tabDat.history.vatOverlay;
%                 Rimg = img(:,:,1);
%                 Rimg(oldInd) = Rimg(oldInd)./(1-color(1));
%                 Gimg = img(:,:,2);
%                 Gimg(oldInd) = Gimg(oldInd)./(1-color(1));
%                 Bimg = img(:,:,3);
%                 Bimg(oldInd) = Bimg(oldInd)./(1-color(1));
%             else
%                 img = d.handles.imgDisplay.CData;
%             end
            
            Rimg = img(:,:,1);
            Rimg(maskInd) = Rimg(maskInd) - Rimg(maskInd).*color(1);
            Gimg = img(:,:,1);
            Gimg(maskInd) = Gimg(maskInd) - Gimg(maskInd).*color(2);
            Bimg = img(:,:,1);
            Bimg(maskInd) = Bimg(maskInd) - Bimg(maskInd).*color(3);
            
            RGBimg = [Rimg Gimg Bimg];
            RGBimg = reshape(RGBimg, size(Rimg,1), size(Rimg,2), 3);
            
            d.handles.imgDisplay.CData = uint8(RGBimg);
        end
        
        % % % Segmentaion Organisation % % %
        function tabDat = segment(tabDat, segProps)
            iBound = tabDat.Boundaries.getBoundOfType('innerBound');
            oBound = tabDat.Boundaries.getBoundOfType('outerBound');
            vBound = tabDat.Boundaries.getBoundOfType('visceralBound');
            
            
            switch segProps.name
                case 'NikitaFat160322Segmenting.m'
                    imgBase = tabDat.getImgOfType('OutPhase');
                    imgInfo = imgBase.dicomInfo;
                    imgData = imgBase.data;
                    
                    [outerBound innerBound visceralBound] = NikitaFat160322Segmenting(imgData, imgInfo);
                    outerBound = logical(outerBound);
                    innerBound = logical(innerBound);
                    visceralBound = logical(visceralBound);
                    
                    oBound.coord = bwboundaries(outerBound);
                    iBound.coord = bwboundaries(innerBound);
                    vBound.coord = bwboundaries(visceralBound);
                case 'OuterBound_RS'
                    imgIn = tabDat.getImgOfType('InPhase');
                    imgOut = tabDat.getImgOfType('OutPhase');
                    oBound.coord = {RSouterBound(imgIn, 'MRT_OutPhase', segProps.magThreshold)};
                case 'OuterBound_RS+NikitaFat'
                    imgIn = tabDat.getImgOfType('InPhase');
                    imgOut = tabDat.getImgOfType('OutPhase');
                    outerBoundCoord = {RSouterBound(imgIn, 'MRT_OutPhase', segProps.magThreshold)};
                    
                    imgBody = imgOut.data;
                    indBody = find(~tabDat.getBoundMask(imgOut.data, outerBoundCoord));
                    imgBody(indBody) = 0;
                    
                    
                    [outerBound innerBound visceralBound] = NikitaFat161213Segmenting(imgBody, imgOut.dicomInfo);
                    %visceralBound = imerode(innerBound, strel('diamond', 1));
                    
                    outerBound = logical(outerBound);
                    innerBound = logical(innerBound);
                    visceralBound = logical(visceralBound);
                    
                    oBound.coord = outerBoundCoord;
                    iBound.coord = bwboundaries(innerBound);
                    vBound.coord = bwboundaries(visceralBound);
                case 'NikitaFat161213Segmenting.m'
                    imgBase = tabDat.getImgOfType('OutPhase');
                    imgInfo = imgBase.dicomInfo;
                    imgData = imgBase.data;
                    
                    [outerBound innerBound visceralBound] = NikitaFat161213Segmenting(imgData, imgInfo);
                    outerBound = logical(outerBound);
                    innerBound = logical(innerBound);
                    visceralBound = logical(visceralBound);
                    
                    oBound.coord = bwboundaries(outerBound);
                    iBound.coord = bwboundaries(innerBound);
                    vBound.coord = bwboundaries(visceralBound);
            end
            try
                oBound.coord = oBound.coord{1};
                tabDat.Boundaries = tabDat.Boundaries.setBound(oBound);
            end
            try
                iBound.coord = iBound.coord{1};
                tabDat.Boundaries = tabDat.Boundaries.setBound(iBound);
            end
            try
                vBound.coord = vBound.coord{1};
                tabDat.Boundaries = tabDat.Boundaries.setBound(vBound);
            end;
            
            tabDat = tabDat.setSegmentDone;
        end
        
        function tabDat = segmentSingle(tabDat,d)
            if numel(tabDat)==1
                ind = 1;
            else
                ind = d.tableRow;
            end
            tabDat(ind) = tabDat(ind).segment(d.cfgDM.segProps);
        end
        
        function tabDat = segmentAll(tabDat,d)
            wb = waitbar(0, ['Image 1 of ' num2str(numel(tabDat)) '. Time left: inf']);
            wb.Name = 'segmenting image data';
            numel(tabDat)
            for i=1:numel(tabDat)
                i
                if ~tabDat(i).segmentDone
                    t1 = tic;
                    tabDat(i) = tabDat(i).segment(d.cfgDM.segProps);
                    
                    t2 = toc(t1);
                    time(i) = t2;
                    timeLeft = mean(time(i))*(numel(tabDat)-i);
                    if ishandle(wb)
                        waitbar(i/numel(tabDat), wb, ['Image ' num2str(i+1) ' of ' num2str(numel(tabDat)) '. Time left: ' num2str(timeLeft, '%.0f') ' sec']);
                    else
                        disp('aha');
                        return % user abord
                    end
                end
            end
            close(wb);
            %d.dat = tabDat;
        end
        
        function tabDat = setSegmentDone(tabDat)
            if ~tabDat.Boundaries.getBoundInd('outerBound')==0 & ~tabDat.Boundaries.getBoundInd('innerBound')==0 & ~tabDat.Boundaries.getBoundInd('visceralBound')==0 & tabDat.fatThresh>1
                tabDat.segmentDone = true;
            else
                tabDat.segmentDone = false;
            end
        end
        
        function tabDat = clearSegment(tabDat)
            % to be done
            
        end
        
        function tabDat = findThreshLvl(tabDat, d)
            ctabDat = tabDat(d.tableRow);
            if ~ctabDat.Boundaries.getBoundInd('outerBound')==0 & ~ctabDat.Boundaries.getBoundInd('innerBound')==0
                %AUTOMATISCH THRESHOLDERMITTLUNG
                outerCoord = ctabDat.Boundaries(ctabDat.Boundaries.getBoundInd('outerBound')).coord;
                innerCoord = ctabDat.Boundaries(ctabDat.Boundaries.getBoundInd('innerBound')).coord;
                visceralCoord = ctabDat.Boundaries(ctabDat.Boundaries.getBoundInd('visceralBound')).coord;
                
                outerMask = ctabDat.getBoundMask(ctabDat.waterImg.data, outerCoord);
                innerMask = ctabDat.getBoundMask(ctabDat.waterImg.data, innerCoord);
                satMask = outerMask&~innerMask;
                
                satMask(:,1:min(visceralCoord(:,2))) = 0;
                satMask(:,max(visceralCoord(:,2)):end) = 0;
                satMask = imerode(satMask, strel('diamond',5));
                
                
                satIntensities = ctabDat.waterImg.data(find(satMask));
                
                %                 figure();
                %                 imshow(satMask);
                %                 imshow(imerode(satMask, strel('diamond',5)));
                %                 histogram(satIntensities, 100);
                
                ctabDat.fatThresh = prctile(satIntensities, 0.5);
            else
                uiwait(msgbox('SAT must be segmented for FatThreshold determination!'));
            end
            
            tabDat(d.tableRow) = ctabDat;
            d.tableCellSelect;
            
            %
            %             d.cfgDM.autoThresh = ~d.cfgDM.autoThresh;
            %             if d.cfgDM.autoThresh == 0
            %                 uiwait(msgbox('AutoThresholding is Off now! Please set threshold level manually.'));
            %             elseif d.cfgDM.autoThresh == 1
            %                 uiwait(msgbox('AutoThresholding is On now!'));
%                 tabDat = tabDat.determineFatThresh(d);
%             end
        end
        
        function volumeSAT = volumeSAT(tabDat) % in cm^3
            obInd = tabDat.Boundaries.getBoundInd('outerBound');
            ibInd = tabDat.Boundaries.getBoundInd('innerBound');
            if obInd==0 | ibInd==0
                volumeSAT = 0;
            else
                pxlcount = (tabDat.Boundaries(obInd).areaBound - tabDat.Boundaries(ibInd).areaBound);
                volumeSAT = pxlcount*tabDat.imgs(1).getVoxelVolume;
            end
        end
        
        function volumeVAT = volumeVAT(tabDat) % in cm^3
            vbInd = tabDat.Boundaries.getBoundInd('visceralBound');
            if vbInd==0
                volumeVAT = 0;
            else
                VatFatPxl = tabDat.getVatFatPxl;  % Vat is only pxlValues bigger than hist cursor
                
                volumeVAT = sum(sum(VatFatPxl))*tabDat.imgs(1).getVoxelVolume;
            end
        end
        
        function VatFatPxl = getVatFatPxl(tabDat)
            vbInd = tabDat.Boundaries.getBoundInd('visceralBound');
            VatImg = tabDat.waterImg;
            VatMask = ~logical(tabDat.getBoundMask(VatImg.data, tabDat.Boundaries(vbInd).coord));
            VatImg.data(VatMask) = 0;   % only Vat pxls are not 0
            VatFatPxl = VatImg.data>tabDat.fatThresh;  % Vat is only pxlValues bigger than hist cursor
        end
                
        % % % Application Management % % %
        function saveXls(tabDat, d)
            %% preparation
            xlsPath = fullfile(d.cfgDM.lastLoadPath, [d.getSaveFilePrefix '_data.xlsx']);
            [file, path] = uiputfile(xlsPath);
            if path==0
                return
            end
            xlsPath = fullfile(path,file);
            %% collect infos and store in variables
            dicomInfo = tabDat(1).getStandardImg.dicomInfo;
            try info.comment = dicomInfo.StudyComments; end
            try info.description = dicomInfo.RequestedProcedureDescription; end
            try info.physicianName = dicomInfo.ReferringPhysicianName.FamilyName; end
            try info.institution = dicomInfo.InstitutionName; end
            try info.stationName = dicomInfo.StationName; end
            try info.manufacturer = dicomInfo.Manufacturer; end
            try info.manufacturerModelName = dicomInfo.ManufacturerModelName; end
            
            try info.patientName = [dicomInfo.PatientName.FamilyName '_' dicomInfo.PatientName.GivenName]; 
            catch
                try info.patientName = dicomInfo.PatientName.FamilyName;
                catch
                    info.patientName = 'NoName';
                end
            end
            try info.patientWeight = num2str(dicomInfo.PatientWeight); end
            try info.patientAge = dicomInfo.PatientAge; end
            try info.patientSex = dicomInfo.PatientSex; end
            try info.patientBirthDat = dicomInfo.PatientBirthDate; end
            try info.patientID = dicomInfo.PatientID; end
            
            try info.creationDate = datestr(datenum(dicomInfo.InstanceCreationDate, 'yyyymmdd'), 'dd.mm.yyyy'); end
            
            % remove empty entries
            emptyInd = structfun(@isempty, info);
            infoFields = fieldnames(info);
            for i = 1:numel(emptyInd)
                if emptyInd(i)
                    info = rmfield(info, infoFields(i));
                end
            end
            
            % create struct with tabDat data
            for i = 1:numel(tabDat)
                ctabDat = tabDat(i);
                s.voxVol(i) = ctabDat.imgs(1).getVoxelVolume;
                s.fatThresh(i) = ctabDat.fatThresh;
                try 
                    oBoundCoord = ctabDat.Boundaries(ctabDat.Boundaries.getBoundInd('outerBound')); 
                catch
                    oBoundCoord = []; 
                end
                try 
                    oBoundMask = ctabDat.getBoundMask(ctabDat.waterImg.data, oBoundCoord.coord); 
                catch
                    oBoundMask = []; 
                end
                tmp = regionprops(oBoundMask , 'Area', 'Perimeter');
                if isempty(tmp)
                    tmp(1).Area = 0;
                    tmp(1).Perimeter = 0;
                end
                s.bodyArea(i) = tmp.Area;
                s.bodyPerimeter(i) = tmp.Perimeter;
                
                s.SatArea(i) = ctabDat.volumeSAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                s.VatArea(i) = ctabDat.volumeVAT/ctabDat.imgs(1).dicomInfo.SpacingBetweenSlices*1000;
                s.SatVol(i) = ctabDat.volumeSAT;
                s.VatVol(i) = ctabDat.volumeVAT;
                s.Loc1(i) = {ctabDat.Loc1};
                s.Loc2(i) = {ctabDat.Loc2};
                s.sliceLoc(i) = str2num(ctabDat.sliceLocation);
                s.sliceNr(i) = i;
            end
            % postprocessing
            s.Loc1(ismember(s.Loc1, 'none')) = {''};
            s.Loc2(ismember(s.Loc2, 'none')) = {''};
            
            sFlip = structfun(@(x) x', s, 'Uniformoutput', 0);
            
            %% write to xls sheet (use all available data)
            writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
            writetable(struct2table(sFlip), xlsPath, 'Sheet', 'allFatData');
            
            %% write to xls sheet (xls file like <nikita 2016)
            inconsistentSliceSpacing = any(abs(diff(s.sliceLoc) - d.cfgDM.sliceSpacingInterpolationDistance) > 0.1);
            if inconsistentSliceSpacing
                if isnan(d.cfgDM.sliceSpacingInterpolationDistance)
                    sliceSpacingInterpolationDistance = str2num(inputdlg('Set a interpolation value for slice spacing in mm:', 'SliceSpacing inconsistent'));
                    d.cfgDM.sliceSpacingInterpolationDistance = sliceSpacingInterpolationDistance
                end
                % prepare data: interpolate to equidistant slice loc
                x = s.sliceLoc;
                sliceLocOld = x;
                window = d.cfgDM.sliceSpacingInterpolationDistance;
                xn = [x(1):window:x(end)];
                sliceLocNew = xn;
                % find correct slice width (description available (drawIO)) for volume calculation
                sliceWidth = diff(sliceLocNew);
                sW1 = sliceWidth./2; sW1(end+1) = 0;
                sW2 = sliceWidth./2; sW2 = [0 sW2];
                sliceWidth = sW1+sW2;
                % now special treatment for boundary images (1 and end)
                sliceWidth(1) = sliceWidth(1)+str2num(d.dat(1).imgs(1).sliceThickness)/2;
                sliceWidth(end) = sliceWidth(end)+str2num(d.dat(end).imgs(end).sliceThickness)/2;
                % slice Width done!
                
                %_Calc VatVol
                y = s.VatArea;  % mm^2
                [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                ynVatArea = interp1(x2, y2, sliceLocNew);
                VatVol = ynVatArea.*sliceWidth*0.001;
                
                %_Calc SatVol
                y = s.SatArea;  % mm^2
                [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
                ynSatArea = interp1(x2, y2, sliceLocNew);
                SatVol = ynSatArea.*sliceWidth*0.001;
                
                %_Set WKs
                LocsInd = find(~ismember(s.Loc1,''));
                LocsVal = s.Loc1(LocsInd);
                LocsPosOrig = s.sliceLoc(LocsInd);
                Loc1 = cell(1, numel(sliceLocNew)); Loc1(:) = {''};
                for i = 1:numel(LocsPosOrig)
                    [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                    Loc1(ind) = LocsVal(i);
                end
                
                %_Set Landmarks
                LocsInd = find(~ismember(s.Loc2,''));
                LocsVal = s.Loc2(LocsInd);
                LocsPosOrig = s.sliceLoc(LocsInd);
                Loc2 = cell(1, numel(sliceLocNew)); Loc2(:) = {''};
                for i = 1:numel(LocsPosOrig)
                    [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
                    Loc2(ind) = LocsVal(i);
                end
                
                %_Set sliceNr
                sliceNr = 1:numel(sliceLocNew);
                
                %_Plot Interpolation Reults
                figure();
                plot(diff(x),'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                hold on
                plot(diff(x2),'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                plot(diff(xn),'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                drawnow;
                a = gca;
                a.XLabel.String = 'sliceLocation';
                a.YLabel.String = 'VatArea';
                legend('show');
                
                figure();
                plot(x, y, 'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
                hold on
                plot(x2,y2,'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
                plot(xn,ynSatArea,'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
                drawnow;
                a = gca;
                a.XLabel.String = 'sliceLocation';
                a.YLabel.String = 'VatArea';
                legend('show');
                
                
                
                
                waitfor(msgbox('Slice locations are not equally distributed -> interpolation was done as shown in figure!'));
                
                
            else
                sliceLocNew = s.sliceLoc;
                SatVol = s.SatVol;
                VatVol = s.VatVol;
                sliceNr = s.sliceNr;
                Loc1 = s.Loc1;
                Loc2 = s.Loc2;
            end


            Pos = 1;
            xlswrite(xlsPath, {info.patientName} , 'FAT', 'A1');
            xlswrite(xlsPath, {info.creationDate} , 'FAT', 'A2');
            xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', 'A3');
            xlswrite(xlsPath, sliceNr', 'FAT', 'A4');
            xlswrite(xlsPath, sliceLocNew', 'FAT', 'B4');
            xlswrite(xlsPath, [0 diff(sliceLocNew)]', 'FAT', 'C4');
            xlswrite(xlsPath, round(SatVol)', 'FAT', 'D4');
            xlswrite(xlsPath, round(VatVol)', 'FAT', 'E4');
            xlswrite(xlsPath, Loc1', 'FAT', 'F4');
            xlswrite(xlsPath, Loc2', 'FAT', 'G4');
            Pos = 3+numel(VatVol)+1;
            xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', ['A' num2str(Pos)]);
            Pos = Pos+2;
            xlswrite(xlsPath, {'Summe'}, 'FAT', ['A' num2str(Pos)]);
            xlswrite(xlsPath, round(sum(SatVol)), 'FAT', ['D' num2str(Pos)]);
            xlswrite(xlsPath, round(sum(VatVol)), 'FAT', ['E' num2str(Pos)]);
            
            
        end
        
        function closeReq(tabDat, d)
            b = questdlg('save data before exit?', 'saveData yes/no', 'yes', 'no', 'yes');
            switch b
                case 'yes'
                    d.saveData;
                case 'no'
            end
        end
        
        % % % Object Management % % %
        function tabDat = updatetabDatFatSegmentIOphase(tabDat, data, saveDate)
            % here each slice gets implemented in the current tabDat and
            % tabDatFatSegment structure
            for i = 1:numel(data)
                tabDat(i) = tabDatFatSegmentIOphase;  % object
                cTabDat = data(i);  % simple variable (struct)
                if isfield(cTabDat, 'version_tabDatFatSegmentIOphase')
                    switch cTabDat.version_tabDatFatSegmentIOphase
                        case {'1.0' '1.2'}
                            for f = fieldnames(tabDat(i))'
                                f = f{1};
                                tabDat(i).(f) = cTabDat.(f);
                            end
                            % take care about cfgversion!!?!!?!!?!!
                            sc = superclasses(class(tabDat(i)));
                            tabDat(i) = tabDat(i).(['update' sc{1}]);
                        otherwise
                            msgbox('tabDatFatSegmentIOphase version problem in tabDatFatSegmentIOphase_updateFcn!');
                    end
                    % if an old tabDatFat file is loaded:
                elseif isfield(cTabDat, 'version_tabDatFat')
                    cTabDat.Boundaries = boundary;
                    cTabDat.Boundaries(1).name = 'outerBound';
                    cTabDat.Boundaries(2).name = 'innerBound';
                    cTabDat.Boundaries(3).name = 'visceralBound';
                    try cTabDat.Boundaries(1).coord = cTabDat.outerBoundCoord{1}; end
                    try cTabDat.Boundaries(2).coord = cTabDat.innerBoundCoord{1}; end
                    try cTabDat.Boundaries(3).coord = cTabDat.visceralBoundCoord{1}; end
                    cTabDat.Various = {};
                    
                    ind = [1:numel(cTabDat.Boundaries)];
                    for j = fliplr(ind)
                        if isempty(cTabDat.Boundaries(j).coord)
                            cTabDat.Boundaries(j) = [];
                        end
                    end
                    
                    cTabDat.version_tabDatFatSegmentIOphase = tabDat.version_tabDatFatSegmentIOphase;
                    cTabDat.BoundData = {};
                    cTabDat.selectedBound = '';
                    for f = fieldnames(tabDat(i))'
                        f = f{1};
                        tabDat(i).(f) = cTabDat.(f);
                    end
                    
                    switch cTabDat.version_tabDatFat
                        case '0.1'
                            if saveDate<'20-Jan-2017'
                                tabDat(i).sliceLocation = tabDat(i).imgs(1).slicePosition;
                            end
                        case {'0.2' '0.2.1'}
                        otherwise
                            msgbox('tabDatFat version problem in tabDatFat_updateFcn!');
                    end
                    % take care about cfgversion!!?!!?!!?!!
                    sc = superclasses(class(tabDat(i)));
                    tabDat(i) = tabDat(i).(['update' sc{1}]);
                end
            end
            
        end
        
        function tabDat = tabDatFatSegmentIOphase(tabArray)
            
        end
    end
end

