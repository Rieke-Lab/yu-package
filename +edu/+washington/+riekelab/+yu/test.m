g = edu.washington.riekelab.yu.utils.createGratings(0.5,0.1,5,70);
%g1 = uint8(squeeze(g(2,:,:)).*255);
%imagesc(g1); colormap(gray); axis image; axis equal;
%imshow(g1);