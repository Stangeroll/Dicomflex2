% This function was copied by Roland Stange from the code of Nikita Garnov
% out of FAT_160322.m

function [seg1 seg2 seg3] = NikitaFat161213Segmenting(actImage, infoRef)

small_actImage = imresize(actImage,[200 NaN]);                      % make image smaller, zwecks Beschleunigung
seg1 = actImage>0;                                             % seg1 - outer SAT-Maske
body    = seg1.*double(actImage);                              % Bild innerhalb der Maske (Originale Größe)
body_r  = imresize(seg1, [200 NaN]).*double(small_actImage);   % Bild innerhalb der Maske (reduziert)


tic
%% Active Contours INNER SAT
[~,mask]  = kmeans(body_r,2);                                       % K-MEANS image clustering (2 Stufen)
workMask = mask==2;

% Übergang von der äußeren auf imnnere SAT-Maske mittels regiongrowing
x=1; y=1;
outer_mask = regiongrowing(workMask,x,y,0.2);
workMask= workMask+outer_mask;
workMask=~workMask;
workMask= imfill(workMask,'holes');

% Wenn keine Area > 100 -> Bauchnabel-Spalt
connCmp = bwconncomp(workMask);
maskAreas = regionprops(connCmp, 'Area');
areaSize=100;
areaIndex = find([maskAreas.Area]>areaSize);
if isempty(areaIndex)                                                %
    workMask = mask==2;   % mask - cluster-Image                     %
    seg1edg = edge(imresize(seg1, [200 NaN]), 'sobel');              %      % Schließen des Spalts ...
    workMask = ~(~workMask.*~seg1edg);                               %      % durch seg1-Kontur
    x=1; y=1;                                                        %
    outer_mask = regiongrowing(workMask,x,y,0.2);                    %
    workMask= workMask+outer_mask;                                   % Problem: Bauchnabel-Spalt
    workMask=~workMask;                                              %
    workMask= imfill(workMask,'holes');                              %
    kernel = ones(5,5);                                              %
    workMask_eroded = imerode(workMask, kernel, 'same');             %
    workMask = imdilate(workMask_eroded, kernel, 'same');            %
end                                                                  %

connCmp = bwconncomp(workMask);
maskAreas = regionprops(connCmp, 'Area');
areaIndex = find([maskAreas.Area]>areaSize);

if isempty(areaIndex)
    disp('if-Bedienung Line 300')                                   % Sonstige Ausnahme (???)
    [~,mask]  = kmeans(small_actImage,2);
    mask_outer = imfill(mask, 'holes');
    workMask = mask_outer==2;
    workMask_dilated = imdilate(workMask, ones(2, 2), 'same');
    x=1; y=1;
    outer_mask = regiongrowing(workMask_dilated,x,y,0.2);
    workMask= workMask_dilated+outer_mask;
    workMask=~workMask;
    workMask= imfill(workMask,'holes');
    connCmp = bwconncomp(workMask);
    maskAreas = regionprops(connCmp, 'Area');
    areaIndex = find([maskAreas.Area]>areaSize);
    workMask = ismember(labelmatrix(connCmp), areaIndex);
end

kernel = ones(20,20);
workMask_dilated = imdilate(workMask, kernel, 'same');              % Maske vergrößern
workMask = imerode (workMask_dilated, kernel, 'same');              % Vergrößerte Maske wieder verkleinern
workMask = imfill (workMask, 'holes');                              % innere Räume werden gefüllt

connCmp = bwconncomp(workMask);
maskAreas = regionprops(connCmp, 'Area');
areaSize=500;
areaIndex = find([maskAreas.Area]>areaSize);
% Wenn keine große Flächen (> 500) nicht gefunden werden ->
% kleinere Flächen zusammenschließen durch
% um 40 % vergrößern und wieder verkleinern
if isempty(areaIndex)
    seg1_pad = padarray(imresize(seg1, [200 NaN]), [50 50]);
    seg1_dil = imdilate (seg1_pad, ones(40,40), 'same');
    seg1_dil = imfill(seg1_dil, 'holes');
    seg2_pad = imerode (seg1_dil, ones(80,80), 'same');
    seg2 = imcrop(seg2_pad, [51 51 size(seg1_pad)-101]);
