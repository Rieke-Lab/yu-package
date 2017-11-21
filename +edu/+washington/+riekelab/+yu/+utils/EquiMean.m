function Intensity = EquiMean( SigmaC, image, Tag )
%EQUIMEAN equivalent intensity of a image
%   Detailed explanation goes here
   if strcmp(Tag,'gaussian center')
      RF = fspecial('gaussian',size(image),SigmaC);
      apertureMatrix = ones(size(image));
      weightingFxn = apertureMatrix .* RF;
      weightingFxn = weightingFxn ./ sum(weightingFxn(:)); %sum to one
      Intensity = sum(sum(weightingFxn .* double(image))); 
   elseif strcmp(Tag,'uniform')
      Intensity = mean(image(:));
   end

end

