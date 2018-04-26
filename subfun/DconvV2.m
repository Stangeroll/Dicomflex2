% Datapointwise convolution function for unsorted X-Y-Data. Also relations 
% are possible as input.
% Description: Programm uses X-Y-Dataset. It takes smallest X-Value and all
% values within +-CFwidth/2 in one bin and averages X and Y Data for this 
% point. -> Next iteration (next X-Value).....
% -> each value of original data leads to a point in the resulting plot,
% but only Unique values survive.
% xData = xData; yData = yData
% CFwidth = width of each bin. leave ConfidenceInterval = [] to supress calculation
% Methode = can either be 'xmeanymean'; 'xmedianymedian'; 'xmeanymedian'; 'xmedianymean'
% Confidenceinterval = Percent value ranging from 0:100

% DconvV2 gives the same output than DconvV1, but is much faster (~20x) for figures with many graphs. For simple soothening ony 5 times faster
% Calculating confidence intervals may be very slow. Simply leave ConfidenceInterval = [] to supress calculation
 
    


function [xNewData, yNewData, Percentile, Confidence95, Nrofcells] = DconvV2(xData,yData,CFwidth, Methode, Percent)

doPc = ~isempty(Percent);
doCi = doPc;

if ~iscell(xData); xData = {xData}; end
if ~iscell(yData); yData = {yData}; end
xNewData = cellfun(@(x) x(:,1)', xData, 'Uniformoutput', 0);
yNewData = xNewData;
Percentile = xNewData;
Nrofcells = cell(size(xData));
CFwidthR = CFwidth/2;
CFwidthL = CFwidth/2;
tic
for i = 1 : numel (xData)
    x = xData{i}; x = reshape(x,1,numel(x));
    y = yData{i}; y = reshape(y,1,numel(y));    
    [x, ind] = sort(x, 'ascend');
    y = y(ind);
    x = x'; y = y';
    [xU, iU, ~] = unique(x); % whereby x(iU) == xU
    xU = xU(~isnan(xU));    % remove NaN´s
    xNew = zeros(size(xU))';  %xNew and yNew is the new dataset for the current Dataset
    yNew = zeros(size(xU))';
    count = zeros(size(xU))';  
    Pc = zeros(size(xU,1),2)'; % confidence interval
    
    for j = 1 : size(xU,1)
        xtmp = xU(j);
        k = 0; next = 0;
        while next==0   % go from xtmp to higher values till xtmp+CFwidthR is reached. then stop the loop with next = 1
            if xU(j+k) <= xtmp+CFwidthR; 
                try indmax = iU(j+k+1)-1; 
                catch 
                    indmax = iU(end); 
                end % here we are still in range of xtmp+CFwidthR; the indmax is: current+1 iU (unique index) -1; x(1 2 3 3 3 4) -> for 3: iU(j+k) is 3 but iU(j+k+1)-1 is 5!!
                if j+k >= numel(xU)
                    next = next+1;
                end
            else
                next = next+1;
            end
            k=k+1;
        end
        k = 0; next = 0; indmin = iU(j);
        while next==0
            if xU(j-k) >= xtmp-CFwidthL
                indmin = iU(j-k);
                if j == k+1
                    next = next+1; 
                end
            else
                next = next+1; 
            end
            k=k+1;
        end
        Ind = indmin:indmax;
        %Ind = find (x > xU(j)-CFwidth/2 & x < xU(j)+CFwidth/2);
        
        xInd = x(Ind);
        yInd = y(Ind);
        % Methode = can either be 'xmeanymean'; 'xmedianymedian'; 'xmeanymedian'; 'xmedianymean'
        if doCi
            switch Methode
                case 'xmeanymedian'
                    CiX (1:2) = std(xInd)/sqrt(size(xInd,1))*1.96; % http://en.wikipedia.org/wiki/Standard_error#Assumptions_and_usage   s/sqrt(n)*196 = CI(95%)
                    xNew(j) = nanmean(xInd);
                    
                    [CiY yNew(j)] = BootIt(yInd);
                case 'xmeanymean'
                    CiX (1:2) = std(xInd)/sqrt(size(xInd,1))*1.96; % http://en.wikipedia.org/wiki/Standard_error#Assumptions_and_usage   s/sqrt(n)*196 = CI(95%)
                    xNew(j) = nanmean(xInd);
                    
                    CiY (1:2) = std(yInd)/sqrt(size(yInd,1))*1.96; % http://en.wikipedia.org/wiki/Standard_error#Assumptions_and_usage   s/sqrt(n)*196 = CI(95%)
                    yNew(j) = nanmean(yInd);
                case 'xmedianymedian'
                    [CiX xNew(j)] = BootIt(xInd);
                    
                    [CiY yNew(j)] = BootIt(yInd);
                case 'xmedianymean'
                    [CiX xNew(j)] = BootIt(xInd);
                    
                    CiY (1:2) = std(yInd)/sqrt(size(yInd,1))*1.96; % http://en.wikipedia.org/wiki/Standard_error#Assumptions_and_usage   s/sqrt(n)*196 = CI(95%)
                    yNew(j) = nanmean(yInd);
                otherwise
                    disp('Methode not supported. Use "xmeanymedian" "xmeanymean" "xmedianymedian" "xmedianymean"')
                    break
            end
        else
            switch Methode
                case 'xmeanymedian'
                    xNew(j) = nanmean(xInd);
                    yNew(j) = nanmedian(yInd);
                case 'xmeanymean'
                    xNew(j) = nanmean(xInd);
                    yNew(j) = nanmean(yInd);
                case 'xmedianymedian'
                    xNew(j) = nanmedian(xInd);
                    yNew(j) = nanmedian(yInd);
                case 'xmedianymean'
                    xNew(j) = nanmedian(xInd);
                    yNew(j) = nanmean(yInd);
                otherwise
                    disp('Methode not supported. Use "xmeanymedian" "xmeanymean" "xmedianymedian" "xmedianymean"')
                    break
            end
        end
%         plot(x,y,'Linestyle','none','Marker','x','Color','B','Markersize',6); hold on
%         plot(xInd,yInd,'Linestyle','none','Marker','.','Color','R','Markersize',5); hold off
        count (j) = numel(xInd);
        if doPc
            Pc(:,j) = [prctile(yInd, 50-Percent/2) prctile(yInd, 50+Percent/2)];   % define percentile here
        end
        if doCi
            Ci(1:4,j) = [CiX'; CiY']';   % define confidence intervals here
        end
    end
    [~, ind] = unique([xNew; yNew]','rows'); %find unique datapoints
    xNewData(i) = {xNew(ind)};
    yNewData(i) = {yNew(ind)};
    if doPc; Percentile(i) = {Pc(:,ind)}; else Percentile(i) = {zeros(2,numel(ind))}; end
    if doCi; Confidence95(i) =  {Ci(:,ind)}; else Confidence95(i) = {zeros(4,numel(ind))}; end
    
    Nrofcells(i) = {count(ind)};
    disp([num2str(numel(xNewData{i})) ' points used!']);
        
end

    function [Ci DataOut] = BootIt(DataIn)
    BootCount = size(DataIn,1)*2;
    if BootCount>1000; BootCount = 1000; end
    [Ci Stat] = RollBootCi(DataIn,BootCount);
    DataOut = nanmean(Stat); % calc median is more precice by building the mean of the median distribution (Stat)
    end

toc
end


%%%%% old version 2013.05.30
% % Datapointwise convolution function for unsorted X-Y-Data. Also relations 
% % are possible as input. Can be time consuming for large data sets. 
% % Description: Programm uses X-Y-Dataset. It takes smallest X-Value and all
% % values within +-CFwidth in one bin and averages X and Y Data for this 
% % point. -> Next iteration (next X-Value).....
% % -> each value of original data leads to a point in the resluting plot
% 
% 
% function [xNewData, yNewData, stddevData, Nrofcells] = Dconv(xData,yData,CFwidth, Methode)
% if ~iscell(xData); xData = {xData}; end
% if ~iscell(yData); yData = {yData}; end
% 
% xNewData = xData;
% yNewData = yData;
% for i = 1 : numel (xData)
%     x = xData{i}; 
%     y = yData{i};
%     xNew = zeros(length (x));  %xNew and yNew are the new dataset for the current Dataset
%     yNew = zeros(length (x));
%     count = zeros(length (x));
%     stddev = zeros(length (x));
%     for j = 1 : length (x)
%         Ind = find (x > x(j)-CFwidth/2 & x < x(j)+CFwidth/2);  %To convolute unsorted Data or relations(not functions) it searches for data with xValues within the current convolution function
%         xInd = x(Ind);
%         yInd = y(Ind);
%         if strcmp(Methode, 'median')
%             xNew(j) = nanmedian(xInd);
%             yNew(j) = nanmedian(yInd);
%         elseif strcmp(Methode, 'mean')
%             xNew(j) = nanmean(xInd);
%             yNew(j) = nanmean(yInd);
%         end
%         count (j) = numel(xInd);
%         stddev(j) = std(yInd);   %standard error of the mean 95% confidence
%     end
%     [val ind] = unique([xNew; yNew]','rows'); %find unique datapoints
%     xNewData(i) = {xNew(ind)};
%     yNewData(i) = {yNew(ind)};
%     stddevData(i) = {stddev(ind)};
%     Nrofcells(i) = {count(ind)};
%     
% end
% 
% 
% 
% 
% 
% 
% 
% -------------------------------
% % Datapointwise convolution function for unsorted X-Y-Data. Also relations 
% % are possible as input. Can be time consuming for large data sets. 
% % Description: Programm uses X-Y-Dataset. It takes smallest X-Value and all
% % values within +-CFwidth in one bin and averages X and Y Data for this 
% % point. -> Next iteration (next X-Value).....
% % -> each value of original data leads to a point in the resluting plot
% 
% 
% function [xNewData, yNewData, stddevData, Nrofcells] = Dconv(xData,yData,CFwidth, Methode)
% if ~iscell(xData); xData = {xData}; end
% if ~iscell(yData); yData = {yData}; end
% for i = 1 : numel (xData)
%     x = xData{i}; 
%     y = yData{i};
%     xNew = [];  %xNew and yNew are the new dataset for the current Dataset
%     yNew = [];
%     n = 1;
%     for j = 1 : length (x)
%         n
%         j
%         Ind = find (x > x(j)-CFwidth/2 & x < x(j)+CFwidth/2);  %To convolute unsorted Data or relations(not functions) it searches for data with xValues within the current convolution function
%         xInd = x(Ind);
%         yInd = y(Ind);
%         if strcmp(Methode, 'median')
%             xNew(j) = nanmedian(xInd);
%             yNew(j) = nanmedian(yInd);
%         elseif Methode == 'mean'
%             xNew(j) = nanmean(xInd);
%             yNew(j) = nanmean(yInd);
%         end
%         count (j) = numel(xInd);
%         stddev(j) = std(yInd);   %standard error of the mean 95% confidence
%         n = n + 1
%     end
%     [val ind] = unique([xNew; yNew]','rows'); %find unique datapoints
%     xNewData(i) = {xNew(ind)};
%     yNewData(i) = {yNew(ind)};
%     stddevData(i) = {stddev(ind)};
%     Nrofcells(i) = {count(ind)};
%     
% end

