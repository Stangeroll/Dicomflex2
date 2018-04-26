classdef cComputeFatSegment<cCompute
    properties
        %% these properties must exist
        pVersion_cComputeFatSegment = '1.2';
        
        %% these properties are just for application specific use
        oBoundaries = boundary.empty;
        pSelectedBound = '';
        pSliceDone = logical.empty;    % 0 means not semented, 1 means segemented
        pUseSlice = false;
        pLoc1 = '';
        pLoc2 = '';
        pFatThresh = 0;
    end
    
    methods(Static)
        
    end
    
    methods
        % % % data loading % % %
        function oComp = mInit_oCompApp(oComp, imgs, oCont)
            pFcfg = oCont.pFcfg;
            pAcfg = oCont.pAcfg;
            %-------------------------------%
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
                oComp(i) = feval(str2func(pAcfg.cComputeFcn));
                oComp(i).oImgs = imgs(indImg);
                oComp(i).pPatientName = imgs(indImg(1)).patientName;
                oComp(i).pDataName = oComp(i).pPatientName;
                oComp(i).pSliceLocation = imgs(indImg(1)).sliceLocation;
                oComp(i).pSliceDone = false;
            end
            [a sortInd] = sort(cellfun(@(x) str2num(x) ,{oComp.pSliceLocation}), 'ascend');
            oComp = oComp(sortInd);
            oComp = setStructArrayField(oComp, 'pLoc1', {pAcfg.table.columnFormat{5}{1}});
            oComp = setStructArrayField(oComp, 'pLoc2', {pAcfg.table.columnFormat{6}{1}});
        end
        
        % % % GUI update % % %
        function imgDisplay = mGetImg2Display(oComp, oCont)
            pFcfg = oCont.pFcfg;
            pAcfg = oCont.pAcfg;
            oComp = oCont.oComp(oCont.pTable.row);
            %-------------------------------%
            %% determine image to be shown
            stdImgType = pAcfg.standardImgType;
            switch pAcfg.imageDisplayMode
                case 'Water only'
                    imgDisplay = oComp.mWaterImg;
                case 'Fat only'
                    imgDisplay = oComp.mFatImg;
                case 'Out Phase only'
                    imgDisplay = oComp.mGetImgOfType('OutPhase');
                case 'In Phase only'
                    imgDisplay = oComp.mGetImgOfType('InPhase');
                case 'All Four'
                    msgbox('All Four: not implementet!');
                case stdImgType
                    imgDisplay = oComp.mGetImgOfType(stdImgType);
                    
            end
            
            %% convert
            imgDisplay = imgDisplay.scale2([0 255]);
        end
                
        function mPostPlot(oComp, oCont)
            pFcfg = oCont.pFcfg;
            pAcfg = oCont.pAcfg;
            oComp = oCont.oComp(oCont.pTable.row);
            imgAxis = oCont.pHandles.imgAxis;
            %-------------------------------%
            %% plot segmentation
            contCoord = {};
            colors = {};
            for i=1:numel(oComp.oBoundaries)
                cBound = oComp.oBoundaries(i);
                contCoord{i} = {cBound.coord};
                colors(i) = pAcfg.contour.colors(find(ismember(pAcfg.contour.names, cBound.name)));
            end
            % plot contours
            oCont.pHandles.contour = oCont.mDrawContour(imgAxis, contCoord, colors);
            %% plot line for miror axis
            if pAcfg.contour.showMirrorAxis
                coord = [oCont.oComp.pVarious];
                if numel(coord)>1
                    msgbox('to many mirro axis found in all data! check at 107.');
                elseif numel(coord)==1
                    
                    oCont.mDrawContour(imgAxis, {{[coord{1}.mirrorAxisY{1} coord{1}.mirrorAxisX{1}]}}, {'green'});
                end
            end
            %% plot rect
            if pAcfg.contour.showFemurBox
                try 
                    coord = bwboundaries(oCont.oComp(oCont.pVarious.femurBoxInd).pVarious.femurBox);
                    oCont.mDrawContour(imgAxis, {coord}, {[1 1 1]});
                    
                    pos = oCont.pVarious.femurBoxSize;
                    T1 = text(0, 0, '', 'Parent', oCont.pHandles.imgAxis, 'Color', 'white');
                    T2 = text(0, 0, '', 'Parent', oCont.pHandles.imgAxis, 'Color', 'white');
                    T1.String = num2str(round(pos(3)*oComp(1).oImgs(1).dicomInfo.PixelSpacing(2)));
                    T1.Position = [pos(1)+pos(3)/2-5, pos(2)-6];
                    T2.String = num2str(round(pos(4)*oComp(1).oImgs(1).dicomInfo.PixelSpacing(2)));
                    T2.Position = [pos(1)+pos(3)+2, pos(2)+pos(4)/2];
                catch
                    uiwait(msgbox('could not draw box'));
                    oComp.mShowFemurBox(oCont);
                end
            end
            %% TopLeft text in Image
            pos = [3, 6];
            gap = 8;
            letterSize = 10;
            letterStyle = 'bold';
            imgText = [pAcfg.imageDisplayMode ' - Slice ' num2str(oCont.pTable.row)];
            oCont.pHandles.imgText = text(pos(1),pos(2), imgText, 'Parent', imgAxis, 'Color', 'white'); pos(2) = pos(2)+gap;
            oCont.pHandles.imgText.FontSize = letterSize;
            oCont.pHandles.imgText.FontWeight = letterStyle;
            oCont.pHandles.imgText.HitTest = 'off';
            % boundary text im image
            for i = 1:numel(oComp.oBoundaries)
                if ~isempty(oComp.oBoundaries(i).coord)
                    % plot annotation
                    txt = oComp.oBoundaries(i).name;
                    t = text(pos(1),pos(2), txt, 'Parent', oCont.pHandles.imgAxis, 'Color', colors{i});
                    t.FontSize = letterSize;
                    t.FontWeight = letterStyle;
                    pos(2) = pos(2)+gap;
                end
            end
        end
        
        function oCont = mDrawGraph(oComp, oCont)
            pFcfg = oCont.pFcfg;
            pAcfg = oCont.pAcfg;
            datInd = oCont.pTable.row;
            oComp = oCont.oComp(datInd);
            graphAxis = oCont.pHandles.graphAxis;
            axes(graphAxis);
            visInd = oComp.oBoundaries.getBoundInd('visceralBound');
            %-------------------------------%
            % determine graphData to be plotted in graph
            if visInd==0
                graphData = oComp.mWaterImg.data;
            else
                visBounoCont = oComp.oBoundaries(visInd);
                VatMask = logical(oComp.mGetBoundMask(oComp.oImgs(1).data, oComp.oBoundaries(visInd).coord));
                graphData = oComp.mWaterImg.data(VatMask);
            end
            
            % plot hist with as many bars as the data has possible values
            if isfield(oCont.pHandles, 'graphPlot') && ishandle(oCont.pHandles.graphPlot)   % use current histogram
                %[histDat histInd] = histcounts(graphData, 'NumBins', max(graphData)/10)
                oCont.pHandles.graphPlot.Data = graphData;
                oCont.pHandles.graphPlot.NumBins = max(max(graphData))/10;
                oCont.pHandles.graphPlot.BinLimitsMode = 'manual';
                oCont.pHandles.graphPlot.BinLimits = [min(min(graphData)) max(max(graphData))];
                oCont.pHandles.graphAxis.YLim = [0 max(oCont.pHandles.graphPlot.Values)];
                
            else    % create histogram because not created, yet
                hold all;
                oCont.pHandles.graphPlot = histogram(graphData);
                oCont.pHandles.graphPlot.NumBins = max(max(graphData))/10;
                oCont.pHandles.graphPlot.BinLimitsMode = 'manual';
                oCont.pHandles.graphPlot.BinLimits = [min(min(graphData)) max(max(graphData))];
                oCont.pHandles.graphPlot.EdgeColor = oCont.pFcfg.apperance.designColor1;
                oCont.pHandles.graphPlot.EdgeAlpha = 0.66;
                oCont.pHandles.graphPlot.FaceColor = oCont.pFcfg.apperance.designColor1;
                oCont.pHandles.graphPlot.FaceAlpha = 0.2;
                oCont.pHandles.graphAxis.YTick = [];
                oCont.pHandles.graphAxis.XTickMode = 'auto';
                oCont.pHandles.graphAxis.FontWeight = 'bold';
                oCont.pHandles.graphAxis.Box = 'on';
                oCont.pHandles.graphPlot.HitTest = 'off';
                oCont.pHandles.graphAxis.YLabel.String = 'frequency';
                oCont.pHandles.graphAxis.XLabel.String = 'pixel intensity';
                hold off;
            end
            
            if visInd==0   % set hist line to fatThresh value
                try delete(oCont.pHandles.histLine); end
            else
                % update histogram threshold line
                oCont = oComp.mUpdateHistLine(oCont);
            end
            drawnow
            
            %% check if slice is done
            oComp = oComp.mSet_pSliceDone;
            %-------------------------------%
            oCont.oComp(datInd) = oComp;
        end
        
        function oCont = mUpdateHistLine(oComp, oCont)
            if isfield(oCont.pHandles, 'histLine') && isvalid(oCont.pHandles.histLine)    % use existing line
                oCont.pHandles.histLine.XData = [oComp.pFatThresh oComp.pFatThresh];
                oCont.pHandles.histLine.YData = [0 oCont.pHandles.graphAxis.YLim(2)];
            else    % create new line
                oCont.pHandles.histLine = line([oComp.pFatThresh oComp.pFatThresh], [0 oCont.pHandles.graphAxis.YLim(2)], 'parent', oCont.pHandles.graphAxis);
                oCont.pHandles.histLine.LineWidth = 3;
                oCont.pHandles.histLine.LineStyle = ':';
                oCont.pHandles.histLine.Color = 'green';
                oCont.pHandles.histLine.HitTest = 'off';
            end
        end
        
        function lines = mGetTextBoxLines(oComp, oCont)
            lines = string('');
        end
        
        % % % GUI Interaction % % %
        function oComp = mTableEdit(oComp, select)
            switch select.Source.ColumnName{select.Indices(2)}
                case 'UseIt'
                    oComp.pUseSlice = select.NewData;
            end
        end
        
        function oComp = mKeyPress(oComp, oCont, key)
            pAcfg = oCont.pAcfg;
            key = key.Key;
            %-------------------------------%
            oCont.pHandles.figure.WindowKeyReleaseFcn = {@oCont.mKeyRelease};
            %oCont.pHandles.figure.WindowKeyPressFcn = '';
            switch key
                case pAcfg.contour.keyAssociation  % normal grayed out contour display
                    oComp.pSelectedBound = pAcfg.contour.names(find(ismember(pAcfg.contour.keyAssociation, key)));
                    imgAxis = oCont.pHandles.imgAxis;
                    % delete axis childs
                    if exist('oCont.pHandles.contour')
                        for a = oCont.pHandles.contour
                            delete(a);
                        end
                    end
                    
                    %% Plot Contours grayed out
                    contCoord = {};
                    colors = {};
                    for i=1:numel(oComp.oBoundaries)
                        cBound = oComp.oBoundaries(i);
                        contCoord{i} = {cBound.coord};
                        if isequal({cBound.name}, oComp.pSelectedBound)
                            colors(i) = pAcfg.contour.colors(find(ismember(pAcfg.contour.names, oComp.pSelectedBound)));
                        else
                            colors{i} = [0.1 0.1 0.1];
                        end
                    end
                    % plot contours
                    oCont.pHandles.contour = oCont.mDrawContour(imgAxis, contCoord, colors);
                    
                    pause(0);
                    
                case pAcfg.key.deleteContour  % delete selected contour
                    disp('keyDelCont')
                    % delete contour if one contour is selected
                    otherKeys = oCont.pActiveKey(~ismember(oCont.pActiveKey, {key}))
                    if numel(otherKeys) > 1
                        disp('to many keys pressed');
                    else
                        switch otherKeys{1}
                            case pAcfg.contour.keyAssociation
                                contourName = pAcfg.contour.names(find(ismember(oCont.pAcfg.contour.keyAssociation, otherKeys{1})))
                                
                                boundInd = oComp.oBoundaries.getBoundInd(oComp.pSelectedBound);
                                if ~isempty(boundInd)
                                    oComp.oBoundaries(boundInd) = [];
                                    oComp.pSliceDone = false;
                                    oComp.pUseSlice = false;
                                end
                                
                        end
                    end

                case pAcfg.key.showVat  % show vat
                    oComp.mVatOverlay(oCont);
            end
            %-------------------------------%
            oCont.pAcfg = pAcfg;
        end
        
        function mKeyRelease(oComp, oCont, keys)
            oCont.pHandles.figure.WindowKeyPressFcn = @oCont.mKeyPress;
            
            
            oCont.pHandles.imgDisplay.AlphaData = 1;
            oCont.mTableCellSelect;
        end
        
        function mImgAxisButtonDown(oComp, oCont, hit)
            switch oCont.pActiveKey{1}
                case ''
                otherwise
                oCont.pLineCoord = [oCont.pHandles.imgAxis.CurrentPoint(1,2) oCont.pHandles.imgAxis.CurrentPoint(1,1)];
                oCont.pActiveMouse = oCont.pHandles.figure.SelectionType;
                
                oCont.pHandles.draw = oCont.mDrawContour(oCont.pHandles.imgAxis, {{oCont.pLineCoord}}, {'green'});
                oCont.pHandles.draw = oCont.pHandles.draw{1};
                if isempty(oCont.pHandles.figure.WindowButtonMotionFcn) | isempty(oCont.pHandles.figure.WindowButtonMotionFcn)
                    oCont.pHandles.figure.WindowButtonMotionFcn = {@oComp.mImgAxisButtonMotion, oCont};
                    oCont.pHandles.figure.WindowButtonUpFcn = {@oComp.mImgAxisButtonUp, oCont};
                else
                    msgbox('WindowButtonMotionFcn and WindowButtonUpFcn are already set');
                end
            end
        end
        
        function mImgAxisButtonMotion(oComp, a, b, oCont)
            newC = [oCont.pHandles.imgAxis.CurrentPoint(1,2) oCont.pHandles.imgAxis.CurrentPoint(1,1)];
            oCont.pLineCoord = [oCont.pLineCoord; newC];
            oCont.pHandles.draw.XData = oCont.pLineCoord(:,2);
            oCont.pHandles.draw.YData = oCont.pLineCoord(:,1);
            drawnow;
        end
        
        function mImgAxisButtonUp(oComp, a, b, oCont)
            oCont.pHandles.figure.WindowButtonMotionFcn = '';
            oCont.pHandles.figure.WindowButtonUpFcn = '';
            oCont = oCont.oComp.mUseDraw(oCont);
        end
        
        function mGraphAxisButtonDown(oComp, oCont, hit)
            % calc VAT
            oComp.pFatThresh = oCont.pHandles.graphAxis.CurrentPoint(1,1);
            
            oCont.oComp(oCont.pTable.row) = oComp;
            
            oComp.mUpdateHistLine(oCont);
            
            oComp.mVatOverlay(oCont);
            
            if isempty(oCont.pHandles.figure.WindowButtonMotionFcn) | isempty(oCont.pHandles.figure.WindowButtonMotionFcn)
                oCont.pHandles.figure.WindowButtonMotionFcn = {@oComp.mGraphAxisButtonMotion, oCont};
                oCont.pHandles.figure.WindowButtonUpFcn = {@oComp.mGraphAxisButtonUp, oCont};
            else
                msgbox('WindowButtonMotionFcn and WindowButtonUpFcn are already set');
            end
        end
        
        function mGraphAxisButtonMotion(oComp, a, b, oCont)
            oComp.pFatThresh = oCont.pHandles.graphAxis.CurrentPoint(1,1);
            oComp.mVatOverlay(oCont);
            %-------------------------------%
            oCont.oComp(oCont.pTable.row) = oComp;
            oComp.mUpdateHistLine(oCont);
        end
        
        function mGraphAxisButtonUp(oComp, a, b, oCont)
            oCont.pHandles.figure.WindowButtonMotionFcn = '';
            oCont.pHandles.figure.WindowButtonUpFcn = '';
            oCont.pHandles.imgDisplay.AlphaData = 1;
            oCont.mTableCellSelect;
        end
        
        % % % Experimental % % %
        % % Mirror Axis % %
            function oComp = mShowMirrorAxis(oComp, oCont)
            uiwait(msgbox('please reprogram code! mShowMirrorAxis is not up to date!!!'));
