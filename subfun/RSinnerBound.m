% img - image of class img
% mode - mode as string (e.g. 'MRT_OutPhase')
% lvl - thresholding determination (0.1 - 3)

function innerBound = RSinnerBound(img, mode, outerBoundCoord, lvl)

switch mode
    case 'MRT_OutPhase'
        tic
        iDat = img.data;
        iZero = zeros(size(iDat));
        % % get body belt for determining a good threshold lvl
        
        outerBoundCoord = RSouterBound(img, 'MRT_OutPhase', 10);
        outerBoundMask = cCompute.mGetBoundMask(iZero, outerBoundCoord);
        outerBoundMask_erode1 = imerode(outerBoundMask, strel('disk',3));
        outerBoundMask_erode2 = imerode(outerBoundMask_erode1, strel('disk',3));
        
        bodyBelt = outerBoundMask_erode1 & ~outerBoundMask_erode2;
        beltDat = iDat(find(bodyBelt));
        threshLvl = median(beltDat)-lvl*std(double(beltDat))
        % threshLvl = prctile(iDat(find(bodyBelt)), 6);
        
        % % % search for innerBound
        % % find SAT
        bw = iDat>threshLvl;
        cc = bwconncomp(bw,4);
        [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
        SatMask = iZero;
        SatMask(cc.PixelIdxList{maxInd}) = 1;
        
        % % find VAT
        % invert SAT and search connected components
        cc = bwconncomp(~SatMask,4);
        % second biggest is VAT-Area (biggest is area outside body)
        [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
        cc.PixelIdxList(maxInd) = {[NaN]};
        [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
        
        VatMask = iZero;
        VatMask(cc.PixelIdxList{maxInd}) = 1;
        innerBoundCoord = cCompute.mGetBoundaryImageCoord(VatMask);
        innerBound = innerBoundCoord;
        toc
        % % Now make some optimization
        perimAreaRatio = (numel(innerBoundCoord)*numel(innerBoundCoord))/sum(sum(VatMask))
        if perimAreaRatio<300
            % there is to much perimeter for the inner body area
            
        end
        
%         
        f = figure();
        im = imshow(bw, 'DisplayRange', []);
        ax = gca;
        cControl.mDrawContour(ax, outerBoundCoord, {[1 1 1]});
        cControl.mDrawContour(ax, innerBoundCoord, {[0 1 0]});
        cControl.mDrawContour(ax, cCompute.mGetBoundaryImageCoord(bodyBelt), {[0 1 1]}, 'drawMode', {'dot'});
% % 

    case 'CT'
end
end
% 
% %% plot final figures
% f = figure();
% a = histfit(iDat(find(bodyBelt)));
% 
% f = figure();
% im = imshow(iDat, 'DisplayRange', []);
% ax = gca;
% cControl.mDrawContour(ax, outerBoundCoord, {[1 1 1]});
% cControl.mDrawContour(ax, innerBoundCoord, {[0 1 0]});
% cControl.mDrawContour(ax, cCompute.mGetBoundaryImageCoord(bodyBelt), {[0 1 1]}, 'drawMode', {'dot'});