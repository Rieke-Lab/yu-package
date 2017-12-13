classdef SkewedTexture < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    %SKEWEDTEXTURE 
    % Show textures that wrapped in the same pixel value distribution as
    % natural images
    % Detailed explanation
    % First step: use stored image patches from 00152 and 01151
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        imageName = '00152' %van hateren image names
        linearIntegrationFunction = 'gaussian center'
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF

        onlineAnalysis = 'none'
        numberOfAverages = uint16(40) % number of epochs to queue
        maskDiameter = 0; % place holder
        amp
    end
    
    properties (Hidden)
        ampType
        imageNameType = symphonyui.core.PropertyType('char', 'row',...
            {'00152','01151'});
        
    end
    methods
    end
    
end