else    % ansonsten leichte Anpassung mittels snake-Algorithms
    seg2 = region_seg(small_actImage, workMask, 40, 10, false);
end

connCmp = bwconncomp(seg2);
if connCmp.NumObjects > 1                                %
    ccarea_max = 0;                                       %
    for ccno = 1 : connCmp.NumObjects                     %
        ccarea = length(connCmp.PixelIdxList{ccno});      %
        if ccarea >= ccarea_max                           %
            ccarea_max = ccarea;                           % die groesste Maske auswaehlen
            ccarea_no  = ccno;                            %
        end                                               %
    end                                                   %
    seg2 = ismember(labelmatrix(connCmp), ccarea_no);     %
end                                                      %

seg2 = imresize(seg2, [infoRef.Rows infoRef.Columns]);              % seg2 - inner SAT-Maske (Originale Größe)



sub_FAT    = seg1.*~seg2.*double(body);                                 % SAT-Bild innerhalb der Maske

%% Active Contours VAT
if  seg2(1, 1) == 1
    vis_FAT    = seg1.*~seg2.*double(body);
elseif ~seg2(1, 1) == 1
    vis_FAT    = seg1.*seg2.*double(body);
end

if mean(vis_FAT(:)) == 0;
    vis_FAT    = seg2.*double(actImage);
end

if mean(vis_FAT(:)) == 0;
    disp('line 370: mean(vis_FAT(:)) == 0; - seg2 (inner SAT mask) is empty')
    seg3 = zeros(size(seg1));
else
    workImage =  vis_FAT;
    small_workImage = imresize(workImage,[200 NaN]);                %-- make image smaller
    [~,mask]  = kmeans(int16(small_workImage),2);                   % K-MEANS image clustering (2 Stufen)
    workMask = mask==2;
    % Suchen Flächen > 200 und glätten (imdilate-imerode-imfill)
    connCmp = bwconncomp(workMask, 8);
    maskAreas = regionprops(connCmp, 'Area');
    areaSize=200;
    areaIndex = find([maskAreas.Area]>areaSize);
    workMask = ismember(labelmatrix(connCmp), areaIndex);
    kernel = ones(10,10);
    workMask_dilated = imdilate(workMask, kernel, 'same');
    workMask = imerode (workMask_dilated, kernel, 'same');
    workMask = imfill (workMask, 'holes');
    
    try
        seg3 = region_seg(small_workImage, workMask, 20, 10, false);    % leichte Anpassung mittels snake-Algorithms
    catch
        kernel   = ones(3,3);
        seg3 =  imdilate(workMask, kernel, 'same');
    end
    % Nur eine - größte - VAT-Maske lassen
    connCmp = bwconncomp(seg3);
    maskAreas = regionprops(connCmp, 'Area');
    if numel(maskAreas) > 1
        areaIndex = find ([maskAreas.Area] == max(cell2mat(struct2cell(maskAreas))));
        seg3 = ismember(labelmatrix(connCmp), areaIndex);
    end
    
    seg3 = imresize(seg3,[infoRef.Rows infoRef.Columns]);           % seg3 - VAT-Maske (Originale Größe)
    
    kernel = ones(7,7);                                                     %
    seg3 = imdilate(seg3, kernel, 'same');                                  % um (7-2) = 5 Pts erweitern
    seg3 = seg3.*seg2;                                                      % (aber seg3 < seg2, d.h. VAT < iSAT)
    kernel = ones(2,2);                                                     %
    seg3 = imerode(seg3, kernel, 'same');                                   %
    
end
toc
end