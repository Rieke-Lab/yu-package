classdef SplitFieldMoving < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 250 % ms
        stimTime = 2000 % ms
        tailTime = 250 % ms
        contrast_1 = -0.9 % relative to mean (0-1)
        contrast_2 = 0.2 % relative to mean(0-1)
        temporalFrequency = 4 % Hz
        apertureDiameter = 200 % um
        vertical = false;  % deg
        backgroundIntensity = 0.5 % (0-1)
        centerBias = 20 % x or y bias from center(um)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(1) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        %centerOffsetType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
    end
       
    properties (Hidden, Transient)
        analysisFigure
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                % custom figure handler
                if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
                    obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.F1F2_PSTH);
                    f = obj.analysisFigure.getFigureHandle();
                    set(f, 'Name', 'Cycle avg PSTH');
                    obj.analysisFigure.userData.runningTrace = 0;
                    obj.analysisFigure.userData.axesHandle = axes('Parent', f);
                else
                    obj.analysisFigure.userData.runningTrace = 0;
                end
            end
        end
        
        function F1F2_PSTH(obj, ~, epoch) %online analysis function
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            quantities = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            axesHandle = obj.analysisFigure.userData.axesHandle;
            runningTrace = obj.analysisFigure.userData.runningTrace;
            
            if strcmp(obj.onlineAnalysis,'extracellular') %spike recording
                filterSigma = (20/1000)*sampleRate; %msec -> dataPts
                newFilt = normpdf(1:10*filterSigma,10*filterSigma/2,filterSigma);
                res = edu.washington.riekelab.turner.utils.spikeDetectorOnline(quantities,[],sampleRate);
                epochResponseTrace = zeros(size(quantities));
                epochResponseTrace(res.sp) = 1; %spike binary
                epochResponseTrace = sampleRate*conv(epochResponseTrace,newFilt,'same'); %inst firing rate
            else %intracellular - Vclamp
                epochResponseTrace = quantities-mean(quantities(1:sampleRate*obj.preTime/1000)); %baseline
                if strcmp(obj.onlineAnalysis,'exc') %measuring exc
                    epochResponseTrace = epochResponseTrace./(-60-0); %conductance (nS), ballpark
                elseif strcmp(obj.onlineAnalysis,'inh') %measuring inh
                    epochResponseTrace = epochResponseTrace./(0-(-60)); %conductance (nS), ballpark
                end
            end
            
            noCycles = floor(obj.temporalFrequency*obj.stimTime/1000);
            period = (1/obj.temporalFrequency)*sampleRate; %data points
            epochResponseTrace(1:(sampleRate*obj.preTime/1000)) = []; %cut out prePts
            cycleAvgResp = 0;
            for c = 1:noCycles
                cycleAvgResp = cycleAvgResp + epochResponseTrace((c-1)*period+1:c*period);
            end
            cycleAvgResp = cycleAvgResp./noCycles;
            timeVector = (1:length(cycleAvgResp))./sampleRate; %sec
            runningTrace = runningTrace + cycleAvgResp;
            cla(axesHandle);
            h = line(timeVector, runningTrace./obj.numEpochsCompleted, 'Parent', axesHandle);
            set(h,'Color',[0 0 0],'LineWidth',2);
            xlabel(axesHandle,'Time (s)')
            title(axesHandle,'Running cycle average...')
            if strcmp(obj.onlineAnalysis,'extracellular')
                ylabel(axesHandle,'Spike rate (Hz)')
            else
                ylabel(axesHandle,'Resp (nS)')
            end
            obj.analysisFigure.userData.runningTrace = runningTrace;
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            centerBiasPix = obj.rig.getDevice('Stage').um2pix(obj.centerBias);
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create split-field stimulus
            splitFiledContrastMatrix = zeros(apertureDiameterPix)+obj.backgroundIntensity;
            scene = stage.builtin.stimuli.Image(uint8(splitFiledContrastMatrix.*255));
            scene.size = [apertureDiameterPix apertureDiameterPix];  %scale up to canvas size
            scene.position = canvasSize/2;
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            if (obj.temporalFrequency>0)
                sceneMatrix = stage.builtin.controllers.PropertyController(scene,'imageMatrix',...
                    @(state)getSceneMatrix(state.time - obj.preTime/1e3,obj.backgroundIntensity,obj.vertical,...
                    obj.temporalFrequency,obj.contrast_1, obj.contrast_2, centerBiasPix, apertureDiameterPix));
                p.addController(sceneMatrix);
            end
            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);
            % function to control temporal dynamics of the sceneMatrix
            function p = getSceneMatrix(time, background, vertical, freq, contrast1, contrast2, bias, sz)
                img = zeros(sz);
                if time>0
                    gain = cos(time*freq*pi*2);
                    img = img+contrast2*gain;
                    img(:, 1:floor(sz/2)+bias) = contrast1*gain;
                end
                p = img*background + background;
                p = uint8(p.*255);
                if (~vertical)
                    p = p';
                end 
            end
            % Create aperture
            if  (obj.apertureDiameter > 0) % Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [apertureDiameterPix, apertureDiameterPix];
                mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end

        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
        end
        
        %same presentation each epoch in a run. Replay.
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            if (obj.numEpochsCompleted >= 1) && (obj.numEpochsCompleted < obj.numberOfAverages)
                obj.rig.getDevice('Stage').replay
            else
                obj.rig.getDevice('Stage').play(obj.createPresentation());
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

