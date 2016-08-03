classdef MeanPlusGrating < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % MeanPlusGrating: raise a mean value to grating stimuli
    % modified from Max's ContrastReversingGrating.m and
    % MeanPlusContrastimage.m
    
    % V1: manually set a mean value; bar width is determined by a array
    % input
    % Try to match stimulation parameter to those in
    % MeanPlusContrastImage.m for future comparison purpose
    
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        meanIntensity = 0.6 % (0-1)
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        barWidth = 20; % um
        rotation = 0; % deg
        backgroundIntensity = 0.5 % (0-1)
        centerOffset = [0, 0] % [x,y] (um)
       
        onlineAnalysis = 'none'
        numberOfAverages = uint16(20) % number of epochs to queue
        amp
    end
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentBarWidth
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        centerOffsetType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        
        % saved to each epoch
        stimulusTag
    end
       
    properties (Hidden, Transient)
        analysisFigure
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
                obj.showFigure('edu.washington.riekelab.turner.figures.MeanPlusContrastImageFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
            % Create bar width sequence.
            obj.barWidthSequence = obj.barWidth;
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* ...
                obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            stimSize_VHpix = stimSize ./ (3.3); %um / (um/pixel) -> pixel
            radX = round(stimSize_VHpix(1) / 2); %boundaries for fixation draws depend on stimulus size
            radY = round(stimSize_VHpix(2) / 2);
             %get equivalent intensity values:
            %   Get the model RF...
            sigmaC = obj.rfSigmaCenter ./ 3.3; %microns -> VH pixels
            RF = fspecial('gaussian',2.*[radX radY] + 1,sigmaC);

            %   get the aperture to apply to the image...
            %   set to 1 = values to be included (i.e. image is shown there)
            [rr, cc] = meshgrid(1:(2*radX+1),1:(2*radY+1));
            if obj.apertureDiameter > 0
                apertureMatrix = sqrt((rr-radX).^2 + ...
                    (cc-radY).^2) < (obj.apertureDiameter/2) ./ 3.3;
                apertureMatrix = apertureMatrix';
            else
                apertureMatrix = ones(2.*[radX radY] + 1);
            end
            
        end
        
         function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

            %pull patch location and equivalent contrast:
            obj.imagePatchIndex = floor(mod(obj.numEpochsCompleted/3,obj.noPatches) + 1);
            stimInd = mod(obj.numEpochsCompleted,3);
            if stimInd == 0 % show linear equivalent intensity
                obj.stimulusTag = 'intensity';
            elseif stimInd == 1 %  show remaining spatial contrast (image - intensity)
                obj.stimulusTag = 'contrast';
            elseif stimInd == 2 %  show image
                obj.stimulusTag = 'image';
            end
            
            obj.equivalentIntensity = obj.allEquivalentIntensityValues(obj.imagePatchIndex);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            %imagePatchMatrix is in VH pixels
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* ...
                obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            stimSize_VHpix = stimSize ./ (3.3); %um / (um/pixel) -> pixel
            radX = round(stimSize_VHpix(1) / 2); %boundaries for fixation draws depend on stimulus size
            radY = round(stimSize_VHpix(2) / 2);
            obj.imagePatchMatrix = obj.wholeImageMatrix(round(obj.currentPatchLocation(1)-radX):round(obj.currentPatchLocation(1)+radX),...
                round(obj.currentPatchLocation(2)-radY):round(obj.currentPatchLocation(2)+radY));
            obj.imagePatchMatrix = obj.imagePatchMatrix';
            
%             figure(30); clf;
%             imagesc(obj.imagePatchMatrix); colormap(gray); axis image; axis equal;

            epoch.addParameter('currentStimSet', obj.currentStimSet);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('imagePatchIndex', obj.imagePatchIndex);
            epoch.addParameter('currentPatchLocation', obj.currentPatchLocation);
            epoch.addParameter('equivalentIntensity', obj.equivalentIntensity);
            epoch.addParameter('stimulusTag', obj.stimulusTag);
        end
         
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            centerOffsetPix = obj.rig.getDevice('Stage').um2pix(obj.centerOffset);
            maskDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.maskDiameter);
            currentBarWidthPix = obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create grating stimulus.
            grate = stage.builtin.stimuli.Grating('square'); %square wave grating
            grate.orientation = obj.rotation;
            grate.size = [apertureDiameterPix, apertureDiameterPix];
            grate.position = canvasSize/2 + centerOffsetPix;
            grate.spatialFreq = 1/(2*currentBarWidthPix); %convert from bar width to spatial freq
            grate.color = 2*obj.backgroundIntensity;
            %calc to apply phase shift s.t. a contrast-reversing boundary
            %is in the center regardless of spatial frequency. Arbitrarily
            %say boundary should be positve to right and negative to left
            %crosses x axis from neg to pos every period from 0
            zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1); 
            offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
            [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
            phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
            phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
            grate.phase = phaseShift; %keep contrast reversing boundary in center
            p.addStimulus(grate);
            
            %make it contrast-reversing
            if (obj.temporalFrequency > 0) 
                grateContrast = stage.builtin.controllers.PropertyController(grate, 'contrast',...
                    @(state)getGrateContrast(obj, state.time - obj.preTime/1e3));
                p.addController(grateContrast); %add the controller
            end
            function c = getGrateContrast(obj, time)
                c = obj.contrast.*sin(2 * pi * obj.temporalFrequency * time);
            end
            
            if  (obj.apertureDiameter > 0) % Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2 + centerOffsetPix;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [apertureDiameterPix, apertureDiameterPix];
                mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
            if (obj.maskDiameter > 0) % Create mask
                mask = stage.builtin.stimuli.Ellipse();
                mask.position = canvasSize/2 + centerOffsetPix;
                mask.color = obj.backgroundIntensity;
                mask.radiusX = maskDiameterPix/2;
                mask.radiusY = maskDiameterPix/2;
                p.addStimulus(mask); %add mask
            end
            
            % hide during pre & post
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);
        end
        
    end
    
end

