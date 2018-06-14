% Evaluate time stamps of Dicomflex files
function patient = EvaluateTimeLogging(file, folder)
patient.file = file;
patient.folder = folder;

% [patient.file patient.folder] = uigetfile('C:\Users\StangeR\MATLAB\FatSegmentPatienten\', '*.mat');
load(fullfile(patient.folder, patient.file));

%% collect data
actions = oContLogging.Action';
stamps = oContLogging.Stamp';

%% determine times needed for each slice
tableCellSelect.searchString = 'oCont.mTableCellSelect';
[tableCellSelect.inds tableCellSelect.actions tableCellSelect.stamps] = ind2action(tableCellSelect.searchString, actions, stamps);

tableCellSelect.rows_all = cellfun(@(x) str2num(x(30:31)), tableCellSelect.actions);
tableCellSelect.rows = unique(tableCellSelect.rows_all);
indizes = {};
times = {};
tableCellSelect.deltaTimes = diff(tableCellSelect.stamps);
tableCellSelect.deltaTimes = [tableCellSelect.deltaTimes; 0];
deltaTimes = tableCellSelect.deltaTimes;
rows = tableCellSelect.rows_all;
i = 0;
for row = tableCellSelect.rows'
    i=i+1;
    indizes{i} = find(rows==row);
    times{i} = deltaTimes(indizes{i});
end

tableCellSelect.times = cellfun(@(x) sum(x), times)*24*3600;

% find autosegment all times and subtract them from slice times
autoSegmentAll_start.searchString = 'oCont.mMenuCallback - start @(oComp)oCont.oComp.mAutoSegmentAll(oCont)';
[autoSegmentAll_start.inds autoSegmentAll_start.actions autoSegmentAll_start.stamps] = ind2action(autoSegmentAll_start.searchString, actions, stamps);
autoSegmentAll_end.searchString = 'oCont.mMenuCallback - end @(oComp)oCont.oComp.mAutoSegmentAll(oCont)';
[autoSegmentAll_end.inds autoSegmentAll_end.actions autoSegmentAll_end.stamps] = ind2action(autoSegmentAll_end.searchString, actions, stamps);

for i = 1:numel(autoSegmentAll_start.inds)
[x ind] = min(abs(autoSegmentAll_start.inds(i)-tableCellSelect.inds));
tmp = actions(tableCellSelect.inds(ind));
autoSegmentAll.rows(i) = str2num(tmp{1}(30:31));
autoSegmentAll.time(i) = (autoSegmentAll_end.stamps(i)-autoSegmentAll_start.stamps(i))*24*3600;

ind = find(tableCellSelect.rows==autoSegmentAll.rows(i));
tableCellSelect.times(ind) = tableCellSelect.times(ind)-autoSegmentAll.time(i);
end

patient.Slice_Times = tableCellSelect.times';
patient.Slice_Nrs = tableCellSelect.rows;
patient.AutoSegmentAll_Times = autoSegmentAll.time;

%% determine loading time
searchString = 'mLoadData - start';
[inds_out actions_out loadStart_stamp] = ind2action(searchString, actions, stamps);
searchString = 'mLoadData - end';
[inds_out actions_out loadEnd_stamp] = ind2action(searchString, actions, stamps);

patient.LoadTime = (loadEnd_stamp-loadStart_stamp)*24*3600;

%% determine total patient time from load to save
searchString = 'mLoadData - start';
[inds_out actions_out loadStart_stamp] = ind2action(searchString, actions, stamps);
searchString = 'mSaveData - start';
[inds_out actions_out saveStart_stamp] = ind2action(searchString, actions, stamps);

patient.TotalWorkTime = (saveStart_stamp-loadStart_stamp)*24*3600;

end

function [inds actions stamps] = ind2action(searchString, actions, stamps)
val = searchString;
tmp = cellfun(@(x) strfind(x, val), actions, 'un', false);
tmp = cellfun(@(x) sum(x), tmp);
inds = find(tmp);

stamps = stamps(inds);
actions = actions(inds);

end


