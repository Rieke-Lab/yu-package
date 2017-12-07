classdef BalancedSkewSplitField < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    %BALANCEDSKEWSPLITFIELD Summary of this class goes here
    %   With similar goal as the SplitField. 
    % The difference here is c1_Hat*A1 remains constant
    
 %SKEWSPLITFIELD: modify the pixel distribution of splitfield stimulu
    % c1_hat*A1 = c2_hat*A2 (c_hat: rec field adjusted contrast, A1:area)
    
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        backgroundIntensity = 0.5 % (0-1)
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        minAbsContrast = 0.3 %(0 - 1)
        maxAbsContrast = 0.9 %(0 - 1)
        numSteps = 5 % must be odd number to get half field
        vertical = true
        onlineAnalysis = 'none'
        numberOfAverages = uint16(40) % number of epochs to queue
        linearIntegrationFunction = 'gaussian center' % small error due to pixel int
        maskDiameter = 0; % place holder
        amp
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        pos_seq % all in units of pixels
        delta_x
        delta_y
        posContrast
        negContrast
        contras % left and right field contrast
        %stimulusTag
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
                'groupBy',{'contras'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.yu.figures.MeanPlusGratingFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
            
            obj.pos_seq = ones(obj.numSteps,1);
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            sigmaC = obj.rfSigmaCenter ./ 3.3;
            [equi_contrast, pos_right] = edu.washington.riekelab.yu.utils.getDeltapos(sigmaC, apertureDiameterPix,...
                -obj.minAbsContrast, obj.maxAbsContrast, obj.linearIntegrationFunction);
            if equi_contrast > 0.05
                display('attention: equivalent contrast not canceled')
            end
            pos_left = apertureDiameterPix - pos_right; 
            obj.pos_seq = round(linspace(pos_left, pos_right, obj.numSteps));
            obj.posContrast(1) = obj.maxAbsContrast;
            obj.posContrast(obj.numSteps) = obj.minAbsContrast;
            obj.negContrast(1) = -obj.minAbsContrast;
            obj.negContrast(obj.numSteps) = -obj.maxAbsContrast;
            for i = 2:obj.numSteps-1
                % remember to add that to util
                [equi_contrast, obj.posContrast(i), obj.negContrast(i)] = edu.washington.riekelab.yu.utils.getSplitContrast(sigmaC, ...
                    apertureDiameterPix,pos_right, obj.minAbsContrast,obj.linearIntegrationFunction,...
                    obj.pos_seq(i));
                if equi_contrast > 0.05
                    display('attention: equivalent contrast not canceled')
                end
            end
            display(obj.posContrast);
            display(obj.negContrast);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            stimInd = mod(obj.numEpochsPrepared-1,2);
            contraInd = mod(floor((obj.numEpochsPrepared-1)/2), length(obj.posContrast))+1;
            if stimInd == 0 % show skewed split-field
                obj.contras = [obj.posContrast(contraInd), obj.negContrast(contraInd)];
            elseif stimInd == 1 %  show remaining spatial contrast (image - intensity)
                obj.contras = [obj.negContrast(contraInd),obj.posContrast(contraInd)];
            end
            
            if obj.vertical
                obj.delta_x = obj.pos_seq(contraInd);
                obj.delta_y = 0;
            else
                obj.delta_x = 0;
                obj.delta_y = obj.pos_seq(contraInd);
            end
            
            %
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('contras', obj.contras);
            epoch.addParameter('delta_x', obj.delta_x);
            epoch.addParameter('delta_y', obj.delta_y);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            splitFieldMatrix = zeros(apertureDiameterPix);
            d = max(obj.delta_x, obj.delta_y);
            d = max(d, apertureDiameterPix-d);
            if abs(obj.contras(1)) < abs(obj.contras(2))
                splitFieldMatrix(:,1:d) = obj.contras(1);
                splitFieldMatrix(:,d+1:apertureDiameterPix) = obj.contras(2);
            else
                splitFieldMatrix(:,1:apertureDiameterPix-d) = obj.contras(1);
                splitFieldMatrix(:,apertureDiameterPix-d+1:apertureDiameterPix) = obj.contras(2);
            end
            if obj.delta_y ~= 0
                splitFieldMatrix = splitFieldMatrix';
            end
            splitFieldMatrix = splitFieldMatrix*obj.backgroundIntensity+obj.backgroundIntensity;
            %display(min(splitFieldMatrix(:)));
            splitFieldMatrix = uint8(splitFieldMatrix.*255);
            scene = stage.builtin.stimuli.Image(splitFieldMatrix);
            scene.size = [apertureDiameterPix, apertureDiameterPix];
            scene.position = canvasSize/2;%+ centerOffsetPix;
            p.addStimulus(scene);
            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);
            
            if  (obj.apertureDiameter > 0) % Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;% + centerOffsetPix;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [apertureDiameterPix, apertureDiameterPix];
                mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
        end
         
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
end

