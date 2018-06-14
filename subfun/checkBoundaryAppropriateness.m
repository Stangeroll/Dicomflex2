% check boundary quality. oB, iB, vB are arrays of structs

function [ind quality] = checkBoundaryAppropriateness(boundName, oB, iB, vB, iDat, iZero)
switch boundName
    case 'innerBound'
        %gradientLines = imbinarize(uint16(imgradient(iDat)), 'adaptive');
        for i = 1:numel(iB)
            circularity(i) = iBcircularity(iB(i));
            centricity(i) = iBcentricity(oB(1), iB(i));
            proximalBrightness(i) = iBproximalBrightness(iB(i), iDat);
            boundGradientFitScore(i) = boundToGradientFitScore(iDat, iB(i).coord);
            areaBrightness(i) = oBareaBrightness(oB, iB(i), iDat);
        end
        
        score = circularity.*centricity;
        tmp = find(proximalBrightness<0.4);
        score(tmp) = 0;
        [a ind] = max(score);
        
        quality = a;
        
%         % proximalBrightness must be low enough
%         tmp = find(proximalBrightness>0.6);
%         
%         % boundToGradientFitScore must be as high as possible
%         boundToGradientFitScore(tmp) = 0;
%         [a ind] = max(boundToGradientFitScore);
%         
%         % circularity must be highest
%         circularity(tmp) = inf;
%         [a ind] = min(circularity);
%         
%         if proximalBrightness(ind)<0.6
%             boundOut = iB(ind);
%         else
%             uiwait(msgbox('iB Check error: circulatity ok but proximalBrightness > 0.6'));
%             boundOut = iB(ind);
%         end
        
    case 'outerBound'
    case 'visceralBound'
end
end

% %% check outerBound alone
% if mean(iDat(find(outerBound.Mask))) < mean(iDat(:))
%     code = 'Precheck: outerBound in dark area';
%     return
% end
% 
% rp = regionprops(outerBound.Mask, 'EquivDiameter', 'Extent', 'MajorAxisLength', 'MinorAxisLength', 'PixelIdxList');
% circularity = sum(sum(bwperim(outerBound.Mask)))/(rp.EquivDiameter*pi);   % bound length diveded by equivalent circle perimeter
% if circularity>1.5
%     code = 'Precheck: outerBound not round';
%     return
% end
function areaBrightness = oBareaBrightness(oB, iB, iDat)
intensities = double(iDat(oB.Mask&~iB.Mask));
brightness = mean(intensities);
area = numel(intensities);
skew = skewness(intensities);
areaBrightness = skew;
end

function centricity = iBcentricity(oB, iB)
% the closer the value gets to 1, the more centered is the iB center to the
% oB center
rp = regionprops(iB.Mask, 'Centroid');
iB.Center = rp.Centroid;

rp = regionprops(oB.Mask, 'Centroid');
oB.Center = rp.Centroid;

centricity = 1-max(abs((oB.Center-iB.Center)./oB.Center));
end

function boundToGradientFitScore = boundToGradientFitScore(iDat, coord)
boundMask = cCompute.mGetBoundMask(iDat, coord, 'fillHoles', false);
gradIm = imgradient(iDat);
boundToGradientFitScore = sum(sum(gradIm.*boundMask))/numel(boundMask);
end

function circularity = iBcircularity(iB)
% the closer the value gets from 0 to 1 the more circular
rp = regionprops(iB.Mask, 'EquivDiameter', 'Extent', 'MajorAxisLength', 'MinorAxisLength', 'PixelIdxList');
circularity = (rp.EquivDiameter*pi)/sum(sum(bwperim(iB.Mask)))/1.11;

%% to test min circularity value
% tmp.Mask = fspecial('gaussian',1000,20);
% tmp.Mask = imbinarize(tmp.Mask, 0.0001);
% iBcircularity(tmp)
end

function extent = iBextent(iB)
rp = regionprops(iB.Mask, 'Extent');
extent = rp.Extent;
end

function proximalBrightness = iBproximalBrightness(iB, iDat)
% the closer the value gets to 1, the more contrast has the boundary
% % innerBound lays in SAT area
tmp = imerode(iB.Mask, strel('disk', 4));
iB.ProximalMask = (iB.Mask&~tmp);

tmp = imdilate(iB.Mask, strel('disk', 4));
iB.DistalMask = (tmp&~iB.Mask);
proximalBrightness = 1-mean(iDat(find(iB.ProximalMask)))/mean(iDat(find(iB.DistalMask)))
end


% innerBound lays in VAT-area
%                                 n = 0.02;
%                                 SAT.Mask = o.Mask & ~i.Mask;
%                                 hole.Mask = ~o.PriorFilledMask & SAT.Mask;
%                                 cc = bwconncomp(hole.Mask, 4);
%                                 if ~isempty(cc.PixelIdxList)
%                                     [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
%                                     hole.Mask = iZero;
%                                     hole.Mask(cc.PixelIdxList{maxInd}) = 1;
%                                 end
%
%                                 %hole size
%                                 hole.Area = sum(sum(hole.Mask))/sum(sum(o.Mask));
%
%                                 if hole.Area>n
%                                     holeToBig = true;
%                                 else
%                                     holeToBig = false;
%                                 end
%
%                                 %hole possition
%                                 hole.rp = regionprops(cc, 'Centroid');
%                                 o.rp = regionprops(o.Mask, 'Centroid');
%                                 hole.DistanceFromBodyCenter = abs((hole.rp(maxInd).Centroid ./ o.rp.Centroid)-1);    % distance of the hole from the center of the body in %
%                                 if all(hole.DistanceFromBodyCenter<0.20)
%                                     % if there are any holes in the SAT-mask that are closer to the center of the whole body than m%
%                                     % -> SAT mask includes parts of VAT
%                                     holeToCloseToCenter = true;
%                                 else
%                                     holeToCloseToCenter = false;
%
%                                 end
%
%                                 %hole brightness
%                                 meanSAT = mean(iDat(find(SAT.Mask)));
%                                 meanVAT = mean(iDat(find(visceralBound.Mask)));
%                                 meanHole = mean(iDat(find(hole.Mask)));
%                                 if meanHole<meanVAT
%                                     % if the hole is dark -> must be VAT
%                                     % if the hole is bright -> could also be SAT
%                                     holeIsToDark = true;
%                                 else
%                                     holeIsToDark = false;
%                                 end
%
%                                 if holeToBig&holeToCloseToCenter&holeIsToDark
%                                     % a bad hole must be big, close to center and dark!
%                                     code = 'innerBound includes SAT parts';
%                                     return
%                                 end