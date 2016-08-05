g = edu.washington.riekelab.yu.utils.createGratings(0.5,0.1,[-3 -10],70);
g1 = uint8(squeeze(g(2,:,:)).*255);
g11 = squeeze(g(1,:,:));
%imagesc(g1); colormap(gray); axis image; axis equal;
imshow(g1);
sigmaC = 20; %pseudo receiptive field center
%{
RF = fspecial('gaussian',2.*[35 35],20);
apertureMatrix = ones(2.*[35 35]);
weightingFxn = apertureMatrix .* RF;
weightingFxn = weightingFxn ./ sum(weightingFxn(:)); %sum to one
 equivalentContrast = sum(sum(weightingFxn .* double(g11)));
%}
edu.washington.riekelab.yu.utils.EquiMean(sigmaC, g11, 'gaussian center')
