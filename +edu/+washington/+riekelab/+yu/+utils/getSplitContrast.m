function [ equi_contrast, pos_contrast, neg_contrast] = getSplitContrast( SigmaC, sz, x_pos, min_c, tag,pos)
%GETSPLITCONTRAST Summary of this function goes here
%   Detailed explanation goes here
     r = floor(sz/2);
    [rr, cc] = meshgrid(1:sz, 1:sz);
    apertureMatrix = sqrt((rr-r).^2 +(cc-r).^2) < r;
    if strcmp(Tag, 'gaussian center')
        RF = fspecial('gaussian', [sz, sz], SigmaC);
    elseif strcmp(Tag, 'uniform')
        RF = ones(sz, sz);
    end
    weightingFxn = apertureMatrix.* RF;
    weightingFxn = weightingFxn ./ sum(weightingFxn(:)); %sum to one

end

