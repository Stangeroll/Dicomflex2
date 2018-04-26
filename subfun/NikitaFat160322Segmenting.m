% This function was copied by Roland Stange from the code of Nikita Garnov
% out of FAT_160322.m

function [seg1 seg2 seg3] = NikitaFat160322Segmenting(actImage, infoRef)
AreaScale = 1;
tic
small_actImage = imresize(actImage,[200 NaN]);                      % make image smaller, zwecks Beschleunigung
[~,mask]  = kmeans(small_actImage,2);                               % K-MEANS image clustering (2 Stufen)
mask_outer = imfill(mask, 'holes');                                 % innere R‰ume werden gef¸llt
%% Active Contours OUTER SAT

workMask = mask_outer==2;

connCmp = bwconncomp(workMask, 4);                                  % find connected components, 4 - connectivity
maskAreas = regionprops(connCmp, 'Area');                           % Areas in den connected components
areaSize = 3000/AreaScale;                                                    % 3000 - ein Grenzwert um Kˆrperumfang vom Armenumfang oder sonstigen Stˆrungen zu unterscheiden
areaIndex = find([maskAreas.Area]>areaSize);                        % Finde Areas > areaSize zur Auswahl des grˆﬂten Umfangs

% wenn solche nicht gefunden wurden -> Maske um 10 pixel vergrˆﬂern
% und wieder verkleinern zum Schlieﬂen von offenen Konturen
if isempty(areaIndex)
    kernel = ones(10,10);                                           % kernel 10 pixel
    workMask_dilated = imdilate(workMask, kernel, 'same');          % Maske vergrˆﬂern
    workMask_eroded = imerode (workMask_dilated, kernel, 'same');   % Vergrˆﬂerte Maske wieder verkleinern
    workMask = imfill(workMask_eroded, 'holes');                    % innere R‰ume werden gef¸llt
    connCmp = bwconncomp(workMask, 4);                              % find connected components, 4 - connectivity
    maskAreas = regionprops(connCmp, 'Area');
    %             areaSize=8000;
    areaIndex = find([maskAreas.Area]>areaSize);
end

% wenn immernoch keine Areas gefunden wurden -> dann handelt es
% sich hˆchstwahrscheinlich um eine Schicht mit dem Bauchnabelspalt
if isempty(areaIndex)
    actImage_blur   = medfilt2(actImage);                           % Image weichzeichnen
    extension = 1;
    % Solange die Maske vergrˆﬂern/verkleinern bis sich der Spalt
    % schlieﬂt
    while isempty(areaIndex)
        actImage_edge = edge(actImage_blur, 'canny', .25);                      % EDGE - Konturen suchen
        actImage_edge = padarray(actImage_edge, [extension+20 extension+20]);   % Bildabmessungen um 20 pixel erweitern
        actImage_edge = imdilate(actImage_edge, ones(extension, extension), 'same');    % Konturen um 'extension'-Wert aufweiten
        workMask = imfill(actImage_edge, 'holes');                              % innere R‰ume werden gef¸llt
        workMask = imerode (workMask, ones(extension, extension), 'same');      % Vergrˆﬂerte Maske wieder verkleinern
        workMask = imcrop(workMask, [extension+21 extension+21 size(actImage)-1]);      % Bildabmessungen verkleinern
        workMask = imresize(workMask, [200 200]);
        connCmp = bwconncomp(workMask, 4);                                      % find connected components, 4 - connectivity
        maskAreas = regionprops(connCmp, 'Area');                               % Areas in den connected components
        %                 areaSize=3000;
        areaIndex = find([maskAreas.Area]>areaSize);                            % Finde Areas > areaSize zur Auswahl des grˆﬂten Umfangs
        extension = extension + 1;                                              % extension increment wenn keien Area gefunden
    end
end

% wenn mehrere groﬂe Areas gefunden wurden, werden zwei grˆﬂten
% ausgew‰hlt
while length(areaIndex)>2
    areaSize= areaSize+100;
    areaIndex = find([maskAreas.Area]>areaSize);
end

