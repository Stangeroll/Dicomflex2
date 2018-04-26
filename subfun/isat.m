% ISAT - ImageStackAnalysisTool

classdef isat < handle
    
    properties
        versionIsat = '1.1';
        mode = '';
        handles = struct('draw', []);
        dat = [];   % contains an array of cCompute objects
        tableRow = 1;   % current selected row
        tableColumn = 1;    % current selected column
        
        cfgMM = struct([]); % frameworkConfig
        cfgMMpath = '';
        cfgDM = struct([]); % applicationConfig
        cfgDMpath = '';
        
        lineCoord = []; % coordinates drawn by mouse and temporarily stored for processing in cCompute
        history = struct('data', {{'emptySlot'}});   % used to store history ---- not implemented!! 
        
        activeKey = {}; % press and hold a key will be stored here
        activeMouse = '';
        saveDate = datetime.empty;  % last data file save time stamp
        versions = struct('name', '', 'ver', '', 'updateFcn', '');  % struct with all relevant classes, objects and there current version
        Various = {};
        
    end
    
    methods(Static)
        function h = drawContour(imgAxis, contCoord, contColor)
            % draws a set of contour coordinates (contCoord) into an image
            % (imgAxis) with the colors (contColor)
            % imgAxis       - handle to an axis
            % contCoord     - cell array containing an 2xN array per cell
            % as x, y coordinates
            % contColor     - cell array containing a color specifier per
            % array element
            h = []; % pre allocated, in case all contCoords are empty and h will not be assigned
            
            if isvalid(imgAxis)
                axes(imgAxis); hold on;
            else
                msgbox('no valid handle for plotting contours');
                return;
            end
            
            for i = 1:numel(contCoord)
                c = contCoord{i};
                if ~isempty(c)
                    c = c{1};
                    if ~isempty(c)
                    h{i} = line(c(:,2), c(:,1), 'Color', contColor{i}, 'LineWidth', 2);
                    h{i}.ButtonDownFcn = imgAxis.ButtonDownFcn;
                    h{i}.HitTest = 'on';
                    end
                end
            end
            hold off;
            
        end
    end
    
    methods
        function dummy(d)
            disp('test dummy');
        end
        
        function d = setVersionInfo(d, name, ver, updateFcn)
            % overwrites existing version info or creates new entry
            ind = ismember({d.versions.name}, {name});
            if any(ind)
                d.versions(ind).ver = ver;
                d.versions(ind).updateFcn = updateFcn;
            else
                d.versions(end+1).name = name;
                d.versions(end).ver = ver;
                d.versions(end).updateFcn = updateFcn;
            end
        end
        
        function prefix = getSaveFilePrefix(d)
            prefix = [d.dat(1).patientName '_' d.dat(1).imgs(1).dicomInfo.AcquisitionDate '_' datestr(now, 'yymmdd_HHMM') '_' d.mode];
        end
        
        function histData = generateHistData(d)
            histData = struct(d);
            histData.dat = setStructArrayField(histData.dat, 'imgs', {});
            histData.dat = setStructArrayField(histData.dat, 'history', {});
            histData = rmfield(histData, 'history');
            histData = rmfield(histData, 'tableRow');
            histData = rmfield(histData, 'tableColumn');
            histData = rmfield(histData, 'handles');
            histData = rmfield(histData, 'versionIsat');
            histData = rmfield(histData, 'mode');
            histData = rmfield(histData, 'cfgMM');
            histData = rmfield(histData, 'cfgDM');
            histData = rmfield(histData, 'cfgMMpath');
            histData = rmfield(histData, 'cfgDMpath');
            histData = rmfield(histData, 'activeKey');
            histData = rmfield(histData, 'activeMouse');
            histData = rmfield(histData, 'versions');
            try histData = rmfield(histData, 'PreviousInstance__'); end
        end
        
        function d = makeUndo(d, varargin)
