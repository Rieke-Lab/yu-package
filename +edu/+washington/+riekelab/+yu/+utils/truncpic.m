function trunc_img = truncpic( img, b )
%TRUNCPIC recenter the image, so that the contrast will fall in between
%[-1,1], centerd at the same mean
%   Detailed explanation goes here
  p_min = min((img(:)));

  img(img>2*b) = 2*b; % anything has contrast>1 equals1
  img(img<b) = b-(img(img<b)-b)/(p_min-b)*b;
  trunc_img = img;
end

