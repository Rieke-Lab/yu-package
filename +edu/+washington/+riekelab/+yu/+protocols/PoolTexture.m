classdef PoolTexture < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    %POOLTEXTURE 
    %   go over series of texture stimulus(numSigma*numSeed) to find the
    %   best texture stimulus. 
    % parameters to alternate: 
    % 1. numSigma: number of differen center sigmas
    % 2. numSeed: different number of seeds to generate textures
    % 3. seedSampling: random, ordered - > random: random set of seeds;
    % ordered: allow the same set of seeds
    % 4. edgeSharpen: 'Off': just original texture
    % 'binary': texture became 0, 1 binary
    % 'on':image edge sharpened with imgsharpen method
    % 5. contrast: contrast of texture
    
    properties
        preTime = 200 %ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        numSigma = [15 30 40] %texture space
        angle = 45 %[0 - 180],fixed
        apertureDiameter = 200 % um
        background = 0.2
        numSeed = 3 % search range
        seedSampling = 'random'
        edgeSharpen = 'off'
        contrast = 1 %[0 1]
        centerOffset = [0, 0] % [x,y] (um)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(90) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        seedSamplingType = symphonyui.core.PropertyType('char','row',{'random','ordered'})
        edgeSharpenType = symphonyui.core.PropertyType('char','row',{'on','off','binary'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        centerOffsetType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        centerTexture
        %currentTextureMatrix
        currentAngle
        currentSeed
        currentSigma
        sigmaPixSeq
        seedSeq
        sharpenParams
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
                'groupBy',{'currentSeed'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
           % obj.showFigure('edu.washington.riekelab.yu.figures.searchFigure',obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,'groups',360/obj.angle);
            % make properiate texture input
            obj.sigmaPixSeq =  obj.rig.getDevice('Stage').um2pix(obj.numSigma);
            %display(obj.sigmaPixSeq)
            if ~strcmp(obj.seedSampling,'random')
                obj.seedSeq = 1:obj.numSeed;
            else obj.seedSeq = randi([1,100],1,obj.numSeed);
            end
            %obj.currentSeed = RandStream.shuffleSeed;
            %obj.centerTexture = edu.washington.riekelab.yu.utils.makeRecTextureMatrix(stimSize,...
            %        sigmaPix/2, obj.seed, obj.background, obj.contrast);
            %obj.centerTexture = uint8(obj.centerTexture .* 255)';
            %display(size(obj.centerTexture));
        end
        
        function prepareEpoch(obj, epoch)
             prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
             rnum = 360/obj.angle;
             rotate_id = mod(obj.numEpochsPrepared-1,rnum)+1;
             seedInd = mod(floor((obj.numEpochsPrepared-1)/rnum),obj.numSeed)+1;
             sz_Sigma = size(obj.numSigma,2);
             sigmaInd = mod(floor((obj.numEpochsPrepared-1)/rnum/obj.numSeed),sz_Sigma)+1;
             obj.currentAngle = rotate_id*obj.angle;
             obj.currentSeed = obj.seedSeq(seedInd);
             obj.currentSigma = obj.sigmaPixSeq(sigmaInd);
             display(strcat('current seed is:',num2str(obj.currentSeed),' current Sigma is:',num2str(obj.currentSigma)));
             stimSize = obj.rig.getDevice('Stage').getCanvasSize(); %um     
             obj.centerTexture = edu.washington.riekelab.yu.utils.makeRecTextureMatrix(stimSize,...
                    obj.currentSigma/2, obj.currentSeed, obj.background, obj.contrast);
             obj.centerTexture = imrotate(obj.centerTexture, obj.currentAngle, 'bilinear', 'crop');
             if strcmp(obj.edgeSharpen,'on')
                 radius = 15;
                 amount = 2;
                 threshold = 0.1;
                 obj.centerTexture = imsharpen(obj.centerTexture,'Radius',radius,'Amount',amount,'Threshold',threshold);
                 obj.sharpenParams.Radius = radius;
                 obj.sharpenParams.Amount = amount;
                 obj.sharpenParams.Threshold= threshold;
             elseif strcmp(obj.edgeSharpen,'binary')
                 obj.centerTexture(obj.centerTexture<obj.background) = 0;
                 obj.centerTexture(obj.centerTexture>obj.background) = obj.background*2;
             end
             obj.centerTexture = uint8(obj.centerTexture .* 255)';
             device = obj.rig.getDevice(obj.amp);
             duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
             epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
             epoch.addResponse(device);
             epoch.addParameter('currentSeed',obj.currentSeed);
             epoch.addParameter('currentSigma',obj.currentSigma);
             epoch.addParameter('currentAngle',obj.currentAngle);
             epoch.addParameter('edgeShapren',obj.edgeSharpen);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            centerOffsetPix = obj.rig.getDevice('Stage').um2pix(obj.centerOffset);
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.background);
            scene = stage.builtin.stimuli.Image(obj.centerTexture);
            scene.size = canvasSize; %scale up to canvas size
            scene.position = canvasSize/2 + centerOffsetPix;
                % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);
            if (obj.apertureDiameter > 0) %% Create aperture
               aperture = stage.builtin.stimuli.Rectangle();
               aperture.position = canvasSize/2 + centerOffsetPix;
               aperture.color = obj.background;
               aperture.size = [max(canvasSize) max(canvasSize)];
               mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
               %display(apertureDiameterPix/max(canvasSize));
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

