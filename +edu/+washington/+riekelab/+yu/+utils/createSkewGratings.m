function gratingMatrix = createSkewGratings( height, offset,unitbarwidth,sz,pos_ratio)
%create skewed gratings with mean (offst)
% to achieve sum(pos_conctrast) == neg(contrast) -> bar width is scaled
    grating = ones(sz,sz); %  create an image array
    center = floor(sz/2)+1; % center of grating is 
    wave = sin((linspace(1,sz,sz)-center)*pi/(unitbarwidth));
    wave(wave>=0)=1;
    wave(wave<0)=-1;
    grating = ones(sz,1)*wave;
    gratingMatrix = grating*height+offset;
end

