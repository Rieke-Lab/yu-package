function [equi_C, delta_pos] = getDeltapos( SigmaC, sz, pos_contrast, neg_contrast, Tag )
%calclate the translation needed to achieve balanced splitfield
% A: area
% A1: pos_contrast area; A2: neg_contrast area
% A1*pos_contrast_hat = A2*neg_contrast_hat
% A/2*equi_C = A1*pos_contrast_hat
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
    % use search method to find minimum contrast difference point
    % initialize
    delta_pos = 0;
    abs_diff = abs((pos_contrast - neg_contrast)*sz*sz);
    % find the minimal difference point
    for i = floor(sz/2):sz
        mat = zeros(sz, sz);
        mat(:,1:i) = min(abs(pos_contrast), abs(neg_contrast));
        mat(:,i+1:sz) = max(abs(pos_contrast), abs(neg_contrast));
        mat = mat.*weightingFxn;
        diff = abs(sum(sum(mat(:,1:i))) - sum(sum(mat(:,i+1:sz))));
        if diff < abs_diff
            abs_diff = diff;
            delta_pos = i;
        end
    end
    % sanity check: equivalent contrast should be very small
    s_mat = zeros(sz, sz);
    if abs(pos_contrast) < abs(neg_contrast)
        sign = 1;
    else
        sign = -1;
    end
    s_mat(:,1:delta_pos) = sign*min(abs(pos_contrast), abs(neg_contrast));
    s_mat(:, delta_pos+1:sz) =  -sign*max(abs(pos_contrast), abs(neg_contrast));
    equi_C = sum(sum(weightingFxn .* s_mat));
end


