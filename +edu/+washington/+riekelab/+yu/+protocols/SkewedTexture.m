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
        textureSeed = 1
        centerSigma = 60 % texture sigma
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        onlineAnalysis = 'none'
        numberOfAverages = uint16(120) % number of epochs to queue
        maskDiameter = 0; % place holder
        amp
    end
    
    properties (Hidden)
        ampType
        imageNameType = symphonyui.core.PropertyType('char', 'row',...
            {'00152','01151'});
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        stimulusTag
        % image related
        wholeImageMatrix
        allEquivalentIntensityValues
        patchLocations
        % texture related
        pixelPercentile
        centerTexture
        % the one to display
        imagePatchMatrix
        
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
             prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'stimulusTag'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.ImageVsIntensityFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
            % TODO
            % get 30 patch locations
            % caclulate equivalent intensity
            % generate base textures
            %
        end
        
         function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            % TODO
            % retrive the base image index
            % according to stimulusTag, generate the image to display
         end
        
         function p = createPresentation(obj)
         end
          
         function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
         end
        
         function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
         end
    end
    
end

