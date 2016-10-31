function trunc_img = truncpic( img, b )
%TRUNCPIC recenter the image, so that the contrast will fall in between
%[-1,1], centerd at the same mean
%   Detailed explanation goes here
  m1 = mean(img(:));
  p_min = min(img(:));

  img(img>2*b) = 2*b; % anything has contrast>1 equals1
  img(img<b) = b-(img(img<b)-b)/(p_min-b)*b;
  m2 = mean(img(:));
  if (m1-b)*(m2-b)<1
     % if the rescaling change the polarity of mean;
     % flip along the background
    trunc_img = 2*b-img;
   else trunc_img = img;
  end
    
end

