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
        backgroundIntensity = 0.5 % (0-1)
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        unitWidth = 20 %(um) the unit bar width
        barWidth_unit = [2,1,4,3]; % even-odd bar width in units 
        onlineAnalysis = 'none'
        numberOfAverages = uint16(40) % number of epochs to queue
        linearIntegrationFunction = 'gaussian center' % small error due to pixel int
        maskDiameter = 0; % place holder
        equivalentDisc = 'on' % alternating with equivalent discs
        amp
    end
    
      properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentPosBarWidth
        currentNegBarWidth
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        centerOffsetType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        equivalentDiscType = symphonyui.core.PropertyType('char','row',{'on', 'off'})
        % barWidthSequence
        % saved to each epoch
        stimulusTag
        equimean % equivalent intensity
        int_error = 0.03; % error space due to pixels are int
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
            obj.posBarWidthSeqeuence = obj.unitWidth.*obj.barWidth_unit;
            % negative contrast bar width sequence (switch every other
            % location)
            obj.negBarWidthSequence = obj.barWidth_unit;
            for i = 1:2:length(obj.unitWidth)
                obj.negBarWidthSequence(i) = obj.posBarWidthSequence(i+1);
                obj.negBarWidthSequence(i+1) = obj.posBarWidthSequence(i);
            end
                
            %obj.barWidthSequence = linspace(obj.minbarWidth,obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter)/2,obj.numBarwidth);
            %obj.barWidthSequence = ones(1,2*obj.numBarwidth);
            % alternating the dark and bright bars
            %obj.barWidthSequence(1:2:2*obj.numBarwidth) = linspace(obj.minbarWidth,obj.apertureDiameter/2,obj.numBarwidth);
            %obj.barWidthSequence(2:2:2*obj.numBarwidth) = -linspace(obj.minbarWidth,obj.apertureDiameter/2,obj.numBarwidth);
            
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            num_bars = length(obj.barWidth_unit);
            if strcmp(obj.equivalentDisc, 'on')
            % if we alternate between the equivalent disc and gratings
                stimInd = mod(obj.numEpochsPrepared - 1,2);
                if stimInd == 0 % show linear equivalent intensity
                    obj.stimulusTag = 'grating';
                elseif stimInd == 1 %  show remaining spatial contrast (image - intensity)
                    obj.stimulusTag = 'disc';
                end
                barindex = mode(floor((obj.numEpochsPrepared - 1)/2), num_bars)+1;
            else
                obj.stimulusTag = 'grating';
                barindex = mode(obj.numEpochsPrepared, num_bars)+1;
            end
            obj.currentPosBarWidth = obj.posBarWidthSeqeuence(barindex);
            obj.currentNegBarWidth = obj.negBarWidthSequence(barindex);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('stimulusTag', obj.stimulusTag);
            epoch.addParameter('currentPosBarWidth', obj.currentPosBarWidth);
            epoch.addParameter('currentNegBarWidth', obj.currentNegBarWidth);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            centerOffsetPix = obj.rig.getDevice('Stage').um2pix(obj.centerOffset);
            %maskDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.maskDiameter);
            currentBarWidthPix = obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end

