classdef cImage
    properties
        name = '';
        date = '';
        datenum = '';
        path = '';
        nr = '';
        imgType = '';
        data = int16([]);
        pVersion_cImage = '1';
    end
    
    methods
        function RGBimg = conv2RGB(img);
            % scale max is the maximum value the resulting image will have
            data = cat(3, img.data, img.data, img.data);
            RGBimg = img;
            RGBimg.data = data;
        end

        function imgData = dataResize(img, scale)
            imgData = imresize(img.data, scale, 'nearest');
        end
        
        function img = scale2(img, scaleMinMax)
            Min = scaleMinMax(1);
            Max = scaleMinMax(2);
            im = double(img.data);
            switch numel(size(im))
                case 2
                    im = im+(Min-min(min(im)));
                    range = max(max(im)) - min(min(im));
                    im = im./range.*Max;
                case 3
                    im = im+(Min-min(min(min(im))));
                    range = max(max(max(im))) - min(min(min(im)));
                    im = im./range.*Max;
                otherwise
                    msgbox('image has wrong dimensionality');
                    return
            end
            img.data = cast(im, 'like', img.data);
        end
        
        function d = update_cControlVersionInfo(img, d)
            sc = superclasses(class(img));
            sc = [{class(img)}; sc];
            for i = 1:numel(sc)
                d.mSetVersionInfo(sc{i}, img.(['pVersion_' sc{i}]), ['mUpdate_' sc{i}]);
                %                     removed at 20170228
                %                     d.setVersionInfo('img', tabDat(1).imgs(1).img_version, ['update' sc{1}]);
                %                     d.setVersionInfo(tabDat(1).imgs(1).imgChild1_name, tabDat(1).imgs(1).imgChild1_version, ['update' class(tabDat(1).imgs(1))]);
            end
        end
        
        function img = cImage(path)
           
        end
    end
end