%             [a b c] = comp_struct(d.history.data{1}, d.history.data{2})
%             histData2 = d.generateHistData;
            % generate data
            histData = d.history.data{2};
            fields = fieldnames(histData);
            tabDat = d.dat;
            
            % overwrite fields from histdata to d
            for i=1:numel(fields)
                d.(fields{i}) = histData.(fields{i});
            end
            % write back images
            d.dat = setStructArrayField(d.dat, 'imgs', {tabDat.imgs});
            d.dat = setStructArrayField(d.dat, 'history', {tabDat.history});
            % delete newest histelement to assure more than one undo is
            % possible. Two must be deletet, because tableCellSelect will
            % generatre a new one
            d.history.data(1:2) = [];
            
            d.tableCellSelect;
        end
        
        % % % Keyboard and Mouse Input processing % % %
        function histAxisButtonDown(d, a, hit, varargin)
            d.dat(d.tableRow).histAxisButtonDown(d, hit); % execute function associated in tabDat class
        end
        
        function imgAxisButtonDown(d, a, hit, varargin)
            d.dat(d.tableRow).imgAxisButtonDown(d, hit); % execute function associated in tabDat class
        end
        
        function mouseWheel(d, a, b, varargin)
            max = numel(d.dat);
            min = 1;
            new = d.tableRow+b.VerticalScrollCount;
            if new<min
                new = min;
            elseif new>max
                new = max;
            end
            d.tableRow = new;
            d.tableCellSelect;
        end
        
        function keyPress(d, a, key)
            % key already pressed?
            if any(ismember(d.activeKey, {key.Key}));
                return
            end
            % add key to d.activeKey
            d.activeKey = [d.activeKey {key.Key}];
            % use key input
            switch key.Key
                case {'z'}   % here keys can be processed directly
                    switch d.activeKey{1}
                        case {'control'}
                            d = d.makeUndo;
                    end
                otherwise   % here keys are processed in the cCompute class
                    d.dat(d.tableRow) = d.dat(d.tableRow).keyPress(d, key); % execute function associated in cCompute class
            end
            d.activeKey
        end
        
        function keyRelease(d, a, key)
            % remove key from d.activeKey
            keyInd = ismember(d.activeKey, {key.Key});
            d.activeKey(keyInd) = [];
            switch key.Character
                case {''}   % here keys can be processed directly
                otherwise   % here keys are processed in the cCompute class
                    d.dat(d.tableRow).keyRelease(d, key); % execute function associated in cCompute class
            end
            d.activeKey
        end
        
        % % % ProgramMenue interaction % % %
        function menuCallback(d, fcn, varargin)
            try
                tmp = feval(fcn); % execute the function coming from the menu button callback stored in applicationConfig
            catch
                msgbox([char(fcn) ' could not be excecuted!']);
            end
            if exist('tmp') == 1
                if isa(tmp, 'isat')
                    d = tmp;
                    d.tableCellSelect;
                else % must be cCompute
                    d.dat = tmp;
                    d.tableCellSelect;
                end
            end
        end
        
        function imageDisplayMode(d, b, varargin)
            % change the current mode of displaying images as stored in
            % applicationConfig
            tmp = arrayfun(@(x) x{1} , d.cfgDM.menu);
            callbackEntries = arrayfun(@(x) x.path{end}, tmp, 'un', false);
            menuSelection = d.cfgDM.menu{find(ismember(callbackEntries, b.Label))};
            d.cfgDM.imageDisplayMode = menuSelection.path{end};
            d = d.dat.plotIt(d);
        end
        
        function saveData(d, varargin)
            wb = waitbar(0.1, 'Data.mat file is beein saved.');
            wb.Name = 'saving....';
            path = fullfile(d.cfgDM.lastLoadPath, [d.getSaveFilePrefix '_data.mat']);
            d.dat.saveTabDat(path, d);
            % execute application specific saving:
            waitbar(0.3, wb, 'Application specific saving has started');
            Fcns = d.cfgDM.saveDatFcn;
            for i = 1:numel(Fcns)
                eval(Fcns{i});
            end
            d.saveDate = datetime('now');
            waitbar(1, wb, 'Done');
            wb.Name = 'Done';
            pause(0.35);
            close(wb);
            
        end
        
        function loadData(d, varargin)
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            % find data
            imgLoad = [];
            patDir = uigetdir(cfgDM.lastLoadPath, 'select folder'); % user select dataset
            if patDir==0
                return
            end
            % clear prior use of Dicomflex class
            d.dat = [];
            d.tableRow = 1;
            d.tableColumn = 1;
            d.versions(:) = [];  % delete initial entry;
            d.setVersionInfo(d.cfgMM.programName, d.versionIsat, '');
            
            % patDir is writable?
            [a, tmp] = fileattrib(patDir)
            if ~tmp.UserWrite
                msgbox('No write permission in data folder. DataSet cannot be saved!');
            end
            
            % read data
            cfgDM.lastLoadPath = patDir;
            d.cfgDM = cfgDM;
            d.dat = feval(str2func(cfgDM.tabDatFcn));
            d = d.dat.initTabDat(d);  % here data structure is created, images loaded and plotted
            
            % set figure name
            d.handles.figure.Name = [cfgMM.programName ' in ' cfgDM.dataMode ' mode - ' d.dat(1).dataName];
            
            % save config file
            savejson('',d.cfgDM, d.cfgDMpath);
            
            % fill table before plotting
            d.updateTable;
            
            % init image display
            if ishandle(d.handles.imgAxis)
                axes(d.handles.imgAxis); htmp = get(d.handles.imgAxis, 'Children');
                for i=1:numel(htmp)
                    delete(htmp(i));
                end
                
                d = d.dat.plotIt(d);
            end
            
            % fill table
            d.updateTable;
        end
        
        function cloneSoftware(d, varargin)
            clone = isat('mode', d.mode);
            clone.dat = d.dat;
            clone.tableRow = d.tableRow;
            clone.tableCellSelect;
        end
        
        % % % GUI interaction % % %
        function tableCellEdit(d, hTab, select, varargin)
            % transfer new value to dat struct
            d.dat(select.Indices(1)).(d.cfgDM.table.AssociatedFieldNames{select.Indices(2)}) = select.NewData;
            
            % execute function due to value change
            d.dat(select.Indices(1)) = d.dat(select.Indices(1)).tableEdit(select);
            d.tableCellSelect;
            
        end
        
        function tableCellSelect(d, varargin)
            tic
            d.history.data;
            % make history storage for undo
            histData = d.generateHistData;            
            if isequal(histData, d.history.data{1})
                % -> no change happened
            else
                histSize = 10;
                %[a b c] = comp_struct(histData, d.history.data{1})
                % make hist data the correct size (init)
                if numel(d.history.data)~=histSize
                    d.history.data(numel(d.history.data)+1:histSize) = {'emptySlot'};
                end
                % delete last element and shift all to end to make first place free
                shiftSet = d.history.data(1:histSize-1);
                d.history.data(1) = {histData}; % here the new stuff
                d.history.data(2:histSize) = shiftSet; % here the old stuff
            end
            
            if nargin==3
                select = varargin{2};
                select = select.Indices;
                if isempty(select)  % dirty, but i did not find another way (if table data gets updated -> cellselect callback -> arrrgg
                    return
                end
            elseif nargin==2
                select = [d.tableRow d.tableColumn];
            elseif nargin==1
                select = [d.tableRow d.tableColumn];
            end
            
            % if the cell is editable -> return    (this is a case for
            % @tableCellEdit
            if any(select(2)==find(d.cfgDM.table.ColumnEditable))
                return
            end
            disp('tableCellSelect');
            d.tableRow = select(1);
            d.tableColumn = select(2);
            
            d = d.dat.plotIt(d);
            
            d = d.dat.histIt(d);
            
            try d = d.dat.textIt(d); end
            
            d.updateTable;
            toc
        end
        
        function updateTable(d)
            % fill the table according to applicationConfig entries
            if ishandle(d.handles.table)
                columNames = d.cfgDM.table.ColumnName;
                fieldNames = d.cfgDM.table.AssociatedFieldNames;
                
                tabData = {};
                for i = 1:numel(d.dat)
                    singleRow = {};
                    for j = 1:numel(columNames)
                        singleRow{j} = d.dat(i).(fieldNames{j});
                    end
                    tabData(i,:) = singleRow;
                end
                d.handles.table.Data = tabData;
                d.handles.table.RowName = [1:numel(d.dat)];
            end
            
            % create savety copy
            if isempty(d.saveDate)
                d.dat.saveTabDat(fullfile(d.cfgDM.lastLoadPath, 'tmp_isat.mat'), d);
                d.saveDate = datetime('now');
                disp('data saved')
            elseif datetime('now')-d.saveDate > d.cfgMM.datAutoSaveTime
                d = d.dat.saveTabDat(fullfile(d.cfgDM.lastLoadPath, 'tmp_isat.mat'), d);
                d.saveDate = datetime('now');
                disp('data saved')
            end
        end
        
        % % % External Windows % % %
        function createZoomView(d, varargin)
            ctabDat = d.dat(d.tableRow);
            img = ctabDat.getImg2Display(d);
            
            if isfield(d.handles, 'zoomFig') && isvalid(d.handles.zoomFig)
                delete(d.handles.zoomFig);
            end
            d.handles.zoomFig = figure('units','pixels', 'menubar','none', 'resize','on', 'numbertitle','off', 'name','Zoom View');
            d.handles.zoomAxis = axes();
            d.handles.zoomDisplay = imshow(uint8(img.data), 'parent', d.handles.zoomAxis);
            %colormap(d.handles.zoomAxis, 'parula');
            d.handles.zoomRect = imrect(d.handles.zoomAxis);
            d.handles.zoomFig.CloseRequestFcn = @d.closeZoomView;
            d.handles.zoomRect.addNewPositionCallback(@d.tableCellSelect);
            d.tableCellSelect;
        end
        
        function closeZoomView(d, varargin)
            delete(varargin{1});
            rmfield(d.handles, 'zoomFig');
            rmfield(d.handles, 'zoomAxis');
            rmfield(d.handles, 'zoomDisplay');
            rmfield(d.handles, 'zoomRect');
            d.tableCellSelect;
        end
        
        % % % Program Start and GUI creation % % %
        function menuHandles = createMenu(d, s, parent)
            for i = 1:numel(s)
                sc = s{i};
                htmp = parent;
                h = htmp;
                
                % check how deep the menu already exists
                lvl = 0;
                while ~isempty(htmp)
                    lvl = lvl+1;
                    tmp = htmp.Children;
                    tmp = tmp(arrayfun(@(x) ismember(class(x), {'matlab.ui.container.Menu'}) , tmp));
                    htmp = tmp(arrayfun(@(x) ismember(x.Label, sc.path(lvl)) ,tmp));
                    if ~isempty(htmp)
                        h = htmp;
                    end
                end
                    
                
                % now create übrige menu entries
                for j = lvl:numel(sc.path)
                    sc.h(j) = uimenu(h, 'Label', sc.path{j});
                    h = sc.h(j);
                    if j==numel(sc.path)
                        sc.h(j).Callback = eval(sc.callback);
                    end
                end
                % store handle data
                menuHandles(i).source = s{i};
                menuHandles(i).handle = sc.h(end);
            end
            
            % obsolete version:
%             for i=1:numel(s.name)
%                 name = s.name{i};
%                 givenName = s.givenName{i};
%                 s.h(i) = uimenu(parent, 'Label', givenName);
%                 if ~isfield(s, name) % generate callback, because if true, its the last element in menu hirarchy
%                     cb = s.callBack{i};
%                     s.h(i).Callback = eval(cb);
%                 else
%                     s.(name) = d.createMenu(s.(name), s.h(i));
%                 end
%                 
%             end
        end
        
        function setGUI(varargin) % set gui object position and size
            % width of table is fix in size and is not allowed to be changed
            d = varargin{1};
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            h = d.handles;
            fSize = get(h.figure, 'position');
            fH = fSize(4); fW = fSize(3); % figure Height and Width
            if ishandle(h.table)
                tW = h.table.Position(3); % table Height and Width
            else
                tw = 0;
            end
            GS1 = cfgMM.GS1; % GapSize 1 in pxl
            GS2 = cfgMM.GS2; % GapSize 2 in pxl
            
            % possiton of Figure window
            % imgAxis at top left with y-offset for histogram
            histH = cfgDM.histAxis.height;    % histogram hight in percent
            imgH = cfgDM.imgAxis.height;    % image axis hight in percent
            
            if ~ishandle(h.imgAxis) % resize img Axis if visible and resize hist Axis only if img Axis is visible
            elseif ishandle(h.imgAxis)
                % from top left
                h.imgAxis.Position(1) = GS2;
                h.imgAxis.Position(3) = fW-tW-GS2-GS1;
                h.imgAxis.Position(4) = fH*imgH;
                h.imgAxis.Position(2) = fH - h.imgAxis.Position(4);
                
                if ishandle(h.histAxis)
                    % below the imgAxis
                    h.histAxis.Position(1) = GS2;
                    h.histAxis.Position(3) = h.imgAxis.Position(3);
                    h.histAxis.Position(4) = fH*histH-GS1-GS2;
                    h.histAxis.Position(2) = h.imgAxis.Position(2)-h.histAxis.Position(4)-GS2;
                end
            end
            
            
            % table at top right with fixed width and height tabH
            if ishandle(h.table)
                tabH = cfgDM.table.height; % table hight in percent
                
                h.table.Position(1) = fW-h.table.Position(3)-GS2;
                h.table.Position(4) = fH*tabH;
                h.table.Position(2) = fH-h.table.Position(4);
            end
            
            if ishandle(h.textBox)
                boxH = cfgDM.textBox.height;
                
                h.textBox.Position(1) = h.table.Position(1);
                h.textBox.Position(3) = h.table.Position(3);
                h.textBox.Position(4) = fH*boxH-GS1-GS2;
                h.textBox.Position(2) = GS1;
            end
            
        end
        
        function d = createGUI(d)   % Define Buttons, Axis,... and set callbacks, initValues,...
            d.handles.figure = figure;
            h = d.handles;
            h.figure.WindowKeyPressFcn = @d.keyPress;
            h.figure.WindowScrollWheelFcn = @d.mouseWheel;
            hf = h.figure;
            hf.CloseRequestFcn = @d.closeIsat;
            h.figure.Color = d.cfgMM.apperance.color1;
            
            cfgMM = d.cfgMM;
            cfgDM = d.cfgDM;
            % create all possible gui objects
            set(hf, 'ResizeFcn', @d.setGUI, 'MenuBar', 'none', 'ToolBar', 'none',...
                'NumberTitle', 'off', 'Name', [cfgMM.programName ' in ' cfgDM.dataMode ' mode']);
            
            if strcmp(cfgDM.imgAxis.visible, 'on')
                h.imgAxis = axes('parent', hf, 'Units', 'pixel',...
                    'Color', [0 0 0], 'XTick', [], 'YTick', []);
                h.imgAxis.ButtonDownFcn = @d.imgAxisButtonDown;
            else
                h.imgAxis = [];
            end
            
            if strcmp(cfgDM.histAxis.visible, 'on')
                h.histAxis = axes('parent', hf, 'Units', 'pixel',...
                    'Color', [0 0 0], 'YTick', []);
                h.histAxis.ButtonDownFcn = @d.histAxisButtonDown;
            else
                h.histAxis = [];
            end
            
            if strcmp(cfgDM.textBox.visible, 'on')
                h.textBox = uicontrol('parent', hf, 'Style', 'text');
                h.textBox.BackgroundColor = [1 1 1];
            else
                h.textBox = [];
            end
            
            % create menue entry
            s = [cfgMM.menu cfgDM.menu];
            h.menu = d.createMenu(s, hf);
            
            % create table for images and results
            if cfgDM.table.visible
                h.table = uitable(hf,...
                    'ColumnName', cfgDM.table.ColumnName,...
                    'ColumnFormat', cfgDM.table.ColumnFormat,...
                    'ColumnEditable', logical(cfgDM.table.ColumnEditable), ...
                    'RowName',[],...
                    'Visible', cfgDM.table.visible,...
                    'CellSelectionCallback', eval(cfgMM.table.CellSelectionCallback),...
                    'CellEditCallback', eval(cfgMM.table.CellEditCallback));
                h.table.ColumnWidth = num2cell(cfgDM.table.ColumnWidth);
                h.table.Position(3) = sum(cell2mat(h.table.ColumnWidth))+2+17+35;  % +17 for scrollbar +35 for rownames
            else
                h.table = [];
            end
            
            d.handles = h;
            
        end
        
        function d = isat(varargin)
            
            
            
            %% get program directory
            % determine .m or .exe directory
            if isdeployed
                progDir = getProgrammPath;
            else
                progDir = which('isat.m');
                progDir = fileparts(progDir);
            end
            %% load master mode cfg file
            cfgMMdir = dir(fullfile(progDir, 'cfg_isatMasterMode.json'));
            d.cfgMMpath = fullfile(cfgMMdir.folder, cfgMMdir.name);
            d.cfgMM = loadjson(d.cfgMMpath);
            %% load data mode cfg file
            cfgDMdir = dir(fullfile(progDir, 'cfg_*_isatDataMode.json'));
            for i = 1:numel(cfgDMdir)
                tmp = strsplit(cfgDMdir(i).name, {'cfg_' '_isatDataMode.json'});
                availableModes(i) = tmp(2);
            end
            
            %% select mode
            if ~isempty(varargin) && isa(varargin{1}, 'char')
                switch varargin{1}
                    case 'mode'
                        Ind = find(ismember(availableModes, varargin{2}));
                end
            else
                Ind = listdlg('PromptString',{'Please select the program mode:'},...
                    'SelectionMode','single', 'ListString', availableModes,...
                    'ListSize', [200 150], 'OKString', 'Select Mode', 'CancelString', 'Abord');
                
                if isempty(Ind)
                    return
                end
            end
            
            d.cfgDMpath = fullfile(cfgDMdir(Ind).folder, cfgDMdir(Ind).name);
            d.cfgDM = loadjson(d.cfgDMpath);
            
            d.mode = d.cfgDM.dataMode;
            %% check for write permission of cfg files
            [a, tmp1] = fileattrib(d.cfgMMpath)
            [a, tmp2] = fileattrib(d.cfgDMpath)
            if ~tmp1.UserWrite | ~tmp2.UserWrite
                msgbox('No write permission for CfgFile. Programm will not operate properly!');
            end
            
            %% create and fill front end
            d.createGUI;
            d.setGUI;
        end
        
        function d = closeIsat(d, varargin)
            if isempty(d.dat)
            else
                b = questdlg('Save before Exit?', 'saveData yes/no', 'yes', 'no', 'abord', 'yes');
                switch b
                    case 'yes'
                        d.saveData;
                    case 'no'
                    case 'abord'
                        return
                end
                %eval(d.cfgDM.closeRequest);
            end
            if isempty(gcbf)
                if length(dbstack) == 1
                    warning(message('MATLAB:closereq:ObsoleteUsage'));
                end
                close('force');
            else
                delete(gcbf);
            end
            h = struct2cell(d.handles);
            for i = 1:numel(h)
                try
                    delete(h{i});
                end
            end
            delete(d);
        end
    end
end





