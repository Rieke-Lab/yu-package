function gratingMatrix = createSkewGratings(offset,unitbarwidth,sz,pos_num, neg_num,pos_center)
% create bar graph with different distribution 
% Detailed explanation goes here
% offset the mean
% neg_num:negative bar size(number of unit barwidth) 
% pos_num: positive bar size(number of unit barwidth)
% pos_center: True: center bars are positive contrast, False: center bars
% are negative contrast (if true then pos_num must be even, if false the
% neg_num must be even)
% unitbarwidth: the minimum bar width here, the center bar width is twice
% as the unitbarwidth
    center = floor(sz/2)+1; % center of grating
    wave = ones(1,sz);
    pt = center;
    if (pos_center)
        pos_tag = 1;
        while (pt <=sz)
            if (pt==center)
                wave(pt-pos_num/2*unitbarwidth:pt+pos_num/2*unitbarwidth) = 1;
                pt = pt + pos_num/2*unitbarwidth;
                pos_tag = 0;
            elseif(pos_tag)
                wave(pt:min(sz,pt+pos_num*unitbarwidth)) = 1;
                wave(max(1, 2*center-pt-pos_num*unitbarwidth):2*center-pt)=1;
                pt = pt + pos_num*unitbarwidth;
                pos_tag = 0;
            elseif(~pos_tag)
                wave(pt:min(sz,pt+neg_num*unitbarwidth)) = -1;
                wave(max(1, 2*center-pt-neg_num*unitbarwidth):2*center-pt)= -1;
                pt = pt + neg_num*unitbarwidth;
                pos_tag = 1;
            end   
        end
    else
        while(pt<=sz)
            if(pt==center)
                wave(pt-neg_num/2*unitbarwidth:pt+neg_num/2*unitbarwidth)=-1;
                pt = pt+neg_num/2*unitbarwidth;
                pos_tag = 1;
            elseif(pos_tag)
                wave(pt:min(sz,pt+pos_num*unitbarwidth)) = 1;
                wave(max(1, 2*center-pt-pos_num*unitbarwidth):2*center-pt)=1;
                pt = pt + pos_num*unitbarwidth;
                pos_tag = 0;
            elseif(~pos_tag)
                wave(pt:min(sz,pt+neg_num*unitbarwidth)) = -1;
                wave(max(1, 2*center-pt-neg_num*unitbarwidth):2*center-pt)= -1;
                pt = pt + neg_num*unitbarwidth;
                pos_tag = 1;
            end
        end
        
    end
    
    grating = ones(sz,1)*wave;
    gratingMatrix = grating;
    if (pos_num>neg_num)
        gratingMatrix(gratingMatrix<0) = -offset*0.9; % all negative pixels become -0.9 contrast
        pos_contra = -sum(sum(gratingMatrix(gratingMatrix<0)))/sum(sum(gratingMatrix>0));
        gratingMatrix(gratingMatrix>0) = pos_contra;
    else
        gratingMatrix(gratingMatrix>0) = offset*0.9;
        neg_contra = -sum(sum(gratingMatrix(gratingMatrix>0)))/sum(sum(gratingMatrix<0));
        gratingMatrix(gratingMatrix<0) = neg_contra;
    end
    gratingMatrix = gratingMatrix + offset;

end