% danach sollte auf jeden Fall mindestens eine Area vorhanden sein
workMask = ismember(labelmatrix(connCmp), areaIndex);               % diese wird zur Arbeitsmaske gemacht
kernel = ones(10,10);
% wenn die zwei Masken fast gleich groﬂ sind (Verh‰ltnis < 1:1.25), werden sie zu einer  gebunden
if length(areaIndex) == 2 && max(maskAreas(areaIndex(1)).Area, maskAreas(areaIndex(2)).Area)/min(maskAreas(areaIndex(1)).Area, maskAreas(areaIndex(2)).Area) < 1.25
    workMask_dilated = imdilate(workMask, kernel, 'same');
    workMask_eroded = imerode (workMask_dilated, kernel, 'same');
    workMask = workMask_eroded;
else    % wenn nicht, dann wird die grˆﬂte ausgew‰hlt
    while length(areaIndex)>1
        areaSize = areaSize+100;
        areaIndex = find([maskAreas.Area]>areaSize);
    end
    workMask = ismember(labelmatrix(connCmp), areaIndex);           % diese wird zur Arbeitsmaske gemacht
end

workMask_dilated = imdilate(workMask, kernel, 'same');          % Maske vergrˆﬂern
workMask = imerode (workMask_dilated, kernel, 'same');          % Vergrˆﬂerte Maske wieder verkleinern
workMask = imfill (workMask, 'holes');                          % innere R‰ume werden gef¸llt

% Jetzt wird ¸berpr¸ft, ob alle vorherige Aktionen zu einer groﬂen Maske (areaSize=10000) gef¸hrt haben
connCmp = bwconncomp(workMask, 4);
maskAreas = regionprops(connCmp, 'Area');
areaSize=10000/AreaScale;
areaIndex = find([maskAreas.Area]>areaSize);

% wenn nicht wird solange die Maske vergrˆﬂert/verkleinert bis so
% eine Maske entsteht
if isempty(areaIndex)
    actImage_blur   = medfilt2(actImage);
    areaIndex = [];
    extension = 4;
    while isempty(areaIndex)==1
        actImage_edge = edge(actImage_blur, 'canny', .25);
        actImage_edge = padarray(actImage_edge, [extension+20 extension+20]);
        actImage_edge = imdilate(actImage_edge, ones(extension, extension), 'same');                        % * Bauchnabel *
        workMask = imfill(actImage_edge, 'holes');
        workMask = imerode (workMask, ones(extension, extension), 'same');                        %    Problem
        workMask = imcrop(workMask, [extension+21 extension+21 size(actImage)-1]);
        connCmp = bwconncomp(workMask, 4);
        maskAreas = regionprops(connCmp, 'Area');
        areaIndex = find([maskAreas.Area]>areaSize);
        extension = extension + 1;
    end
    while length(areaIndex)>2
        areaSize= areaSize+500;
        areaIndex = find([maskAreas.Area]>areaSize);
    end
    
    workMask = ismember(labelmatrix(connCmp), areaIndex);
    
    kernel = ones(20,20);
    
    % wenn die zwei Masken fast gleich groﬂ sind (Verh‰ltnis < 1:1.25), werden sie zu einer  gebunden
    if length(areaIndex) == 2 && max(maskAreas(areaIndex(1)).Area, maskAreas(areaIndex(2)).Area)/min(maskAreas(areaIndex(1)).Area, maskAreas(areaIndex(2)).Area) < 1.25
        workMask_dilated = imdilate(workMask, kernel, 'same');
        workMask_eroded = imerode (workMask_dilated, kernel, 'same');
        workMask = workMask_eroded;
        connCmp = bwconncomp(workMask, 4);
        maskAreas = regionprops(connCmp, 'Area');
        areaSize=10000/AreaScale;
        areaIndex = find([maskAreas.Area]>areaSize);
    else    % wenn nicht, dann wird die grˆﬂte ausgew‰hlt
        while length(areaIndex)>1
            areaSize= areaSize+100;
            areaIndex = find([maskAreas.Area]>areaSize);
        end
        workMask = ismember(labelmatrix(connCmp), areaIndex);   % diese wird zur Arbeitsmaske gemacht
    end
    % Wenn trotzdem keine groﬂe Maske gefunden wurde,
    % eine kleinere (areaSize=3000) suchen
    if isempty(areaIndex)
        [~,mask]  = kmeans(small_actImage,2);
        mask_outer = imfill(mask, 'holes');
        workMask = mask_outer==2;
        connCmp = bwconncomp(workMask, 4);
        maskAreas = regionprops(connCmp, 'Area');
        areaSize=3000/AreaScale;
        areaIndex = find([maskAreas.Area]>areaSize);
        workMask = ismember(labelmatrix(connCmp), areaIndex);
    end
    
    seg1 = workMask;                                               % seg1 - outer SAT-Maske
    body    = seg1.*double(actImage);                              % Bild innerhalb der Maske (Originale Grˆﬂe)
    body_r  = imresize(seg1, [200 200]).*double(small_actImage);   % Bild innerhalb der Maske (reduziert)
    
