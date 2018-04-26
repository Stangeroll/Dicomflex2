% img - image of class img
% mode - mode as string (e.g. 'MRT_OutPhase')
% mag - magnitude for thresholding (0.1 to inf)

function outerBound = RSouterBound(img, mode, mag)
kernel20 = ones(20,20);
kernel10 = ones(10,10);
kernel05 = ones(5,5);
kernel04 = ones(4,4);
kernel03 = ones(3,3);
kernel02 = ones(2,2);
switch mode
    case 'MRT_OutPhase'
        img0 = img.data;
        % Th mit kleinem wert
        [imgBw thLvl] = img2bwThresholding(img0, mag);
        
        % reject holes
        imgBw = imfill(imgBw, 'holes');
        
        % reject small areas (take max region)
        cc = bwconncomp(imgBw, 8);
        [a maxInd] = max(cellfun(@(x) size(x,1), cc.PixelIdxList));    % find maximum area
        imgBw = zeros(size(img0));
        imgBw(cc.PixelIdxList{maxInd}) = 1;
        
        % reject holes
        %imgBw = imfill(imgBw, 'holes');
        
        % get boundary image
        outerBound = bwboundaries(imgBw);
        outerBound = outerBound{1};
        
%         % get outer bound region (OBR)
%         img3erode = imerode(imgBw, kernel20, 'same');
%         img3dilate = imdilate(imgBw, kernel20, 'same');
%         OBR = zeros(size(img0));
%         OBR(img3dilate&~img3erode) = 1;
%         
%         % use hist of outer bound region to get better Th
%         img4 = img0;
%         img4(find(~OBR)) = 0;
%         histogram(img4(img4~=0),200)
%         [histDat histInd] = histcounts(img4, 'BinMethod', 'integer');
%         histDat(1) = 0;
%         histConv = conv2(histDat, ones(1,round(size(histDat,2)/50)));

        
    case 'CT'
end
end