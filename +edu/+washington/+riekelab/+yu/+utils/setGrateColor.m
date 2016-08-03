function c = setGrateColor( background, mean )
%SETGRATECOLOR Summary of this function goes here
%   Detailed explanation goes here
        if (mean < background)
            c = min(mean, (1-background));
        else c = min (background, (1-mean));
        end

end

