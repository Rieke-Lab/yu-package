function [ equi_contrast, pos_contrast, neg_contrast] = getSplitContrast( SigmaC, sz, x_pos, min_c, Tag, pos)
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
    balanced_sum = sum(sum(weightingFxn(:, 1:x_pos).*min_c));
    pos_mat = sum(sum(weightingFxn(:,1:pos)));
    neg_mat = sum(sum(weightingFxn(:,pos+1:sz)));
    pos_contrast = balanced_sum/pos_mat;
    neg_contrast = -balanced_sum/neg_mat;
    equi_contrast = pos_contrast*pos_mat + neg_contrast*neg_mat;
end

