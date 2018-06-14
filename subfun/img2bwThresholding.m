function [imgOut thLvl] = img2bwThresholding(img, magnitude)
% function searches for first max in the image histograms first diff as the threshold basis
[histDat histInd] = histcounts(img, 'BinMethod', 'integer');
histDat(1) = 0;
filtWidth = round(max(max(img))*0.02);
histFilt = movmean(histDat, filtWidth);
histFiltDiff = -diff(histFilt);

%histDiffDat = movmean(histDiff, filtWidth);
%histDiffDat = histDiffDat(filtWidth:end);
minDist = max(max(img))/5;
thLvlAll = localMaximum(histFiltDiff, minDist, true)+1;
thLvlAll = thLvlAll*magnitude;
thLvl = thLvlAll(1); % just to be sure
imgOut = img>thLvl;

% %debug
% figure(); 
% hD = plot(histFilt);
% figure(); 
% hDD = plot(histFiltDiff);
% axes(hD.Parent);
% hold on
% plot(thLvlAll, zeros(numel(thLvlAll)), 'LineStyle', 'none', 'Marker', '.', 'Markersize', 20);
% hold off

% % before 20180419
% [histDat histInd] = histcounts(img, 'BinMethod', 'integer');
% histDat(1) = 0;
% histDiffDat = movmean(-diff(histDat),50);
% thLvl = localMaximum(histDiffDat, 800, true)
% thLvl = thLvl*magnitude;
% thLvl = thLvl(1); % just to be sure
% img = img>thLvl
end