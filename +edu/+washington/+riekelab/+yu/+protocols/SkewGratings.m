classdef SkewGratings < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % SkewGratings: modify the skewness of images, evenBars -> equivalent
    % disc -> skewed_bars1 -> disc
    % Detailed explaination:
    % constrains:
    %(1) count(pos_contrast)*pos_contrast+count(neg_contrast)*neg_contrast = 0
    %(2) symmertry
    %(3) base bar size not too small
    % for simplicity user supply ratio of barwidth
    % either fix the neg_contrast:-0.9, shift the positive contrast from
    % 0.1 - 0.9
    % or fix the pos_contrast:0.9, shift the negative contrast from [-0.1 -
    % 0.9]
    
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        meanIntensity = 0.6 % (0-1), uniform
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        barWidth = [20,40,80,160]; % bar width array um
        backgroundIntensity = 0.5 % (0-1)
        contrast_step = [0.9,0.2,0.4,0.6,0.9] % 
        %centerOffset = [0, 0] % [x,y] (um)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(40) % number of epochs to queue
        linearIntegrationFunction = 'gaussian center' % small error due to pixel int
        maskDiameter = 0; % place holder
        amp
    end
    
    methods
    end
    
end