%             oCont.pAcfg.contour.showMirrorAxis = ~oCont.pAcfg.contour.showMirrorAxis;
%             if oCont.pAcfg.contour.showMirrorAxis == 0
%                 uiwait(msgbox('Mirror axis not visible'));
%             elseif oCont.pAcfg.contour.showMirrorAxis == 1
%                 uiwait(msgbox('Mirror axis now visible'));
%             end
            end
        
            function oComp = mSetMirrorAxis(oComp, oCont)
            uiwait(msgbox('please reprogram code! setMirrorAxis is not up to date!!!'));
%             oComp = setStructArrayField(oComp, 'pVarious.mirrorAxisX', {});
%             oComp = setStructArrayField(oComp, 'pVarious.mirrorAxisY', {});
%             
%             datInd = oCont.pTable.row;
%             oComp = oCont.oComp(datInd);
%             [x y] = getline(oCont.pHandles.imgAxis); % replace by "imline" if to be improved
%             oComp.pVarious.mirrorAxisX = {x};
%             oComp.pVarious.mirrorAxisY = {y};
%             oComp(datInd) = oComp;
%             oCont.mTableCellSelect;
            end
                
            function oComp = mDelMirrorAxis(oComp, oCont)
            uiwait(msgbox('please reprogram code! delMirrorAxis is not up to date!!!'));
