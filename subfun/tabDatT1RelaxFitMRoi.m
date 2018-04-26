classdef tabDatT1RelaxFitMRoi<tabDat
    properties
        %% these properties must exist
        version_tabDatT1RelaxFitMRoi = '1.2';
        
        %% these properties are just for application specific use
        Boundaries = boundaryFit.empty;
        PxlData = struct('pxlNr', [], 'parameters', {}, 'rmse', [], 'rsquare', [], 'badFitReason', {}, 'fitOk', {}, 'values', {[]}, 'cFitObj', rsFitObj);
        selectedBound = '';
        segmentDone = 0;    % 0 means not semented, 1 means segemented but not fitted, 2 means segmented and fitted
    end
    
    methods(Static)
        
    end
    
    methods
        % % % File management % % %
        function tabDat = initImgArray(tabDat, imgs, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            % sort images and init dat struct
            i=0;
            sliceLocs = arrayfun(@(x) x.sliceLocation, imgs, 'un', false);
            for sliceLoc = unique(sliceLocs)
                i=i+1;
                indImg = find(ismember(sliceLocs, sliceLoc(1)));
                tabDat(i) = feval(str2func(cfgDM.tabDatFcn));
                imgstmp = imgs(indImg);
                TI = arrayfun(@(x) x.dicomInfo(1).InversionTime, imgstmp)';
                [a sortInd] = sort(TI, 'ascend');
                tabDat(i).imgs = imgstmp(sortInd);
                tabDat(i).patientName = imgs(indImg(1)).patientName;
                tabDat(i).dataName = [tabDat(i).patientName tabDat(1).imgs(1).dicomInfo.AcquisitionDate];
                tabDat(i).sliceLocation = imgs(indImg(1)).sliceLocation;
            end
            [a sortInd] = sort(cellfun(@(x) str2num(x) ,{tabDat.sliceLocation}), 'ascend');
            tabDat = tabDat(sortInd);
        end
        
        function fileName = getStandardFileName(tabDat)
            
        end
        
        % % % GUI update % % %
        function imgDisplay = getImg2Display(tabDat, d)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            tabDat = d.dat(d.tableRow);
            %% determine image to be shown
            switch cfgDM.imageDisplayMode
                case {'Ti', 'Raw Images'}
                    imgDisplay = tabDat.getImgOfType(cfgDM.standardImgType);
                    imgDisplay = imgDisplay(cfgDM.imageNr);
                case 'T1 Map'
                    imgDisplay = tabDat.getT1Img;
                    
                    FOkmask = tabDat.PxlData.fitOk;
                    R2mask = tabDat.PxlData.rsquare<0.8;
                    
                    HideMask = ~FOkmask | R2mask;
                    %HideMask = ~FOkmask;
                    imgDisplay.data(find(HideMask)) = min(min(imgDisplay.data));
                    imgDisplay.data(find(imgDisplay.data<100 | imgDisplay.data>400)) = 400;
                    
%                     T1 = cellfun(@(x) x(1), tabDat.PxlData.values);
%                     bad = find(T1>3000);
%                     
%                     tabDat.PxlData.rsquare(bad)
                    
                    
                    
                case 'T1 Gradient'
                    imgDisplay = tabDat.getT1Img;
                    FOkmask = tabDat.PxlData.fitOk;
                    R2mask = tabDat.PxlData.rsquare<0.8;
                    T1Mask = imgDisplay.data>500;
                    
                    
                    
                    
                    
                    
                    
                    imgDisplay.data = imgradient(imgDisplay.data, 'sobel');
                    GradMask = imgDisplay.data>400;
                    
                    HideMask = ~FOkmask | R2mask | T1Mask | GradMask;
                    imgDisplay.data(find(HideMask)) = min(min(imgDisplay.data));
                    
            end
            %% convert
            scale = ceil(size(tabDat.imgs(1).data)./size(imgDisplay.data));
            imgDisplay.data = imgDisplay.dataResize(min(scale));
            imgDisplay = imgDisplay.scale2([0 255]);
            
        end
                
        function postPlot(tabDat, d)
            
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            tabDat = d.dat(d.tableRow);
            imgAxis = d.handles.imgAxis;
            %% apply colormap
            switch cfgDM.imageDisplayMode
                case 'T1 Map'
                    colormap(d.handles.imgAxis, 'parula'); % parula jet hsv colorcube
                case 'T1 Gradient'
                    colormap(d.handles.imgAxis, 'parula'); % parula jet hsv colorcube
                otherwise
                    colormap(d.handles.imgAxis, 'gray');
            end
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
            %% TopLeft text in Image
            imgText = ['T1-image nr' num2str(cfgDM.imageNr)];
            imgText = [imgText ' - Row ' num2str(d.tableRow)];
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
            ctabDat = d.dat(d.tableRow);
            histAxis = d.handles.histAxis;
            ind = ctabDat.Boundaries.getBoundInd(ctabDat.selectedBound);
            if ind == 0;
                delete(d.handles.histAxis.Children);
            else
                cBound = ctabDat.Boundaries(ind);
                if ishandle(histAxis) & ~isempty(cBound) && ~isempty(cBound.FitObj.xData)
                    % histAxis exists
                    axes(histAxis);
                    d.handles.histAxis.Color = d.cfgMM.apperance.color1;
                    d.handles.histAxis.Box = 'on';
                    
                    %% plot x-y-Data
                    if isfield(d.handles, 'histPlot') && isvalid(d.handles.histPlot)
                        d.handles.histPlot.XData = cBound.FitObj.xData;
                        d.handles.histPlot.YData = cBound.FitObj.yData;
                    else
                        d.handles.histPlot = plot(cBound.FitObj.xData, cBound.FitObj.yData);
                        d.handles.histPlot.LineStyle = 'none';
                        d.handles.histPlot.Marker = 'o';
                        d.handles.histPlot.HitTest = 'off';
                    end
                    d.handles.histPlot.Color = cfgDM.contour.colors{find(ismember(cfgDM.contour.names, cBound.name))};
                    
                    %% plot fit if available
                    if ~isempty(cBound.FitObj.cfun)
                        if isfield(d.handles, 'histFplot') && isvalid(d.handles.histFplot)
                            d.handles.histFplot.YData = cBound.FitObj.cfun(d.handles.histFplot.XData);
                        else
                            hold on;
                            d.handles.histFplot = plot(cBound.FitObj.cfun);
                            %d.handles.histFplot = plot(cBoundaries.FitObj.cfun, cBoundaries.FitObj.xData, cBoundaries.FitObj.yData);
                            legend off;
                            d.handles.histFplot.LineWidth = 1.5;
                            hold off;
                        end
                        d.handles.histFplot.Color = cfgDM.contour.colors{find(ismember(cfgDM.contour.names, cBound.name))};
                    end
                    
                else
                    delete(d.handles.histAxis.Children);
                end
                drawnow
            end
        end
        
        function lines = getTextBoxLines(tabDat, d)
            textBox = d.handles.textBox;
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            tabDat = d.dat(d.tableRow);
            
            % are fat values up to date?
            if tabDat.segmentDone == 1 % 1 means segmented, but not fitted
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
                
%                 if isfield(cBound.various, 'T1')
%                     count = count+1;
%                     lines(count) = string([cBound.name ' T1_median: ' sprintf('%.1f', median(tabDat.getT1Img.data(cBound.various.pxlNrT1Img)))]);
%                     count = count+1;
%                     lines(count) = string([cBound.name ' T1_mean: ' sprintf('%.1f', mean(tabDat.getT1Img.data(cBound.various.pxlNrT1Img)))]);
%                 end
                
            end
            
        end
        
        % % % GUI Interaction % % %
        function tabDat = tableEdit(tabDat, select)
            switch select.Source.ColumnName{select.Indices(2)}
                case ''
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
                                    tabDat.segmentDone = 0;
                                end
                                
                        end
                    end
                case cfgDM.key.ShowFit
                    tabDat.showFitInFitTool(d);
                case cfgDM.key.FitData
                    % start fitting ...
                    tabDat = tabDat.calcRoiAveraged(d);
                    %tabDat = d.dat;
                    d.updateTable;
                case cfgDM.key.nextImage
                    if cfgDM.imageNr < numel(tabDat.imgs)
                    cfgDM.imageNr = cfgDM.imageNr + 1;
                    end
                case cfgDM.key.previousImage
                    if cfgDM.imageNr > 1
                    cfgDM.imageNr = cfgDM.imageNr - 1;
                    end
            end
            d.cfgDM = cfgDM;
        end
        
        function keyRelease(tabDat, d, key)
            d.handles.figure.WindowKeyPressFcn = @d.keyPress;
            %
            cfgDM = d.cfgDM;
            cfgMM = d.cfgMM;
            key = key.Key;
            switch key
                case cfgDM.contour.keyAssociation  % normal grayed out contour display
                    tabDat.selectedBound = cfgDM.contour.names(find(ismember(cfgDM.contour.keyAssociation, key)));
                    cBound = tabDat.Boundaries.getBoundOfType(tabDat.selectedBound);
                    if ~isempty(cBound.coord)
                        if isfield(d.handles, 'boundInfoFig') && ishandle(d.handles.boundInfoFig)
                            scale = size(tabDat.imgs(1).data)./size(tabDat.getT1Img.data);
                            imgDisplay = getimage(d.handles.imgAxis);
                            cBound = tabDat.Boundaries.getBoundOfType(tabDat.selectedBound);
                            boundMask = tabDat.getBoundMask(imgDisplay, cBound.coord);
                            boundMask = imresize(boundMask, 1/scale(1), 'nearest');
                            boundData = tabDat.getT1Img.data(find(boundMask));
                            %boundData = imgDisplay(find(boundMask));
                            
                            delete(d.handles.boundInfoAxis.Children);
                            axes(d.handles.boundInfoAxis);
                            h = histfit(boundData, ceil(sqrt(numel(boundData))), 'normal');
                            h(1).FaceColor = cfgMM.apperance.color3;
                            h(2).Color = cfgDM.contour.colors{find(ismember(cfgDM.contour.names, cBound.name))};
                            d.handles.boundInfoAxis.XAxis.TickValues = [];
                            d.handles.boundInfoAxis.YAxis.TickValues = [];
                            
                            %fill text box
                            [Lh Lp] = lillietest(boundData);
                            [Kh Kp] = kstest((boundData-mean(boundData))/std(boundData));
                            boxString = {};
                            boxString{1} = ['Pixel Count: ' num2str(numel(boundData), '%10.0u')];
                            boxString{end+1} = ['Pixel Stdev: ' num2str(std(boundData)  , '%10.2f')];
                            boxString{end+1} = ['Pixel minT1: ' num2str(min(boundData)  , '%10.2f')];
                            boxString{end+1} = ['Pixel maxT1: ' num2str(max(boundData)  , '%10.2f')];
                            boxString{end+1} = ['Pixel medianT1: ' num2str(median(boundData), '%10.2f')];
                            boxString{end+1} = ['Pixel meanT1: ' num2str(mean(boundData), '%10.2f')];
                            %boxString{end+1} = ['Pixel 95 perc: ' num2str(mean(boundData), '%10.2f')];
                            boxString{end+1} = ['is not Normal (Lilli): ' num2str(Lp, '%10.5f')];
                            boxString{end+1} = ['is not Normal (ks): ' num2str(Kp, '%10.5f')];
                            
                            
                            
                            d.handles.boundInfoBox.String = boxString;
                            axes(d.handles.imgAxis);
                        else
                        end
                    end
                    
                case cfgDM.key.DeleteContour
                case cfgDM.key.ShowFit
                case cfgDM.key.FitData
                case cfgDM.key.nextImage
                case cfgDM.key.previousImage
            end
            d.cfgDM = cfgDM;
            %
            
            
            
            d.handles.imgDisplay.AlphaData = 1;
            d.tableCellSelect;
        end
        
        function imgAxisButtonDown(tabDat, d, hit)
            if isempty(d.activeKey)
                newC = [d.handles.imgAxis.CurrentPoint(1,2) d.handles.imgAxis.CurrentPoint(1,1)]; newC = uint16(round(newC));
                newC = fliplr( hit.IntersectionPoint(1:2)); newC = uint16(round(newC));
                if isfield(d.handles, 'pxlInfoFig') && ishandle(d.handles.pxlInfoFig)
                else
                    d.handles.pxlInfoFig = figure('units','pixels', 'position',[140 180 240 240], 'menubar','none', 'resize','off', 'numbertitle','off', 'name','Pixel Info');
                    d.handles.pxlInfoBox = uicontrol('style','edit', 'units','pix', 'position',[10 10 220 220], 'backgroundcolor','w', 'HorizontalAlign','left', 'min',0,'max',10, 'enable','inactive');
                end
                scale = size(tabDat.imgs(1).data)./size(tabDat.getT1Img.data);
                imgDisplay = getimage(d.handles.imgAxis);
                pxlInd = sub2ind(size(imgDisplay), newC(1), newC(2));
                boxString = {};
                boxString{1} = ['Pixel Number: ' num2str(newC(1), '%10.0u') ', ' num2str(newC(2), '%10.0u') ' (id: ' num2str(pxlInd, '%10.0u') ')'];
                boxString{end+1} = ['Pixel Value: ' num2str(imgDisplay(pxlInd), '%10.0u')];
                % START mode specific:
                newC = [floor(newC(1)/scale(1)), floor(newC(2)/scale(1))];
                ind = sub2ind(size(tabDat.getT1Img.data), newC(1), newC(2));
                PxlData = tabDat.PxlData;
                
                boxString{end+1} = ['R_Square: ' num2str(PxlData.rsquare(ind), '%10.2f')];
                boxString{end+1} = ['RMSE: ' num2str(PxlData.rmse(ind), '%10.2f')];
                for i=1:numel(PxlData.parameters)
                    boxString{end+1} = [PxlData.parameters{i} ': ' num2str(PxlData.values{ind}(i), '%10.2f')];
                    
                end
                if ~PxlData.fitOk(ind); boxString{end+1} = ['BAD FIT because: ' PxlData.badFitReason{ind}]; end
                % END mode specific!
                
                d.handles.pxlInfoBox.String = boxString;
                
                
            else
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
        
        function d = genBoundInfoFig(tabDat, d)
            d.handles.boundInfoFig = figure('units','pixels', 'position',[140 400 640 240], 'menubar','none', 'resize','off', 'numbertitle','off', 'name','Pixel Info');
            d.handles.boundInfoBox = uicontrol('style','edit', 'units','pix', 'position',[410 10 220 220], 'backgroundcolor','w', 'HorizontalAlign','left', 'min',0,'max',10, 'enable','inactive');
            d.handles.boundInfoAxis = axes('units','pixels','position',[10 10 380 220],'box','on');
            d.handles.boundInfoAxis.XAxis.TickValues = [];
            d.handles.boundInfoAxis.YAxis.TickValues = [];
            
        end
        
        % % % Segmentaion Organisation % % %
        function d = importNikitaBound(tabDat, d)
            % import only roi data from old Nikita tool < 2016
            mb = msgbox('klick OK to load an old Nikita mat file <2016 with Bound data to be imported.');
            waitfor(mb);
            [file folder] = uigetfile(fullfile(d.cfgDM.lastLoadPath, '*.mat'));
            load(fullfile(folder, file), 'ROIs');
            names = d.cfgDM.contour.names;
            [ind b] = listdlg('PromptString', 'where to insert Roi:', 'SelectionMode', 'single', 'ListString', names);
            name = names(ind);
            for i = 1:numel(ROIs(1,1,:))
                cBoundIn = tabDat(i).Boundaries.empty;
                cBoundIn(1).name = name{1};
                cBoundIn.coord = bwboundaries(ROIs(:,:,i));
                cBoundIn.coord = cBoundIn.coord{1};
                
                cBounds = tabDat(i).Boundaries;
                cBounds = setBound(cBounds, cBoundIn);
                
                tabDat(i).Boundaries = cBounds;
                
            end
            
            d.dat = tabDat;
            d.tableCellSelect;
        end
        
        % % % Image Management % % %
        function img = getT1Img(tabDat)
            if numel(tabDat)>1
                msgbox('to many tabDat objects in getT1Img method');
                return
            end
            img = imgFat;
            ind = find(ismember(tabDat.PxlData.cFitObj.getCoeffNames, 'T1'));
            paramCount = numel(tabDat.PxlData.cFitObj.getCoeffNames);
            
            s = size(tabDat.PxlData.values);
            valueData = cell2mat(tabDat.PxlData.values);
            img.data = valueData(1:1:end, ind:3:end);
            
            %img.data = cell2mat(arrayfun(@(x) x{1}(1), tabDat.PxlData.values, 'un', false));
            img.name = tabDat.imgs(1).name;
            img.imgType = 'T1Map';
        end
        
        function mask = getFitOkMask(tabDat)
            if numel(tabDat)>1
                msgbox('to many tabDat objects in getT1Img method');
                return
            end
            mask = logical(zeros(size(tabDat.imgs(1).data)));
            
            values = logical(cell2mat(tabDat.PxlData.fitOk));
            indizes = tabDat.PxlData.pxlNr;
            
            mask(indizes) = values;
        end
        
        function R2Img = getR2Img(tabDat)
            if numel(tabDat)>1
                msgbox('to many tabDat objects in getT1Img method');
                return
            end
            R2Img = zeros(size(tabDat.imgs(1).data));
            
            values = tabDat.PxlData.rsquare;
            indizes = tabDat.PxlData.pxlNr;
            
            R2Img(indizes) = values;
        end
        
        % % % Fit Management % % %
        function ftype = makeStandardFtype(tabDat)
            
            % set fit parameters and fcn
            fitOptions = fitoptions('Method','NonlinearLeastSquares', ...
                'Lower', [180, 1, 0 ], ...
                'Upper', [4000, Inf, 100 ], ...
                'Startpoint', [400 200 10]);
            % [T1 S0 Cn]
            
            fitFcn = ['sqrt((S0*(1-2*exp(-TI/T1)+exp(-2500/T1)))^2+Cn^2)'];
            
            ftype=fittype(fitFcn,...
                'coefficients',{'T1','S0','Cn'},'independent', 'TI',...
                'options',fitOptions);
                        
            ftype = ftype;
        end
        
        function tabDat = fitAllPxls(tabDat,d)
            if numel(tabDat)==1
                tabDatInd = 1;
            else
                tabDatInd = d.tableRow;
            end
            scale = 1.0;
            ctabDat = tabDat(tabDatInd);
            imgs = ctabDat.imgs;
            mask = ones(size(imgs(1).dataResize(scale)));
            imgSize = size(mask);
            PxlData = ctabDat.PxlData;
            
            if numel(PxlData)~=0 && numel(PxlData.pxlNr)>0
                b = questdlg([num2str(numel(PxlData.pxlNr)) 'pixels are already fitted!'], 'Fit Warning', 'Abord', 'Overwrite', 'Abord')
                switch b
                    case 'Abord'
                        return
                    case 'Overwrite'
                end
            end
            % prepare fit data
            % xData:
            TI = arrayfun(@(x) x.dicomInfo(1).InversionTime, imgs)';
            PxlNr = find(mask);
            
            % prepare images
            imgsData = arrayfun(@(x) x.dataResize(scale), imgs, 'un', false);
            
            PxlData(1).cFitObj = rsFitObj;
            PxlData.cFitObj.xData = double(TI);
            PxlData.cFitObj.ftype = ctabDat.makeStandardFtype;
            
%             PxlData.pxlNr = PxlNr;
%             PxlData.pxlFit = repmat(rsFitObj, numel(PxlNr),1);
            % now go through every pixel and fit it
            wb = waitbar(0, 'processing single pixel fits');
            for Nr = PxlNr'
                
                [x, y] = ind2sub(imgSize, Nr);
                waitbar(Nr/numel(PxlNr), wb, ['processing single pixel fits: ' num2str(Nr/numel(PxlNr)*100) '%']);
                wb.Name = [ctabDat.patientName ' image ' num2str(tabDatInd)];
                % yData:
                yData = cellfun(@(x) x(Nr), imgsData);
                % PxlData
                PxlData.pxlNr(Nr) = Nr;
                PxlData.cFitObj.yData = double(yData');
                % fit Data
                PxlData.cFitObj = PxlData.cFitObj.fitIt;
                % is fit good?
                [fitOk reason] =  PxlData.cFitObj.checkFit;
                % store data
                PxlData.values{x, y} = PxlData.cFitObj.values;
                PxlData.fitOk(x, y) = fitOk;
                PxlData.badFitReason{x, y} = reason;
                PxlData.rsquare(x, y) = PxlData.cFitObj.gof.rsquare;
                PxlData.rmse(x, y) = PxlData.cFitObj.gof.rmse;
                
            end
            close(wb);
            PxlData.parameters = PxlData.cFitObj.parameters;
            ctabDat.PxlData = PxlData;
            tabDat(tabDatInd) = ctabDat;
        end
        
        function tabDat = calcSinglePxls(tabDat,d)
            if numel(tabDat)==1
                tabDatInd = 1;
            else
                tabDatInd = d.tableRow;
            end
            ctabDat = tabDat(tabDatInd);
            imgs = ctabDat.imgs;
            %% do the pxls for a single Boundary
            % prepare BoundData
            cBoundInd = ctabDat.Boundaries.getBoundInd(ctabDat.selectedBound);
            cBound = ctabDat.Boundaries(cBoundInd);
            cBoundData = ctabDat.BoundData(1);  % one BoundData array element per boundary
            cBoundData.pxlNr = [];
            cBoundData.pxlData = rsFitObj.empty;
            if isempty(cBound.coord)
            else
                %% prepare fit data
                % xData:
                TI = arrayfun(@(x) x.dicomInfo(1).InversionTime, imgs)';
                % yData:
                mask = tabDat.getBoundMask(imgs(1).data, cBound.coord);
                maskInd = find(mask);
                
                % now go through every pixel and fit it
                wb = waitbar(0, 'processing single pixel fits');
                for j = 1:numel(maskInd)
                    waitbar(j/numel(maskInd));
                    % yData:
                    yData = arrayfun(@(x) x.data(maskInd(j)), imgs, 'un', false);
                    yData = cell2mat(yData);
                    % write in cBoundData
                    cBoundData.pxlNr(j) = maskInd(j);
                    cBoundData.pxlData(j) = rsFitObj;
                    cBoundData.pxlData(j).xData = double(TI);
                    cBoundData.pxlData(j).yData = double(yData');
                    cBoundData.pxlData(j).ftype = ctabDat.makeStandardFtype;
                    
                    %% fit Data
                    cBoundData.pxlData(j) = cBoundData.pxlData(j).fitIt;
                    
                end
                close(wb);
            end
            
            %% result comment
            rsquare = arrayfun(@(x) x.gof.rsquare, cBoundData.pxlData)';
            th = 0.8;
            uiwait(msgbox(['Fit Done: ' num2str(sum(rsquare<th)) ' of ' num2str(numel(rsquare)) ' fits have a R² of less than ' num2str(th)]));
            
            ctabDat.BoundData(cBoundInd) = cBoundData;
            tabDat(tabDatInd) = ctabDat;
            
            
        end
        
        function tabDat = calcRoiAveraged(tabDat,d)
            if numel(tabDat)==1
                tabDatInd = 1;
            else
                tabDatInd = d.tableRow;
            end
            ctabDat = tabDat(tabDatInd);
            imgs = ctabDat.imgs;
            PxlData = ctabDat.PxlData;
            
            for i = 1:numel(ctabDat.Boundaries) % run through Boundaries
                %% calc mean fit values
                if isempty(ctabDat.Boundaries(i).coord)
                else
                    %% prepare fitType
                    cBound = ctabDat.Boundaries(i);
                    cBound.FitObj.ftype = ctabDat.makeStandardFtype;
                    %% prepare fit data
                    % xData: TI inversion times
                    cBound.FitObj.xData = arrayfun(@(x) x.dicomInfo(1).InversionTime, imgs)';
                    % yData: intensities
                    mask = tabDat.getBoundMask(imgs(1).data, cBound.coord);
                    pxlInd = find(mask);
                    yData = arrayfun(@(x) mean(x.data(pxlInd)), imgs, 'un', false);
                    cBound.FitObj.yData = cell2mat(yData');
                    
                    %% fit Data
                    cBound.FitObj = cBound.FitObj.fitIt;
                    
                    %% test fit quality
                    if cBound.FitObj.gof.rsquare<0.8
                        uiwait(msgbox([cBound.name ' quality of fit to low (R^2 = ' num2str(cBound.FitObj.gof.rsquare,2) ')'], 'FIT Error'));
                        
                    end
                end
                
                %% calc average value from existing T1 values
                scale = size(imgs(1).data)./size(ctabDat.getT1Img.data);
                maskScaled = imresize(mask, 1/max(scale));
                pxlInd = find(maskScaled);
                T1Inds = find(ismember(PxlData.pxlNr, pxlInd));
                cBound.various.pxlNrT1Img = T1Inds;
                cBound.various.T1 = median(ctabDat.getT1Img.data(T1Inds));
                
                
                ctabDat.Boundaries(i) = cBound;
            end
            
            ctabDat.segmentDone = 2;
            tabDat(tabDatInd) = ctabDat;
            %d.dat(d.tableRow) = tabDat(ind);
        end
        
        % % % Experimental % % %
        function d = saveRoiResults(tabDat,d)
            imgDisplay = getimage(d.handles.imgAxis);
            %d.tabDat.getStandardFileName
            [file, path] = uiputfile(fullfile(d.cfgDM.lastLoadPath, [d.getSaveFilePrefix '_data.xls']), 'save xls file');
            if file==0
                return
            end
            count = 0;
            wb = waitbar(0, 'Saving XLS file');
            wb.Name = 'saving....';
            % go through tabDats
            for i = 1:numel(tabDat)
                ctabDat = tabDat(i);
                cPxlData = ctabDat.PxlData;
                cT1Img = ctabDat.getT1Img;
                % got through Boundaries
                for j = 1:numel(ctabDat.Boundaries)
                    count = count+1;
                    waitbar(count/numel([tabDat.Boundaries]) , wb);
                    s = struct();
                    cBound = ctabDat.Boundaries(j);
                    boundMask = ctabDat.getBoundMask(imgDisplay, cBound.coord);
                    T1times = cT1Img.data(find(boundMask));
                    
                    [Lh Lp] = lillietest(T1times);
                    [Kh Kp] = kstest((T1times-mean(T1times))/std(T1times));
                    
                    % create table variables
                    PxlInd = find(boundMask);
                    dicomInfo = ctabDat.imgs(1).dicomInfo;
                    hfit = fitdist(T1times, 'Normal');
                    s.BoundName = cBound.name;
                    s.SliceLoc = dicomInfo.SliceLocation;
                    s.Patient = ctabDat.patientName;
                    s.AquDate = dicomInfo.AcquisitionDate;
                    s.PxlCount = numel(T1times);
                    try 
                        s.T1_mean_ofIntensities = cBound.FitObj.values(1); 
                    catch
                        s.T1_mean_ofIntensities = NaN;
                    end
                    s.T1_mean_ofFits = mean(T1times);
                    s.T1_median_ofFits = median(T1times);
                    s.T1_stdAbweichung = std(T1times);
                    s.T1_mean_Ci_95 = 0.95*std(T1times)/sqrt(numel(T1times));
                    s.T1_interQuartileRange = hfit.iqr;
                    s.T1_max = max(T1times);
                    s.T1_min = min(T1times);
                    s.T1_Lilli_isNormal = ~logical(Lh);
                    s.T1_Lilli_pValue = Lp;
                    s.T1_KS_isNormal = ~logical(Kh);
                    s.T1_KS_pValue = Kp;
                    
                    % write to disk
                    sheetName = ['S' num2str(i) '_' s.BoundName];
                    writetable(table(PxlInd, T1times), fullfile(path, file), 'Sheet', sheetName);
                    writetable(struct2table(s), fullfile(path, file), 'Sheet', sheetName,'Range', 'F1');
                    
                    
                end % end Boundaries
                
            end % end tabDats
            close(wb);
%             imgDisplay = getimage(d.handles.imgAxis);
%             scale = size(ctabDat.imgs(1).data)./size(ctabDat.getT1Img.data);
%             boundMask = ctabDat.getBoundMask(imgDisplay, cBound.coord);
%             boundMask = imresize(boundMask, 1/scale(1), 'nearest');
%             boundData = ctabDat.getT1Img.data(find(boundMask));
            
            
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
            dicomInfo = tabDat(1).imgs(1).dicomInfo;
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
            
            
            %% create data structre for xls storage
            s = struct();
            for i = 1:numel(tabDat) % i is for slice
                ctabDat = tabDat(i);
                count = 0;
                s(i).SliceNr = num2str(i,1);
                s(i).SlicePos = str2num(ctabDat.sliceLocation);
                for j = 1:numel(ctabDat.Boundaries)
                    cBound = ctabDat.Boundaries(j);
                    try
                    for k = 1:numel(cBound.FitObj.parameters)
                        s(i).([cBound.name '_' cBound.FitObj.parameters{k}]) = cBound.FitObj.values(k);   
                        s(i).([cBound.name '_Rsquare']) = cBound.FitObj.gof.rsquare;
                    end
                    end
                end
            end
            
            %% write to xls sheet (use all available data)
            writetable(struct2table(info), xlsPath, 'Sheet', 'infos');
            writetable(struct2table(s), xlsPath, 'Sheet', 'allData');
            
%             %% write to xls sheet (xls file like <nikita 2016)
%             Pos = 1;
%             xlswrite(xlsPath, {info.patientName} , 'Seg1', 'A1');
%             xlswrite(xlsPath, {info.creationDate} , 'Seg1', 'A2');
%             xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SegVol [cm^3]' 'Fat [%]'} , 'FAT', 'A3');
%             xlswrite(xlsPath, s.sliceNr', 'FAT', 'A4');
%             xlswrite(xlsPath, s.sliceLoc', 'FAT', 'B4');
%             xlswrite(xlsPath, [0 diff(s.sliceLoc)]', 'FAT', 'C4');
%             xlswrite(xlsPath, round(s.Seg1Vol,2)', 'FAT', 'D4');
%             xlswrite(xlsPath, round(s.FatFraction,2)', 'FAT', 'E4');
%             Pos = 3+numel(s.Seg1Vol)+1;
%             xlswrite(xlsPath, {'Slice #' 'Slice Pos (S)' 'Slice Gap' 'SegVol [cm^3]' 'Fat [%]'} , 'FAT', ['A' num2str(Pos)]);
%             Pos = Pos+2;
%             xlswrite(xlsPath, {'Summe'}, 'FAT', ['A' num2str(Pos)]);
%             xlswrite(xlsPath, round(sum(s.Seg1Vol),2), 'FAT', ['D' num2str(Pos)]);
%             xlswrite(xlsPath, round(sum(s.FatFraction),2), 'FAT', ['E' num2str(Pos)]);
            
            
        end
        
        % % % Object Management % % %
        function tabDat = updatetabDatT1RelaxFitMRoi(tabDat, data, saveDate)
            % here each slice gets implemented in the current tabDat and
            % T1RelaxFitMRoi structure
            for i = 1:numel(data)
                tabDat(i) = tabDatT1RelaxFitMRoi;  % object
                cTabDat = data(i);  % simple variable (struct)
                switch cTabDat.version_tabDatT1RelaxFitMRoi
                    case '0.1'
                        
                        if ~isempty([cTabDat.BoundData.xData])
                            cTabDat.Boundaries = boundaryFit;
                            cTabDat.Boundaries.coord = cTabDat.BoundData.coord;
                            cTabDat.Boundaries.name = cTabDat.BoundData.name;
                            try cTabDat.Boundaries.name = cTabDat.Boundaries.name{1}; end
                            cTabDat.Boundaries.FitObj = rsFitObj;
                        else
                            cTabDat.Boundaries = boundaryFit.empty;
                        end
                        cTabDat.PxlData = tabDat.PxlData;
                        cTabDat.selectedBound = '';
                        cTabDat.Various = {};
                        try cTabDat.BoundData = tabDat.BoundData; end
                        cTabDat.version_tabDatT1RelaxFitMRoi = '0.9';
                        
                        for f = fieldnames(tabDat(i))'
                            f = f{1};
                            tabDat(i).(f) = cTabDat.(f);
                        end
                        % take care about cfgversion!!?!!?!!?!!
                        sc = superclasses(class(tabDat(i)));
                        tabDat(i) = tabDat(i).(['update' sc{1}]);
                    case '0.9'
                        cTabDat.Boundaries = boundaryFit;
                        cTabDat.Boundaries.coord = cTabDat.BoundData.coord;
                        cTabDat.Boundaries.name = cTabDat.BoundData.name;
                        try cTabDat.Boundaries.name = cTabDat.Boundaries.name{1}; end
                        cTabDat.Boundaries.FitObj = rsFitObj;
                        cTabDat.PxlData = tabDat.PxlData;
                        cTabDat.selectedBound = '';
                        cTabDat.Various = {};
                        try cTabDat.BoundData = tabDat.BoundData; end
                        cTabDat.version_tabDatT1RelaxFitMRoi = '1.0';

                        for f = fieldnames(tabDat(i))'
                            f = f{1};
                            tabDat(i).(f) = cTabDat.(f);
                        end
                        % take care about cfgversion!!?!!?!!?!!
                        sc = superclasses(class(tabDat(i)));
                        tabDat(i) = tabDat(i).(['update' sc{1}]);
                        
                    case '1.0'
                        cTabDat = rmfield(cTabDat, 'BoundData');
                        cTabDat.PxlData = tabDat(i).PxlData;
                        cTabDat.version_tabDatT1RelaxFitMRoi = '1.1';
                        
                        for f = fieldnames(tabDat(i))'
                            f = f{1};
                            tabDat(i).(f) = cTabDat.(f);
                        end
                        % take care about cfgversion!!?!!?!!?!!
                        sc = superclasses(class(tabDat(i)));
                        tabDat(i) = tabDat(i).(['update' sc{1}]);
                        
                    case {'1.1' '1.2'}
                        for f = fieldnames(tabDat(i))'
                            f = f{1};
                            tabDat(i).(f) = cTabDat.(f);
                        end
                        % take care about cfgversion!!?!!?!!?!!
                        sc = superclasses(class(tabDat(i)));
                        tabDat(i) = tabDat(i).(['update' sc{1}]);
                    otherwise
                        msgbox('tabDatT1RelaxFitMRoi version problem in tabDatT1RelaxFitMRoi_updateFcn!');
                end
            end
            
        end
        
        function tabDat = tabDatT1RelaxFitMRoi(tabArray)
            
        end
    end
end