else
    seg1 = region_seg(small_actImage, workMask, 40, 5, false);      % leichte Anpassung mittels snake-Algorithms
    body_r  = seg1.*double(small_actImage);                        % Bild innerhalb der Maske (reduziert)
    seg1 = imresize(seg1, [infoRef.Rows infoRef.Columns]);         % seg1 - outer SAT-Maske (Originale Grˆﬂe)
    body    = seg1.*double(actImage);                              % Bild innerhalb der Maske (Originale Grˆﬂe)
    
end
toc
tic
%% Active Contours INNER SAT
[~,mask]  = kmeans(body_r,2);                                       % K-MEANS image clustering (2 Stufen)
workMask = mask==2;

% ‹bergang von der ‰uﬂeren auf imnnere SAT-Maske mittels regiongrowing
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
    seg1edg = edge(imresize(seg1, [200 200]), 'sobel');              %      % Schlieﬂen des Spalts ...
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
workMask_dilated = imdilate(workMask, kernel, 'same');              % Maske vergrˆﬂern
workMask = imerode (workMask_dilated, kernel, 'same');              % Vergrˆﬂerte Maske wieder verkleinern
workMask = imfill (workMask, 'holes');                              % innere R‰ume werden gef¸llt

connCmp = bwconncomp(workMask);
maskAreas = regionprops(connCmp, 'Area');
areaSize=500;
areaIndex = find([maskAreas.Area]>areaSize);
% Wenn keine groﬂe Fl‰chen (> 500) nicht gefunden werden ->
% kleinere Fl‰chen zusammenschlieﬂen durch
% um 40 % vergrˆﬂern und wieder verkleinern
if isempty(areaIndex)
    seg1_pad = padarray(imresize(seg1, [200 200]), [50 50]);
    seg1_dil = imdilate (seg1_pad, ones(40,40), 'same');
    seg1_dil = imfill(seg1_dil, 'holes');
    seg2_pad = imerode (seg1_dil, ones(80,80), 'same');
    seg2 = imcrop(seg2_pad, [51 51 199 199]);
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

seg2 = imresize(seg2, [infoRef.Rows infoRef.Columns]);              % seg2 - inner SAT-Maske (Originale Grˆﬂe)



sub_FAT    = seg1.*~seg2.*double(body);                                 % SAT-Bild innerhalb der Maske

toc
tic
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
else
    workImage =  vis_FAT;
    small_workImage = imresize(workImage,[200 200]);                %-- make image smaller
    [~,mask]  = kmeans(int16(small_workImage),2);                   % K-MEANS image clustering (2 Stufen)
    workMask = mask==2;
    % Suchen Fl‰chen > 200 und gl‰tten (imdilate-imerode-imfill)
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
    % Nur eine - grˆﬂte - VAT-Maske lassen
    connCmp = bwconncomp(seg3);
    maskAreas = regionprops(connCmp, 'Area');
    if numel(maskAreas) > 1
        areaIndex = find ([maskAreas.Area] == max(cell2mat(struct2cell(maskAreas))));
        seg3 = ismember(labelmatrix(connCmp), areaIndex);
    end
    
    seg3 = imresize(seg3,[infoRef.Rows infoRef.Columns]);           % seg3 - VAT-Maske (Originale Grˆﬂe)
    
    kernel = ones(7,7);                                                     %
    seg3 = imdilate(seg3, kernel, 'same');                                  % um (7-2) = 5 Pts erweitern
    seg3 = seg3.*seg2;                                                      % (aber seg3 < seg2, d.h. VAT < iSAT)
    kernel = ones(2,2);                                                     %
    seg3 = imerode(seg3, kernel, 'same');                                   %
    
end
toc
end