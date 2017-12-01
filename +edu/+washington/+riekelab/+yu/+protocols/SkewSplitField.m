classdef SkewSplitField < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    %SKEWSPLITFIELD: modify the pixel distribution of splitfield stimulu
    % c1_hat*A1 = c2_hat*A2 (c_hat: rec field adjusted contrast, A1:area)
    
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        backgroundIntensity = 0.5 % (0-1)
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        negContrast = -0.6 %(-1 - 0)
        posContrast = 0.9 %(0 - 1)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(12) % number of epochs to queue
        linearIntegrationFunction = 'gaussian center' % small error due to pixel int
        maskDiameter = 0; % place holder
        amp
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        stimulusTag % even or skewed
        delta_x
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
                obj.showFigure('edu.washington.riekelab.yu.figures.MeanPlusGratingFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            stimInd = mod(obj.numEpochsPrepared-1,2);
            if stimInd == 0 % show skewed split-field
                obj.stimulusTag = 'skewed';
            elseif stimInd == 1 %  show remaining spatial contrast (image - intensity)
                obj.stimulusTag = 'even';
            end
            %TODO: calculate delta_x
            
            %
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('stimulusTag', obj.stimulusTag);
            epoch.addParameter('delta_x', obj.delta_x);
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

