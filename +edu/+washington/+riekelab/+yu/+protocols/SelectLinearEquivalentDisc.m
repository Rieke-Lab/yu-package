classdef SelectLinearEquivalentDisc < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        imageName = '00152' %van hateren image names
        noPatches = 5 %number of different image patches (fixations) to show; <10
        apertureDiameter = 200 % um
        linearIntegrationFunction = 'gaussian center'
        patchSampling = 'Inh'
        rfSigmaCenter = 50 % (um) Enter from fit RF
        rotation = 0 % counterclock
        centerOffset = [0, 0] % [x,y] (um)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(180) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        imageNameType = symphonyui.core.PropertyType('char', 'row', {'00152','01151'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        patchSamplingType = symphonyui.core.PropertyType('char', 'row', {'Inh','Exc','Spikes'})
        %patchContrastType = symphonyui.core.PropertyType('char', 'row', {'all','negative','positive'})
        %sampleMethodType = symphonyui.core.PropertyType('char','row',{'default','calculated'})
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        centerOffsetType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        
        wholeImageMatrix
        imagePatchMatrix
        allEquivalentIntensityValues
        patchLocations
        
        %saved out to each epoch...
        currentStimSet
        backgroundIntensity
        imagePatchIndex
        currentPatchLocation
        equivalentIntensity
        stimulusTag
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
            
            %load appropriate image...
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentStimSet = '/VHsubsample_20160105';
            fileId=fopen([resourcesDir, obj.currentStimSet, '/imk', obj.imageName,'.iml'],'rb','ieee-be');
            img = fread(fileId, [1536,1024], 'uint16');
           
            img = double(img);
            img = (img./max(img(:))); %rescale s.t. brightest point is maximum monitor level
            obj.backgroundIntensity = mean(img(:));%set the mean to the mean over the image
            contrastImage = (img - obj.backgroundIntensity) ./ obj.backgroundIntensity;
            img = img.*255; %rescale s.t. brightest point is maximum monitor level
            obj.wholeImageMatrix = uint8(img);
            %rng(obj.seed); %set random seed for fixation draw
            
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* ...
                obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            stimSize_VHpix = stimSize ./ (3.3); %um / (um/pixel) -> pixel
            radX = round(stimSize_VHpix(1) / 2); %boundaries for fixation draws depend on stimulus size
            radY = round(stimSize_VHpix(2) / 2);
            
            %get patch locations: store here 1 - 10 different patches
            %load([resourcesDir,'NaturalImageFlashLibrary_072216.mat']);
            %fieldName = ['imk', obj.imageName];
            %1) restrict to desired patch contrast:
            %LnResp = imageData.(fieldName).LnModelResponse;
            cur_Dir = mfilename('fullpath');
            resource_loc = strcat(cur_Dir(1:strfind(cur_Dir,'edu')-2),'resource\');
            %display(resource_loc);
            % default, select patches that has been calculated...
                % based on other cells to give most different inh,exc, spikes
                %display([resource_loc,obj.imageName,'_sorted_locs.mat']);
                load ([resource_loc,obj.imageName,'_sorted_locs.mat'])
             %display('matrix');
              if strcmp(obj.patchSampling,'Inh')
                  obj.noPatches = min(obj.noPatches,size(inh_loc,1));
                   obj.patchLocations(1,1:obj.noPatches) = inh_loc(1:obj.noPatches,1)';
                  obj.patchLocations(2,1:obj.noPatches) = inh_loc(1:obj.noPatches,2)';
              elseif strcmp(obj.patchSampling,'Exc')
                  obj.noPatches = min(obj.noPatches,size(exc_loc,1));
                   obj.patchLocations(1,1:obj.noPatches) = exc_loc(1:obj.noPatches,1)';
                   obj.patchLocations(2,1:obj.noPatches) = exc_loc(1:obj.noPatches,2)';
              elseif strcmp(obj.patchSampling,'Spikes')
                  obj.noPatches = min(obj.noPatches,size(spike_loc,1));
                obj.patchLocations(1,1:obj.noPatches) = spike_loc(1:obj.noPatches,1)';
                   obj.patchLocations(2,1:obj.noPatches) = spike_loc(1:obj.noPatches,2)';
              end
     
           % obj.patchLocations(1,1:obj.noPatches) = xLoc';
           % obj.patchLocations(2:1:obj.noPatches) = yLoc';
            
            
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
            if strcmp(obj.linearIntegrationFunction,'gaussian center')
                weightingFxn = apertureMatrix .* RF; %set to zero mean gray pixels
            elseif strcmp(obj.linearIntegrationFunction,'uniform')
                weightingFxn = apertureMatrix;
            end
            weightingFxn = weightingFxn ./ sum(weightingFxn(:)); %sum to one
            
            for ff = 1:obj.noPatches
                %display(size(obj.patchLocations));
                tempPatch = contrastImage(round(obj.patchLocations(1,ff)-radX):round(obj.patchLocations(1,ff)+radX),...
                    round(obj.patchLocations(2,ff)-radY):round(obj.patchLocations(2,ff)+radY));
                equivalentContrast = sum(sum(weightingFxn .* tempPatch));
                obj.allEquivalentIntensityValues(ff) = obj.backgroundIntensity + ...
                    equivalentContrast * obj.backgroundIntensity;
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

            %pull patch location and equivalent contrast:
            obj.imagePatchIndex = floor(mod(obj.numEpochsCompleted/2,obj.noPatches) + 1);
            evenInd = mod(obj.numEpochsCompleted,2);
            if evenInd == 1 %even, show uniform linear equivalent intensity
                obj.stimulusTag = 'intensity';
                %display('intensity');
            elseif evenInd == 0 %odd, show image
                obj.stimulusTag = 'image';
            end
            
            obj.currentPatchLocation(1) = obj.patchLocations(1,obj.imagePatchIndex); %in VH pixels
            obj.currentPatchLocation(2) = obj.patchLocations(2,obj.imagePatchIndex);
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
            radX = stimSize_VHpix(1) / 2; %boundaries for fixation draws depend on stimulus size
            radY = stimSize_VHpix(2) / 2;
            obj.imagePatchMatrix = obj.wholeImageMatrix(round(obj.currentPatchLocation(1)-radX):round(obj.currentPatchLocation(1)+radX),...
                round(obj.currentPatchLocation(2)-radY):round(obj.currentPatchLocation(2)+radY));
            obj.imagePatchMatrix = obj.imagePatchMatrix';
            obj.imagePatchMatrix = imrotate(obj.imagePatchMatrix, obj.rotation, 'loose');
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
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            centerOffsetPix = obj.rig.getDevice('Stage').um2pix(obj.centerOffset);

            if strcmp(obj.stimulusTag,'image')
                scene = stage.builtin.stimuli.Image(obj.imagePatchMatrix);
                scene.size = canvasSize; %scale up to canvas size
                scene.position = canvasSize/2 + centerOffsetPix;
                % Use linear interpolation when scaling the image.
                scene.setMinFunction(GL.LINEAR);
                scene.setMagFunction(GL.LINEAR);
                p.addStimulus(scene);
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
            elseif strcmp(obj.stimulusTag,'intensity')
                %display( obj.equivalentIntensity);
                scene = stage.builtin.stimuli.Rectangle();
                scene.size = canvasSize;
                scene.color = obj.equivalentIntensity;
                scene.position = canvasSize/2 + centerOffsetPix;
                p.addStimulus(scene);
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
            end
            
            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2 + centerOffsetPix;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
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