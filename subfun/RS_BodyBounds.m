% img - image of class img
% mode - mode as string (e.g. 'MRT_OutPhase')
% mag - magnitude for thresholding (0.1 to inf)

function [outerBound innerBound visceralBound code] = RS_BodyBounds(img, mode, boundName, outerBound, innerBound, visceralBound)
code = 'OK';
switch mode
    case 'MRT_OutPhase'
        iDat = img.data;
        iZero = zeros(size(iDat));
        switch boundName
            case 'outerBound'
                %% find outerBound
                filtersize = round(([outerBound.ThreshWindowSizeMultip*floor(size(iDat)/16)]-1)/2)*2+1;   % make an odd number as filtersize
                threshMask = adaptthresh(iDat, 'NeighborhoodSize', filtersize, 'Statistic', 'gaussian');
                threshMask = threshMask * outerBound.ThreshMultip;
                outerBound.Mask = imbinarize(iDat, threshMask);
                % take object with biggest dimensons
                rp = regionprops(outerBound.Mask, 'MajorAxisLength', 'MinorAxisLength', 'PixelIdxList');
                [a maxInd] = max([rp.MajorAxisLength] + [rp.MinorAxisLength]);    % find maximum area
                outerBound.Mask = iZero;
                outerBound.Mask(rp(maxInd).PixelIdxList) = 1;
                outerBound.PriorFilledMask = outerBound.Mask; % needed for later checkings
                
                % dilate and remove to close small openings
                outerBound.Mask = imdilate(outerBound.Mask, strel('disk', 2, 0));
                outerBound.Mask = imfill(outerBound.Mask, 'holes');
                outerBound.Mask = imerode(outerBound.Mask, strel('disk', 2, 0));
                
                
                outerBound.coord = cCompute.mGetBoundaryImageCoord(outerBound.Mask);
                
                %% check outerBound alone
                if mean(iDat(find(outerBound.Mask))) < mean(iDat(:))
                    code = 'Precheck: outerBound in dark area';
                    return
                end
                
                rp = regionprops(outerBound.Mask, 'EquivDiameter', 'Extent', 'MajorAxisLength', 'MinorAxisLength', 'PixelIdxList');
                circularity = sum(sum(bwperim(outerBound.Mask)))/(rp.EquivDiameter*pi);   % bound length diveded by equivalent circle perimeter
                
                if circularity>1.5
                    code = 'Precheck: outerBound not round';
                    return
                end
                outerBound.status = 'OK';
                code = 'outerBound OK';
                
            case 'innerBound'
                %% find innerBound
                filtersize = round(([innerBound.ThreshWindowSizeMultip*floor(size(iDat)/16)]-1)/2)*2+1;   % make an odd number as filtersize
                threshMask = adaptthresh(iDat, innerBound.ThreshSensitivity, 'NeighborhoodSize', filtersize, 'Statistic', 'gauss');
                threshMask = threshMask * innerBound.ThreshMultip;
                innerBound.Mask = ~imbinarize(iDat, threshMask); % thresholding
                innerBound.PriorFilledMask = innerBound.Mask;
                innerBound.Mask(find(~outerBound.Mask)) = 0;    % remove outerBody region
                
%                 % close openings
%                 SE = strel('disk', 2, 0);
%                 innerBound.Mask = imclose(innerBound.Mask, SE);
                
                % use biggest area
                cc = bwconncomp(innerBound.Mask, 4);
                [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
                innerBound.Mask = iZero;
                innerBound.Mask(cc.PixelIdxList{maxInd}) = 1;
                
                % close openings and remove holes
                SE = strel('disk', 1, 0);
                innerBound.Mask = imdilate(innerBound.Mask, SE);
                innerBound.Mask = imfill(innerBound.Mask, 'holes');
                innerBound.Mask = imerode(innerBound.Mask, SE);
                
                % erode and remove residues (clean outward pointing small objects)
                SE = strel('disk', 1, 0);
                innerBound.Mask = imerode(innerBound.Mask, SE);
                cc = bwconncomp(innerBound.Mask, 4);
                [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
                innerBound.Mask = iZero;
                innerBound.Mask(cc.PixelIdxList{maxInd}) = 1;
                innerBound.Mask = imdilate(innerBound.Mask, SE);
                
                
                innerBound.coord = cCompute.mGetBoundaryImageCoord(innerBound.Mask);
                
                innerBound.status = 'OK';
                code = 'innerBound OK';
                
            case 'visceralBound'
                %% % find visceralBound
                visceralBound.Mask = imerode(innerBound.Mask, strel('disk', visceralBound.ErodeSize, 0));
                cc = bwconncomp(visceralBound.Mask,4);
                [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
                visceralBound.Mask = iZero;
                visceralBound.Mask(cc.PixelIdxList{maxInd}) = 1;
                
                visceralBound.coord = cCompute.mGetBoundaryImageCoord(visceralBound.Mask);
                
                visceralBound.status = 'OK';
                code = 'visceralBound OK';
                
            case 'CT'
        end
end