%             oComp = setStructArrayField(oComp, 'pVarious', {});
%             
%             datInd = oCont.pTable.row;
%             oComp = oCont.oComp(datInd);
%             [x y] = getline(oCont.pHandles.imgAxis); % replace by "imline" if to be improved
%             oComp.pVarious.mirrorAxisX = {x};
%             oComp.pVarious.mirrorAxisY = {y};
%             oComp(datInd) = oComp;
%             oCont.mTableCellSelect;
            end
        
            function oCont = mSaveMirroredXls(oComp, oCont)
            uiwait(msgbox('please reprogram code! saveMirroredXls is not up to date!!!'));
%             wb = waitbar(0, 'saving XLS Hemi results');
%             wb.Name = 'saving....';
%             % find mirror axis
%             coord = [oComp.pVarious];
%             if numel(coord)>1
%                 msgbox('to many axes found in all data! check at saveMirroredXls.');
%             elseif numel(coord)==1
%                 x1 = coord{1}.mirrorAxisX{1}(1);
%                 x2 = coord{1}.mirrorAxisX{1}(2);
%                 y1 = coord{1}.mirrorAxisY{1}(1);
%                 y2 = coord{1}.mirrorAxisY{1}(2);
%                 
%                 %% start saving xls
%                 
%                 %% collect infos
%                 dicomInfo = oComp(1).mGetStandardImg.dicomInfo;
%                 try info.comment = dicomInfo.StudyComments; end
%                 try info.description = dicomInfo.RequestedProcedureDescription; end
%                 try info.physicianName = dicomInfo.ReferringPhysicianName.FamilyName; end
%                 try info.institution = dicomInfo.InstitutionName; end
%                 try info.stationName = dicomInfo.StationName; end
%                 try info.manufacturer = dicomInfo.Manufacturer; end
%                 try info.manufacturerModelName = dicomInfo.ManufacturerModelName; end
%                 
%                 try info.patientName = [dicomInfo.PatientName.FamilyName '_' dicomInfo.PatientName.GivenName];
%                 catch
%                     try info.patientName = dicomInfo.PatientName.FamilyName;
%                     catch
%                         info.patientName = 'NoName';
%                     end
%                 end
%                 try info.patientWeight = num2str(dicomInfo.PatientWeight); end
%                 try info.patientAge = dicomInfo.PatientAge; end
%                 try info.patientSex = dicomInfo.PatientSex; end
%                 try info.patientBirthDat = dicomInfo.PatientBirthDate; end
%                 try info.patientIoCont = dicomInfo.PatientID; end
%                 
%                 try info.creationDate = datestr(datenum(dicomInfo.InstanceCreationDate, 'yyyymmdd'), 'dd.mm.yyyy'); end
%                 
%                 % remove empty entries
%                 emptyInd = structfun(@isempty, info);
%                 infoFields = fieldnames(info);
%                 for i = 1:numel(emptyInd)
%                     if emptyInd(i)
%                         info = rmfield(info, infoFields(i));
%                     end
%                 end
%                 
%                 waitbar(0.3, wb);
% %% create struct with oComp Rechts°!
%                 img = oComp(1).mGetStandardImg;
%                 imgSize = size(img.data);
%                     %% preparation
%                 xlsPath = fullfile(oCont.pAcfg.lastLoadPath, [oCont.mGetSaveFilePrefix 'mirroredRECHTS_data.xlsx']);
%                 
%                     %% get line masks
%                 % get points at upper and lower edge of image according to y=mx+t
%                 m = (y2-y1)/(x2-x1);
%                 t = y1-m*x1;
%                 y11 = 1;
%                 x11 = (y11-t)/m;
%                 y22 = imgSize(2);
%                 x22 = (y22-t)/m;
%                 
%                 [x y] = makeLinePoints(x11, y11, x22, y22);
%                 lineMask = zeros(imgSize);
%                 lineMask = oComp.mGetBoundMask(lineMask, [y' x']);
%                 
%                 rightMask = lineMask;
%                 rightMask(1, x11:end) = 1;
%                 rightMask(end, x22:end) = 1;
%                 rightMask(:, end) = 1;
%                 rightMask = imfill(rightMask,'holes');
%                 
%                 leftMask = lineMask;
%                 leftMask(1, 1:x11) = 1;
%                 leftMask(end, 1:x22) = 1;
%                 leftMask(:, 1) = 1;
%                 leftMask = imfill(leftMask,'holes');
%                 
%                     %% read values from oComp to s struct left side
%                 for i = 1:numel(oComp)
%                     oComp = oComp(i);
%                     %% modify Boundaries for left side only
%                     if oComp.pSliceDone
%                     mask = leftMask;
%                     try
%                         oBoundInd = oComp.oBoundaries.getBoundInd('outerBound');
%                         oBound = oComp.oBoundaries(oBoundInd);
%                         oBoundMask = oComp.mGetBoundMask(img.data, oBound.coord);
%                         oBoundMask = oBoundMask&mask;
%                         tmp = bwboundaries(oBoundMask);
%                         oBound.coord = tmp{1};
%                     catch
%                         oBound = [];
%                     end
%                     
%                     try
%                         iBoundInd = oComp.oBoundaries.getBoundInd('innerBound');
%                         iBound = oComp.oBoundaries(iBoundInd);
%                         iBoundMask = oComp.mGetBoundMask(img.data, iBound.coord);
%                         iBoundMask = iBoundMask&mask;
%                         tmp = bwboundaries(iBoundMask);
%                         iBound.coord = tmp{1};
%                     catch
%                         iBound = [];
%                     end
%                     
%                     try
%                         vBoundInd = oComp.oBoundaries.getBoundInd('visceralBound');
%                         vBound = oComp.oBoundaries(vBoundInd);
%                         vBoundMask = oComp.mGetBoundMask(img.data, vBound.coord);
%                         vBoundMask = vBoundMask&mask;
%                         tmp = bwboundaries(vBoundMask);
%                         vBound.coord = tmp{1};
%                     catch
%                         vBound = [];
%                     end
%                     
%                     
%                     
%                     oComp.oBoundaries = [oBound iBound vBound];
%                     
%                     end
%                     
%                     s.voxVol(i) = oComp.oImgs(1).getVoxelVolume;
%                     s.fatThresh(i) = oComp.pFatThresh;
%                     try 
%                         oBoundCoord = oComp.oBoundaries(oComp.oBoundaries.getBoundInd('outerBound')); 
%                     catch
%                         oBoundCoord = []; 
%                     end
%                     try 
%                         oBoundMask = oComp.mGetBoundMask(oComp.mWaterImg.data, oBoundcoord.coord); 
%                     catch
%                         oBoundMask = [];
%                     end
%                     tmp = regionprops(oBoundMask , 'Area', 'Perimeter');
%                     if isempty(tmp)
%                         tmp(1).Area = 0;
%                         tmp(1).Perimeter = 0;
%                     end
%                     s.bodyArea(i) = tmp.Area;
%                     s.bodyPerimeter(i) = tmp.Perimeter;
%                     
%                     s.SatArea(i) = oComp.volumeSAT/oComp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
%                     s.VatArea(i) = oComp.volumeVAT/oComp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
%                     s.SatVol(i) = oComp.volumeSAT;
%                     s.VatVol(i) = oComp.volumeVAT;
%                     s.Loc1(i) = {oComp.pLoc1};
%                     s.Loc2(i) = {oComp.pLoc2};
%                     s.sliceLoc(i) = str2num(oComp.pSliceLocation);
%                     s.sliceNr(i) = i;
%                 end
%                 % postprocessing
%                 s.Loc1(ismember(s.Loc1, 'none')) = {''};
%                 s.Loc2(ismember(s.Loc2, 'none')) = {''};
%                 
%                 sFlip = structfun(@(x) x', s, 'Uniformoutput', 0);
%                 
%                     %% write to xls sheet (use all available data)
%                 writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
%                 writetable(struct2table(sFlip), xlsPath, 'Sheet', 'allFatData');
%                 
%                     %% write to xls sheet (xls file like <nikita 2016)
%                 if ~isnan(oCont.pAcfg.sliceSpacingInterpolationDistance) && any(abs(diff(s.sliceLoc) - oCont.pAcfg.sliceSpacingInterpolationDistance) > 0.5)
%                     % prepare data: interpolate to equidistant slice loc
%                     x = s.sliceLoc;
%                     sliceLocOld = x;
%                     window = oCont.pAcfg.sliceSpacingInterpolationDistance;
%                     xn = [x(1):window:x(end)];
%                     sliceLocNew = xn;
%                     % find correct slice width (oContescription available (oContrawIO)) for volume calculation
%                     sliceWidth = diff(sliceLocNew);
%                     sW1 = sliceWidth./2; sW1(end+1) = 0;
%                     sW2 = sliceWidth./2; sW2 = [0 sW2];
%                     sliceWidth = sW1+sW2;
%                     % now special treatment for boundary images (1 and end)
%                     sliceWidth(1) = sliceWidth(1)+str2num(oCont.oComp(1).oImgs(1).sliceThickness)/2;
%                     sliceWidth(end) = sliceWidth(end)+str2num(oCont.oComp(end).oImgs(end).sliceThickness)/2;
%                     % slice Width done!
%                     
%                     %_Calc VatVol
%                     y = s.VatArea;  % mm^2
%                     [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
%                     ynVatArea = interp1(x2, y2, sliceLocNew);
%                     VatVol = ynVatArea.*sliceWidth*0.001;
%                     
%                     %_Calc SatVol
%                     y = s.SatArea;  % mm^2
%                     [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
%                     ynSatArea = interp1(x2, y2, sliceLocNew);
%                     SatVol = ynSatArea.*sliceWidth*0.001;
%                     
%                     %_Set WKs
%                     LocsInd = find(~ismember(s.Loc1,''));
%                     LocsVal = s.Loc1(LocsInd);
%                     LocsPosOrig = s.sliceLoc(LocsInd);
%                     Loc1 = cell(1, numel(sliceLocNew)); Loc1(:) = {''};
%                     for i = 1:numel(LocsPosOrig)
%                         [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
%                         Loc1(ind) = LocsVal(i);
%                     end
%                     
%                     %_Set Landmarks
%                     LocsInd = find(~ismember(s.Loc2,''));
%                     LocsVal = s.Loc2(LocsInd);
%                     LocsPosOrig = s.sliceLoc(LocsInd);
%                     Loc2 = cell(1, numel(sliceLocNew)); Loc2(:) = {''};
%                     for i = 1:numel(LocsPosOrig)
%                         [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
%                         Loc2(ind) = LocsVal(i);
%                     end
%                     
%                     %_Set sliceNr
%                     sliceNr = 1:numel(sliceLocNew);
%                     
%                     %_Plot Interpolation Reults
%                     figure();
%                     plot(diff(x),'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
%                     hold on
%                     plot(diff(x2),'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
%                     plot(diff(xn),'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
%                     drawnow;
%                     a = gca;
%                     a.XLabel.String = 'sliceLocation';
%                     a.YLabel.String = 'VatArea';
%                     legend('show');
%                     
%                     figure();
%                     plot(x, y, 'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
%                     hold on
%                     plot(x2,y2,'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
%                     plot(xn,ynSatArea,'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
%                     drawnow;
%                     a = gca;
%                     a.XLabel.String = 'sliceLocation';
%                     a.YLabel.String = 'VatArea';
%                     legend('show');
%                     
%                     
%                     
%                     
%                     waitfor(msgbox('Slice locations are not equally distributed -> interpolation was done as shown in figure!'));
%                     
%                     
%                 else
%                     sliceLocNew = s.sliceLoc;
%                     SatVol = s.SatVol;
%                     VatVol = s.VatVol;
%                     sliceNr = s.sliceNr;
%                     Loc1 = s.Loc1;
%                     Loc2 = s.Loc2;
%                 end
%                 
%                 
%                 Pos = 1;
%                 xlswrite(xlsPath, {info.patientName} , 'FAT', 'A1');
%                 xlswrite(xlsPath, {info.creationDate} , 'FAT', 'A2');
%                 xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', 'A3');
%                 xlswrite(xlsPath, sliceNr', 'FAT', 'A4');
%                 xlswrite(xlsPath, sliceLocNew', 'FAT', 'B4');
%                 xlswrite(xlsPath, [0 diff(sliceLocNew)]', 'FAT', 'C4');
%                 xlswrite(xlsPath, round(SatVol)', 'FAT', 'D4');
%                 xlswrite(xlsPath, round(VatVol)', 'FAT', 'E4');
%                 xlswrite(xlsPath, Loc1', 'FAT', 'F4');
%                 xlswrite(xlsPath, Loc2', 'FAT', 'G4');
%                 Pos = 3+numel(VatVol)+1;
%                 xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', ['A' num2str(Pos)]);
%                 Pos = Pos+2;
%                 xlswrite(xlsPath, {'Summe'}, 'FAT', ['A' num2str(Pos)]);
%                 xlswrite(xlsPath, round(sum(SatVol)), 'FAT', ['D' num2str(Pos)]);
%                 xlswrite(xlsPath, round(sum(VatVol)), 'FAT', ['E' num2str(Pos)]);
%                 
%                 waitbar(0.6, wb);
% %% create struct with oComp Links°!
%                 img = oComp(1).mGetStandardImg;
%                 imgSize = size(img.data);
%                     %% preparation
%                 xlsPath = fullfile(oCont.pAcfg.lastLoadPath, [oCont.mGetSaveFilePrefix 'mirroredLINKS_data.xlsx']);
% %                 %[file, path] = uiputfile(xlsPath);
% %                 if path==0
% %                     return
% %                 end
% %                 xlsPath = fullfile(path,file);
%                 
%                     %% get line masks
%                 % get points at upper and lower edge of image according to y=mx+t
%                 m = (y2-y1)/(x2-x1);
%                 t = y1-m*x1;
%                 y11 = 1;
%                 x11 = (y11-t)/m;
%                 y22 = imgSize(2);
%                 x22 = (y22-t)/m;
%                 
%                 [x y] = makeLinePoints(x11, y11, x22, y22);
%                 lineMask = zeros(imgSize);
%                 lineMask = oComp.mGetBoundMask(lineMask, [y' x']);
%                 
%                 rightMask = lineMask;
%                 rightMask(1, x11:end) = 1;
%                 rightMask(end, x22:end) = 1;
%                 rightMask(:, end) = 1;
%                 rightMask = imfill(rightMask,'holes');
%                 
%                 leftMask = lineMask;
%                 leftMask(1, 1:x11) = 1;
%                 leftMask(end, 1:x22) = 1;
%                 leftMask(:, 1) = 1;
%                 leftMask = imfill(leftMask,'holes');
%                 
%                     %% read values from oComp to s struct right side
%                 for i = 1:numel(oComp)
%                     oComp = oComp(i);
%                     %% modify Boundaries for left side only
%                     if oComp.pSliceDone
%                     mask = rightMask;
%                     try
%                         oBoundInd = oComp.oBoundaries.getBoundInd('outerBound');
%                         oBound = oComp.oBoundaries(oBoundInd);
%                         oBoundMask = oComp.mGetBoundMask(img.data, oBound.coord);
%                         oBoundMask = oBoundMask&mask;
%                         tmp = bwboundaries(oBoundMask);
%                         oBound.coord = tmp{1};
%                     catch
%                         oBound = [];
%                     end
%                     
%                     try
%                         iBoundInd = oComp.oBoundaries.getBoundInd('innerBound');
%                         iBound = oComp.oBoundaries(iBoundInd);
%                         iBoundMask = oComp.mGetBoundMask(img.data, iBound.coord);
%                         iBoundMask = iBoundMask&mask;
%                         tmp = bwboundaries(iBoundMask);
%                         iBound.coord = tmp{1};
%                     catch
%                         iBound = [];
%                     end
%                     
%                     try
%                         vBoundInd = oComp.oBoundaries.getBoundInd('visceralBound');
%                         vBound = oComp.oBoundaries(vBoundInd);
%                         vBoundMask = oComp.mGetBoundMask(img.data, vBound.coord);
%                         vBoundMask = vBoundMask&mask;
%                         tmp = bwboundaries(vBoundMask);
%                         vBound.coord = tmp{1};
%                     catch
%                         vBound = [];
%                     end
%                         
%                     
%                     
%                     oComp.oBoundaries = [oBound iBound vBound];
%                     %oComp.volumeVAT
% % %                     
% %                     figure();
% %                     imshow(oBoundMask);
%                     
%                     
%                     
%                     end
%                     
%                     s.voxVol(i) = oComp.oImgs(1).getVoxelVolume;
%                     s.fatThresh(i) = oComp.pFatThresh;
%                     try 
%                         oBoundCoord = oComp.oBoundaries(oComp.oBoundaries.getBoundInd('outerBound')); 
%                     catch
%                         oBoundCoord = []; 
%                     end
%                     try 
%                         oBoundMask = oComp.mGetBoundMask(oComp.mWaterImg.data, oBoundcoord.coord); 
%                     catch
%                         oBoundMask = [];
%                     end
%                     tmp = regionprops(oBoundMask , 'Area', 'Perimeter');
%                     if isempty(tmp)
%                         tmp(1).Area = 0;
%                         tmp(1).Perimeter = 0;
%                     end
%                     s.bodyArea(i) = tmp.Area;
%                     s.bodyPerimeter(i) = tmp.Perimeter;
%                     
%                     s.SatArea(i) = oComp.volumeSAT/oComp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
%                     s.VatArea(i) = oComp.volumeVAT/oComp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
%                     s.SatVol(i) = oComp.volumeSAT;
%                     s.VatVol(i) = oComp.volumeVAT;
%                     s.Loc1(i) = {oComp.pLoc1};
%                     s.Loc2(i) = {oComp.pLoc2};
%                     s.sliceLoc(i) = str2num(oComp.pSliceLocation);
%                     s.sliceNr(i) = i;
%                 end
%                 % postprocessing
%                 s.Loc1(ismember(s.Loc1, 'none')) = {''};
%                 s.Loc2(ismember(s.Loc2, 'none')) = {''};
%                 
%                 sFlip = structfun(@(x) x', s, 'Uniformoutput', 0);
%                 
%                     %% write to xls sheet (use all available data)
%                 writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
%                 writetable(struct2table(sFlip), xlsPath, 'Sheet', 'allFatData');
%                 
%                     %% write to xls sheet (xls file like <nikita 2016)
%                 if ~isnan(oCont.pAcfg.sliceSpacingInterpolationDistance) && any(abs(diff(s.sliceLoc) - oCont.pAcfg.sliceSpacingInterpolationDistance) > 0.5)
%                     % prepare data: interpolate to equidistant slice loc
%                     x = s.sliceLoc;
%                     sliceLocOld = x;
%                     window = oCont.pAcfg.sliceSpacingInterpolationDistance;
%                     xn = [x(1):window:x(end)];
%                     sliceLocNew = xn;
%                     % find correct slice width (oContescription available (oContrawIO)) for volume calculation
%                     sliceWidth = diff(sliceLocNew);
%                     sW1 = sliceWidth./2; sW1(end+1) = 0;
%                     sW2 = sliceWidth./2; sW2 = [0 sW2];
%                     sliceWidth = sW1+sW2;
%                     % now special treatment for boundary images (1 and end)
%                     sliceWidth(1) = sliceWidth(1)+str2num(oCont.oComp(1).oImgs(1).sliceThickness)/2;
%                     sliceWidth(end) = sliceWidth(end)+str2num(oCont.oComp(end).oImgs(end).sliceThickness)/2;
%                     % slice Width done!
%                     
%                     %_Calc VatVol
%                     y = s.VatArea;  % mm^2
%                     [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
%                     ynVatArea = interp1(x2, y2, sliceLocNew);
%                     VatVol = ynVatArea.*sliceWidth*0.001;
%                     
%                     %_Calc SatVol
%                     y = s.SatArea;  % mm^2
%                     [x2 y2] = DconvV2(x,y,window,'xmeanymean',[]); x2 = x2{1}; y2 = y2{1};
%                     ynSatArea = interp1(x2, y2, sliceLocNew);
%                     SatVol = ynSatArea.*sliceWidth*0.001;
%                     
%                     %_Set WKs
%                     LocsInd = find(~ismember(s.Loc1,''));
%                     LocsVal = s.Loc1(LocsInd);
%                     LocsPosOrig = s.sliceLoc(LocsInd);
%                     Loc1 = cell(1, numel(sliceLocNew)); Loc1(:) = {''};
%                     for i = 1:numel(LocsPosOrig)
%                         [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
%                         Loc1(ind) = LocsVal(i);
%                     end
%                     
%                     %_Set Landmarks
%                     LocsInd = find(~ismember(s.Loc2,''));
%                     LocsVal = s.Loc2(LocsInd);
%                     LocsPosOrig = s.sliceLoc(LocsInd);
%                     Loc2 = cell(1, numel(sliceLocNew)); Loc2(:) = {''};
%                     for i = 1:numel(LocsPosOrig)
%                         [val ind] = min(abs(sliceLocNew-LocsPosOrig(i)));
%                         Loc2(ind) = LocsVal(i);
%                     end
%                     
%                     %_Set sliceNr
%                     sliceNr = 1:numel(sliceLocNew);
%                     
%                     %_Plot Interpolation Reults
%                     figure();
%                     plot(diff(x),'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
%                     hold on
%                     plot(diff(x2),'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
%                     plot(diff(xn),'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
%                     drawnow;
%                     a = gca;
%                     a.XLabel.String = 'sliceLocation';
%                     a.YLabel.String = 'VatArea';
%                     legend('show');
%                     
%                     figure();
%                     plot(x, y, 'LineStyle', 'none', 'Marker', 'o', 'Color', 'black', 'DisplayName', 'raw');
%                     hold on
%                     plot(x2,y2,'LineStyle', 'none', 'Marker', 'x', 'Color', 'black', 'DisplayName', 'smooth');
%                     plot(xn,ynSatArea,'LineStyle', 'none', 'Marker', '.', 'Color', 'red', 'DisplayName', 'interpolated');
%                     drawnow;
%                     a = gca;
%                     a.XLabel.String = 'sliceLocation';
%                     a.YLabel.String = 'VatArea';
%                     legend('show');
%                     
%                     
%                     
%                     
%                     waitfor(msgbox('Slice locations are not equally distributed -> interpolation was done as shown in figure!'));
%                     
%                     
%                 else
%                     sliceLocNew = s.sliceLoc;
%                     SatVol = s.SatVol;
%                     VatVol = s.VatVol;
%                     sliceNr = s.sliceNr;
%                     Loc1 = s.Loc1;
%                     Loc2 = s.Loc2;
%                 end
%                 
%                 
%                 Pos = 1;
%                 xlswrite(xlsPath, {info.patientName} , 'FAT', 'A1');
%                 xlswrite(xlsPath, {info.creationDate} , 'FAT', 'A2');
%                 xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', 'A3');
%                 xlswrite(xlsPath, sliceNr', 'FAT', 'A4');
%                 xlswrite(xlsPath, sliceLocNew', 'FAT', 'B4');
%                 xlswrite(xlsPath, [0 diff(sliceLocNew)]', 'FAT', 'C4');
%                 xlswrite(xlsPath, round(SatVol)', 'FAT', 'D4');
%                 xlswrite(xlsPath, round(VatVol)', 'FAT', 'E4');
%                 xlswrite(xlsPath, Loc1', 'FAT', 'F4');
%                 xlswrite(xlsPath, Loc2', 'FAT', 'G4');
%                 Pos = 3+numel(VatVol)+1;
%                 xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SAT [cm^3]' 'VAT [cm^3]' 'Loc1' 'Loc2'} , 'FAT', ['A' num2str(Pos)]);
%                 Pos = Pos+2;
%                 xlswrite(xlsPath, {'Summe'}, 'FAT', ['A' num2str(Pos)]);
%                 xlswrite(xlsPath, round(sum(SatVol)), 'FAT', ['D' num2str(Pos)]);
%                 xlswrite(xlsPath, round(sum(VatVol)), 'FAT', ['E' num2str(Pos)]);
%                 
%                 waitbar(0.9, wb);
%                 pause(0.3);
%                 close(wb);
%             end
%             
%             uiwait(msgbox('mirror save xls Done!!'));
%             
        end
        
        % % Femur Box % %
        function oComp = mShowFemurBox(oComp, oCont)
            oCont.pAcfg.contour.showFemurBox = ~oCont.pAcfg.contour.showFemurBox;
            if oCont.pAcfg.contour.showFemurBox == 0
                uiwait(msgbox('Femur Box not visible'));
            elseif oCont.pAcfg.contour.showFemurBox == 1
                uiwait(msgbox('Femur Box now visible'));
            end
        end
       
        function mShowFemurBoxSize(oComp, hBox, T1, T2)
            pos = hBox.getPosition;
            %-------------------------------%
            T1.String = num2str(round(pos(3)*oComp(1).oImgs(1).dicomInfo.PixelSpacing(1)));
            T1.Position = [pos(1)+pos(3)/2-5, pos(2)-6];
            T2.String = num2str(round(pos(4)*oComp(1).oImgs(1).dicomInfo.PixelSpacing(2)));
            T2.Position = [pos(1)+pos(3)+2, pos(2)+pos(4)/2];
        end
        
        function oComp = mSetFemurBox(oComp, oCont)
            hBox = imrect(oCont.pHandles.imgAxis);
            pos = hBox.getPosition;
            %-------------------------------%
            Message = text(0, 0, '', 'Parent', oCont.pHandles.imgAxis, 'Color', 'white');
            Message.String = 'Double click on box to confirm!';
            Message.Position = [pos(1)+pos(3)/2-40, pos(2)+pos(4)/3-3];
            Message.FontSize = 14;
            Message.FontWeight = 'bold';
            T1 = text(0, 0, '', 'Parent', oCont.pHandles.imgAxis, 'Color', 'white');
            T1.FontSize = 14;
            T1.FontWeight = 'bold';
            T2 = text(0, 0, '', 'Parent', oCont.pHandles.imgAxis, 'Color', 'white');
            T2.FontSize = 14;
            T2.FontWeight = 'bold';
            oComp.mShowFemurBoxSize(hBox, T1, T2);
            addNewPositionCallback(hBox, @(varargout)oComp.mShowFemurBoxSize(hBox, T1, T2));
            
            wait(hBox);
            pos = hBox.getPosition;
            datInd = oCont.pTable.row;
            oCompTmp = oCont.oComp(datInd);
            oCompTmp.pVarious.femurBox = createMask(hBox);
            oComp(datInd) = oCompTmp;
            
            oCont.pVarious.femurBoxInd = datInd;
            oCont.pVarious.femurBoxSize = pos;
            oCont.pAcfg.contour.showFemurBox = 1;
        end
        
        function oComp = mDelFemurBox(oComp, oCont)
            oCont.oComp(oCont.pVarious.femurBoxInd).pVarious = rmfield(oCont.oComp(oCont.pVarious.femurBoxInd).pVarious, 'femurBox');
            oCont.pVarious.femurBoxInd = 0;
            oCont.pAcfg.contour.showFemurBox = 0;
        end
        
        function oComp = mSaveBoxResults(oComp, oCont)
            wb = waitbar(0, 'saving XLS box results');
            wb.Name = 'saving....';
            %% collect infos
                dicomInfo = oComp(1).mGetStandardImg.dicomInfo;
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
                try info.patientIoCont = dicomInfo.PatientID; end
                
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
            %% create struct with oComp!
                img = oComp(1).mGetStandardImg;
                imgSize = size(img.data);
                    %% preparation
                xlsPath = fullfile(oCont.pAcfg.lastLoadPath, [oCont.mGetSaveFilePrefix 'FemurBox_data.xlsx']);
                
                    %% get masks
                mask = oCont.oComp(oCont.pVarious.femurBoxInd).pVarious.femurBox;
                
                    %% read values from oComp to s struct
                for i = 1:numel(oComp)
                    oCompTmp = oComp(i);
                    %% modify Boundaries for left side only
                    if oCompTmp.pSliceDone
                    try
                        oBoundInd = oCompTmp.oBoundaries.getBoundInd('outerBound');
                        oBound = oCompTmp.oBoundaries(oBoundInd);
                        oBoundMask = oCompTmp.mGetBoundMask(img.data, oBound.coord);
                        oBoundMask = oBoundMask&mask;
                        tmp = bwboundaries(oBoundMask);
                        oBound.coord = tmp{1};
                    catch
                        oBound = [];
                    end
                    
                    try
                        iBoundInd = oCompTmp.oBoundaries.getBoundInd('innerBound');
                        iBound = oCompTmp.oBoundaries(iBoundInd);
                        iBoundMask = oCompTmp.mGetBoundMask(img.data, iBound.coord);
                        iBoundMask = iBoundMask&mask;
                        tmp = bwboundaries(iBoundMask);
                        iBound.coord = tmp{1};
                    catch
                        iBound = [];
                    end
                    
                    try
                        vBoundInd = oCompTmp.oBoundaries.getBoundInd('visceralBound');
                        vBound = oCompTmp.oBoundaries(vBoundInd);
                        vBoundMask = oCompTmp.mGetBoundMask(img.data, vBound.coord);
                        vBoundMask = vBoundMask&mask;
                        tmp = bwboundaries(vBoundMask);
                        vBound.coord = tmp{1};
                    catch
                        vBound = [];
                    end
                    
                    oCompTmp.oBoundaries = [oBound iBound vBound];
                    
                    end
                    
                    s.voxVol(i) = oCompTmp.oImgs(1).getVoxelVolume;
                    s.fatThresh(i) = oCompTmp.pFatThresh;
                    try 
                        oBoundCoord = oCompTmp.oBoundaries(oCompTmp.oBoundaries.getBoundInd('outerBound')); 
                    catch
                        oBoundCoord = []; 
                    end
                    try 
                        oBoundMask = oCompTmp.mGetBoundMask(oCompTmp.mWaterImg.data, oBoundcoord.coord); 
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
                    
                    s.SatArea(i) = oCompTmp.mVolumeSAT/oCompTmp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.VatArea(i) = oCompTmp.mVolumeVAT/oCompTmp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
                    s.SatVol(i) = oCompTmp.mVolumeSAT;
                    s.VatVol(i) = oCompTmp.mVolumeVAT;
                    s.Loc1(i) = {oCompTmp.pLoc1};
                    s.Loc2(i) = {oCompTmp.pLoc2};
                    s.sliceLoc(i) = str2num(oCompTmp.pSliceLocation);
                    s.sliceNr(i) = i;
                    if isempty(oCompTmp.pUseSlice)
                        oCompTmp.pUseSlice = false;
                    end
                    s.useSlice (i) = oCompTmp.pUseSlice;
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
                % filter accordint to pUseSlice
                s.SatVol(~s.useSlice) = 0;
                s.VatVol(~s.useSlice) = 0;
            
                if ~isnan(oCont.pAcfg.sliceSpacingInterpolationDistance) && any(abs(diff(s.sliceLoc) - oCont.pAcfg.sliceSpacingInterpolationDistance) > 0.5)
                    % prepare data: interpolate to equidistant slice loc
                    x = s.sliceLoc;
                    sliceLocOld = x;
                    window = oCont.pAcfg.sliceSpacingInterpolationDistance;
                    xn = [x(1):window:x(end)];
                    sliceLocNew = xn;
                    % find correct slice width (oContescription available (oContrawIO)) for volume calculation
                    sliceWidth = diff(sliceLocNew);
                    sW1 = sliceWidth./2; sW1(end+1) = 0;
                    sW2 = sliceWidth./2; sW2 = [0 sW2];
                    sliceWidth = sW1+sW2;
                    % now special treatment for boundary images (1 and end)
                    sliceWidth(1) = sliceWidth(1)+str2num(oCont.oComp(1).oImgs(1).sliceThickness)/2;
                    sliceWidth(end) = sliceWidth(end)+str2num(oCont.oComp(end).oImgs(end).sliceThickness)/2;
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
            function oCont = mImportNikitaBound(oComp, oCont)
            % import only roi data from old Nikita tool < 2016
            mb = msgbox('klick OK to load an old Nikita mat file <2016 with Bound data to be importeoCont.');
            waitfor(mb);
            [file folder] = uigetfile(fullfile(oCont.pAcfg.lastLoadPath, '*.mat'));
            load(fullfile(folder, file), 'threshold');
            load(fullfile(folder, file), 'X_seg');
            names = {'outerBound', 'innerBound', 'visceralBound'};
            for i = 1:numel(names) %run through names
                for j = 1:numel(X_seg(1,1,1,:,i))   %run through slices
                    cBoundCoords = bwboundaries(X_seg(:,:,1,j,i));
                    if isempty(cBoundCoords)
                    else
                        cBoundIn = oComp(j).oBoundaries.empty;
                        cBoundIn(1).name = names{i};
                        cBoundIn.coord = cBoundCoords{1};
                        
                        cBounds = oComp(j).oBoundaries;
                        cBounds = setBound(cBounds, cBoundIn);
                        oComp(j).oBoundaries = cBounds;
                        oComp(j).pFatThresh = threshold(j);
                        
                        %% check if slice is done
                        oComp(j) = oComp(j).setpSliceDone;
                    end
                    
                end
                
            end
            
            oCont.oComp = oComp;
            oCont.mTableCellSelect;
        end
        
        % % % Image Organisation % % %
        function img = mFatImg(oComp)
            img = cImageDcm;
            inPhaseImg = oComp.mGetImgOfType('InPhase');
            outPhaseImg = oComp.mGetImgOfType('OutPhase');
            
            img.data = (inPhaseImg.data-outPhaseImg.data)./2;
            img.imgType = 'Fat';
        end
        
        function img = mWaterImg(oComp)
            img = cImageDcm;
            inPhaseImg = oComp.mGetImgOfType('InPhase');
            outPhaseImg = oComp.mGetImgOfType('OutPhase');
            
            img.data = (inPhaseImg.data+outPhaseImg.data)./2;
            img.imgType = 'Water';
        end
        
        function mVatOverlay(oComp, oCont)
            vbInd = oComp.oBoundaries.getBoundInd('visceralBound');
            VatImg = oComp.mWaterImg;
            VatMask = ~logical(oComp.mGetBoundMask(VatImg.data, oComp.oBoundaries(vbInd).coord));
            %-------------------------------%
            VatImg.data(VatMask) = 0;   % only Vat pxls are not 0
            VatFatPxl = VatImg.data>oComp.pFatThresh;  % Vat is only pxlValues bigger than hist cursor
            % indicate the VatFat pixels with overlay
            maskInd = find(VatFatPxl);
            color = 1-oCont.pAcfg.color3;
            oComp.pHistory.plotImgRGB = oComp.pHistory.plotImg.conv2RGB;
            img = oComp.pHistory.plotImg.data;
%             if isfield(oComp.pHistory, 'vatOverlay') && ~isempty(oComp.pHistory.vatOverlay)
%                 img = oCont.pHandles.imgDisplay.CData;
%                 % remove overlay
%                 oldInd = oComp.pHistory.vatOverlay;
%                 Rimg = img(:,:,1);
%                 Rimg(oldInd) = Rimg(oldInd)./(1-color(1));
%                 Gimg = img(:,:,2);
%                 Gimg(oldInd) = Gimg(oldInd)./(1-color(1));
%                 Bimg = img(:,:,3);
%                 Bimg(oldInd) = Bimg(oldInd)./(1-color(1));
%             else
%                 img = oCont.pHandles.imgDisplay.CData;
%             end
            
            Rimg = img(:,:,1);
            Rimg(maskInd) = Rimg(maskInd) - Rimg(maskInd).*color(1);
            Gimg = img(:,:,1);
            Gimg(maskInd) = Gimg(maskInd) - Gimg(maskInd).*color(2);
            Bimg = img(:,:,1);
            Bimg(maskInd) = Bimg(maskInd) - Bimg(maskInd).*color(3);
            
            RGBimg = [Rimg Gimg Bimg];
            RGBimg = reshape(RGBimg, size(Rimg,1), size(Rimg,2), 3);
            
            %-------------------------------%
            oCont.pHandles.imgDisplay.CData = uint8(RGBimg);
        end
        
        % % % Segmentaion Organisation % % %
        function oComp = mAutoSegment(oComp, segProps)
            iBound = oComp.oBoundaries.getBoundOfType('innerBound');
            oBound = oComp.oBoundaries.getBoundOfType('outerBound');
            vBound = oComp.oBoundaries.getBoundOfType('visceralBound');
            %-------------------------------%
            switch segProps.name
                case 'NikitaFat160322Segmenting.m'
                    imgBase = oComp.mGetImgOfType('OutPhase');
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
                    imgIn = oComp.mGetImgOfType('InPhase');
                    imgOut = oComp.mGetImgOfType('OutPhase');
                    oBound.coord = {RSouterBound(imgIn, 'MRT_OutPhase', segProps.magThreshold)};
                case 'OuterBound_RS+NikitaFat'
                    imgIn = oComp.mGetImgOfType('InPhase');
                    imgOut = oComp.mGetImgOfType('OutPhase');
                    outerBoundCoord = {RSouterBound(imgIn, 'MRT_OutPhase', 8)};
                    
                    imgBody = imgOut.data;
                    indBody = find(~oComp.mGetBoundMask(imgOut.data, outerBoundCoord));
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
                    imgBase = oComp.mGetImgOfType('OutPhase');
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
            %-------------------------------%
            try
                oBound.coord = oBound.coord{1};
                oComp.oBoundaries = oComp.oBoundaries.setBound(oBound);
            end
            try
                iBound.coord = iBound.coord{1};
                oComp.oBoundaries = oComp.oBoundaries.setBound(iBound);
            end
            try
                vBound.coord = vBound.coord{1};
                oComp.oBoundaries = oComp.oBoundaries.setBound(vBound);
            end
            oComp = oComp.mSet_pSliceDone;
        end
        
        function oComp = mAutoSegmentSingle(oComp, oCont)
            if numel(oComp)==1
                Ind = 1;
            else
                Ind = oCont.pTable.row;
            end
            oComp(Ind) = oComp(Ind).mAutoSegment(oCont.pAcfg.segProps);
            %-------------------------------%
        end
        
        function oComp = mAutoSegmentAll(oComp, oCont)
            wb = waitbar(0, ['Image 1 of ' num2str(numel(oComp)) '. Time left: inf']);
            wb.Name = 'segmenting image data';
            numel(oComp)
            for i=1:numel(oComp)
                i
                if ~oComp(i).pSliceDone
                    t1 = tic;
                    oComp(i) = oComp(i).mAutoSegment(oCont.pAcfg.segProps);
                    
                    t2 = toc(t1);
                    time(i) = t2;
                    timeLeft = median(time)*(numel(oComp)-i);
                    if ishandle(wb)
                        waitbar(i/numel(oComp), wb, ['Image ' num2str(i+1) ' of ' num2str(numel(oComp)) '. Time left: ' num2str(timeLeft, '%.0f') ' sec']);
                    else
                        disp('aha');
                        return % user abord
                    end
                end
            end
            close(wb);
        end
        
        function oComp = mSet_pSliceDone(oComp)
            if ~oComp.oBoundaries.getBoundInd('outerBound')==0 & ~oComp.oBoundaries.getBoundInd('innerBound')==0 & ~oComp.oBoundaries.getBoundInd('visceralBound')==0 & oComp.pFatThresh>1
                % use slice if it switches to Done from notDone
                if oComp.pSliceDone == false
                    oComp.pUseSlice = true;
                end
                oComp.pSliceDone = true;
            else
                oComp.pSliceDone = false;
            end
            
        end
        
            function oComp = mClearSegment(oComp)
            oComp
                % to be done
            
        end
        
        function oComp = mFindThreshLvl(oComp, oCont)
            oCompTmp = oComp(oCont.pTable.row);
            %-------------------------------%
            if ~oCompTmp.oBoundaries.getBoundInd('outerBound')==0 & ~oCompTmp.oBoundaries.getBoundInd('innerBound')==0
                %AUTOMATISCH THRESHOLDERMITTLUNG
                outerCoord = oCompTmp.oBoundaries(oCompTmp.oBoundaries.getBoundInd('outerBound')).coord;
                innerCoord = oCompTmp.oBoundaries(oCompTmp.oBoundaries.getBoundInd('innerBound')).coord;
                visceralCoord = oCompTmp.oBoundaries(oCompTmp.oBoundaries.getBoundInd('visceralBound')).coord;
                
                outerMask = oCompTmp.mGetBoundMask(oCompTmp.mWaterImg.data, outerCoord);
                innerMask = oCompTmp.mGetBoundMask(oCompTmp.mWaterImg.data, innerCoord);
                satMask = outerMask&~innerMask;
                
                satMask(:,1:min(visceralCoord(:,2))) = 0;
                satMask(:,max(visceralCoord(:,2)):end) = 0;
                satMask = imerode(satMask, strel('diamond', 6));
                
                
                satIntensities = oCompTmp.mWaterImg.data(find(satMask));
                
                %                 figure();
                %                 imshow(satMask);
                %                 imshow(imerode(satMask, strel('diamond',5)));
                %                 histogram(satIntensities, 100);
                
                oCompTmp.pFatThresh = prctile(satIntensities, 0.5);
            else
                uiwait(msgbox('SAT must be segmented for FatThreshold determination!'));
            end
            
            oComp(oCont.pTable.row) = oCompTmp;
            oCont.mTableCellSelect;
            
            %
            %             oCont.pAcfg.autoThresh = ~oCont.pAcfg.autoThresh;
            %             if oCont.pAcfg.autoThresh == 0
            %                 uiwait(msgbox('AutoThresholding is Off now! Please set threshold level manually.'));
            %             elseif oCont.pAcfg.autoThresh == 1
            %                 uiwait(msgbox('AutoThresholding is On now!'));
%                 oComp = oComp.determineFatThresh(oCont);
%             end
        end
        
        function volumeSAT = mVolumeSAT(oComp) % in cm^3
            try
                obInd = oComp.oBoundaries.getBoundInd('outerBound');
            catch
                uiwait(msgbox(['OuterBoundary could not be found for slice location ' num2str(oComp.pSliceLocation)]));
                volumeSAT = 0;
                return
            end
            try
                ibInd = oComp.oBoundaries.getBoundInd('innerBound');
            catch
                uiwait(msgbox(['InnerBoundary could not be found for slice location ' num2str(oComp.pSliceLocation)]));
                volumeSAT = 0;
                return
            end
            %-------------------------------%
            if obInd==0 | ibInd==0
                volumeSAT = 0;
            else
                pxlcount = (oComp.oBoundaries(obInd).areaBound - oComp.oBoundaries(ibInd).areaBound);
                volumeSAT = pxlcount*oComp.oImgs(1).getVoxelVolume;
            end
        end
        
        function volumeVAT = mVolumeVAT(oComp) % in cm^3
            try
                vbInd = oComp.oBoundaries.getBoundInd('visceralBound');
            catch
                uiwait(msgbox(['VisceralBoundary could not be found for slice location ' num2str(oComp.pSliceLocation)]));
                volumeVAT = 0;
                return
            end
            %-------------------------------%
            if vbInd==0
                volumeVAT = 0;
            else
                VatFatPxl = oComp.mGetVatFatPxl;  % Vat is only pxlValues bigger than hist cursor
                
                volumeVAT = sum(sum(VatFatPxl))*oComp.oImgs(1).getVoxelVolume;
            end
        end
        
        function VatFatPxl = mGetVatFatPxl(oComp)
            vbInd = oComp.oBoundaries.getBoundInd('visceralBound');
            VatImg = oComp.mWaterImg;
            VatMask = ~logical(oComp.mGetBoundMask(VatImg.data, oComp.oBoundaries(vbInd).coord));
            %-------------------------------%
            VatImg.data(VatMask) = 0;   % only Vat pxls are not 0
            VatFatPxl = VatImg.data>oComp.pFatThresh;  % Vat is only pxlValues bigger than hist cursor
        end
                
        % % % Application Management % % %
        function mSaveXls(oComp, oCont)
            %% preparation
            xlsPath = fullfile(oCont.pAcfg.lastLoadPath, [oCont.mGetSaveFilePrefix '_data.xlsx']);
            [file, path] = uiputfile(xlsPath);
            if path==0
                return
            end
            xlsPath = fullfile(path,file);
            %% collect infos and store in variables
            dicomInfo = oComp(1).mGetStandardImg.dicomInfo;
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
            try info.patientIoCont = dicomInfo.PatientID; end
            
            try info.creationDate = datestr(datenum(dicomInfo.InstanceCreationDate, 'yyyymmdd'), 'dd.mm.yyyy'); end
            
            % remove empty entries
            emptyInd = structfun(@isempty, info);
            infoFields = fieldnames(info);
            for i = 1:numel(emptyInd)
                if emptyInd(i)
                    info = rmfield(info, infoFields(i));
                end
            end
            
            % create struct with oComp data
            for i = 1:numel(oComp)
                oCompTmp = oComp(i);
                s.voxVol(i) = oCompTmp.oImgs(1).getVoxelVolume;
                s.fatThresh(i) = oCompTmp.pFatThresh;
                try 
                    oBoundCoord = oCompTmp.oBoundaries(oComp.oBoundaries.getBoundInd('outerBound')); 
                catch
                    oBoundCoord = []; 
                end
                try 
                    oBoundMask = oCompTmp.mGetBoundMask(oComp.mWaterImg.data, oBoundcoord.coord); 
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
                
                s.SatArea(i) = oCompTmp.mVolumeSAT/oCompTmp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
                s.VatArea(i) = oCompTmp.mVolumeVAT/oCompTmp.oImgs(1).dicomInfo.SpacingBetweenSlices*1000;
                s.SatVol(i) = oCompTmp.mVolumeSAT;
                s.VatVol(i) = oCompTmp.mVolumeVAT;
                s.Loc1(i) = {oCompTmp.pLoc1};
                s.Loc2(i) = {oCompTmp.pLoc2};
                s.sliceLoc(i) = str2num(oCompTmp.pSliceLocation);
                s.sliceNr(i) = i;
                if isempty(oCompTmp.pUseSlice)
                        oCompTmp.pUseSlice = false;
                    end
                s.useSlice (i) = oCompTmp.pUseSlice;
            end
            % postprocessing
            s.Loc1(ismember(s.Loc1, 'none')) = {''};
            s.Loc2(ismember(s.Loc2, 'none')) = {''};
            
            sFlip = structfun(@(x) x', s, 'Uniformoutput', 0);
            
            %% write to xls sheet (use all available data)
            writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
            writetable(struct2table(sFlip), xlsPath, 'Sheet', 'allFatData');
            
            %% write to xls sheet (xls file like <nikita 2016)
            % filter accordint to pUseSlice
            s.SatVol(~s.useSlice) = 0;
            s.VatVol(~s.useSlice) = 0;
            
            inconsistentSliceSpacing = any(abs(diff(s.sliceLoc) - oCont.pAcfg.sliceSpacingInterpolationDistance) > 0.1);
            if inconsistentSliceSpacing
                if isnan(oCont.pAcfg.sliceSpacingInterpolationDistance)
                    sliceSpacingInterpolationDistance = str2num(inputdlg('Set a interpolation value for slice spacing in mm:', 'SliceSpacing inconsistent'));
                    oCont.pAcfg.sliceSpacingInterpolationDistance = sliceSpacingInterpolationDistance
                end
                % prepare data: interpolate to equidistant slice loc
                x = s.sliceLoc;
                sliceLocOld = x;
                window = oCont.pAcfg.sliceSpacingInterpolationDistance;
                xn = [x(1):window:x(end)];
                sliceLocNew = xn;
                % find correct slice width (oContescription available (oContrawIO)) for volume calculation
                sliceWidth = diff(sliceLocNew);
                sW1 = sliceWidth./2; sW1(end+1) = 0;
                sW2 = sliceWidth./2; sW2 = [0 sW2];
                sliceWidth = sW1+sW2;
                % now special treatment for boundary images (1 and end)
                sliceWidth(1) = sliceWidth(1)+str2num(oCont.oComp(1).oImgs(1).sliceThickness)/2;
                sliceWidth(end) = sliceWidth(end)+str2num(oCont.oComp(end).oImgs(end).sliceThickness)/2;
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
        
        function mCloseReq(oComp, oCont)
            b = questdlg('save data before exit?', 'saveData yes/no', 'yes', 'no', 'yes');
            switch b
                case 'yes'
                    oCont.saveData;
                case 'no'
            end
        end
        
        % % % Object Management % % %
        function dataNew = mTabDat2oCompApp(oComp, dataOld, saveDate)
            %update from ISAT to Dicomflex (only for old ISAT datasets <20180401)
            dataNew = struct(oComp);
            dataNew = repmat(dataNew,1,numel(dataOld));
            % first update data to newest ISAT-tabDat version:
            tabDat = tabDatFatSegmentIOphase;
            tabDat = tabDat.updatetabDatFatSegmentIOphase(dataOld, saveDate);
            tabDat = arrayfun(@struct, tabDat);
            % convert ISAT to Dicomflex
            fields = fieldnames(dataNew);
            for i = 1:numel(fields)
                field = fields{i};
                switch field
                    case {'oBoundaries'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.Boundaries});
                    case {'pSliceDone'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.segmentDone});
                        dataNew = setStructArrayField(dataNew, 'pUseSlice', {tabDat.segmentDone});
                    case {'pLoc1'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.Loc1});
                    case {'pLoc2'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.Loc2});
                    case {'pFatThresh'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.fatThresh});
                    case {'oImgs'}
                        oImgTmp = cImageDcm;
                        for j = 1:numel(tabDat)
                            tabDat(j).imgs = oImgTmp.imgDcm2oImageDcm(tabDat(j).imgs);
                        end
                        dataNew = setStructArrayField(dataNew, field, {tabDat.imgs});
                    case {'pDataName'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.dataName});
                    case {'pHistory'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.history});
                    case {'pStandardImgType'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.standardImgType});
                    case {'pPatientName'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.patientName});
                    case {'pSliceLocation'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.sliceLocation});
                    case {'pVarious'}
                        dataNew = setStructArrayField(dataNew, field, {tabDat.Various});
                    otherwise
                end
            end
        end
        
        function oComp = mUpdate_cComputeFatSegment(oComp, data, saveDate)
            % here each slice gets implemented in the current oComp and
            % oCompFatSegment structure
            for i = 1:numel(data)
                oComp(i) = cComputeFatSegment;  % object
                oCompTmp = data(i);  % simple variable (struct)
                switch oCompTmp.pVersion_cComputeFatSegment
                    case {'1.2'}
                        for f = fieldnames(oComp(i))'
                            f = f{1};
                            oComp(i).(f) = oCompTmp.(f);
                        end
                        % take care about cfgversion!!?!!?!!?!!
                        sc = superclasses(class(oComp(i)));
                        oComp(i) = oComp(i).(['mUpdate_' sc{1}]);
                    otherwise
                        msgbox('oCompFatSegment version problem in oCompFatSegment_updateFcn!');
                end
            end
        end
        
        function oComp = cComputeFatSegment(cCompArray)
            
        end
    end
end

