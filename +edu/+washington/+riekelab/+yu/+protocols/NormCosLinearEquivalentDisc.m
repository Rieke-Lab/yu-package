classdef NormCosLinearEquivalentDisc < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms 
        imageName = '00152' %van hateren image names
        searchMode = 'On'
        startPatches = 30 %number of different image patches (fixations) to show
        noPatches = 3 % selected patch for stimulus
        displayMode = 'full' % alternating prequencies
        apertureDiameter = 200 % um
        linearIntegrationFunction = 'gaussian center'
        patchContrast = 'all'
        rfSigmaCenter = 50 % (um) Enter from fit RFmfilename('fullpath')mfilename('fullpath')
        centerOffset = [0, 0] % [x,y] (um)
        patchSampling = 'random'
        onlineAnalysis = 'none'
        numberOfAverages = uint16(180) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        imageNameType = symphonyui.core.PropertyType('char', 'row', {'00152','00377','00405','00459','00657','01151','01154',...
            '01192','01769','01829','02265','02281','02733','02999','03093',...
            '03347','03447','03584','03758','03760'})
        searchModeType = symphonyui.core.PropertyType('char','row',{'On','Off'})
        displayModeType = symphonyui.core.PropertyType('char','row',{'full','trunc'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        patchContrastType = symphonyui.core.PropertyType('char', 'row', {'all','negative','positive'})
        patchSamplingType = symphonyui.core.PropertyType('char', 'row', {'random','ranked'})
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        centerOffsetType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        
        wholeImageMatrix
        imagePatchMatrix
        allEquivalentIntensityValues 
        patchLocations
        currentPatchNo
        patchResponse
        searchTag % reduce during search steps
        % map current patch index to abs index
        currentPatchIndex % start from 30 patches;shrinking
        %saved out to each epoch...
        descentSeq % binary search pool size
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
            % read-in the image
            % prepare patch locations
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'stimulusTag'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
           
            % specify online analysis methods
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
            %contrastImage = (img - obj.backgroundIntensity) ./ obj.backgroundIntensity;
            %img = img.*255; %rescale s.t. brightest point is maximum monitor level
            
            obj.wholeImageMatrix = img;% uint8(img);
            
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* ...
                obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            stimSize_VHpix = stimSize ./ (3.3); %um / (um/pixel) -> pixel
            radX = round(stimSize_VHpix(1) / 2); %boundaries for fixation draws depend on stimulus size
            radY = round(stimSize_VHpix(2) / 2);
            
            load([resourcesDir,'NaturalImageFlashLibrary_072216.mat']);
            fieldName = ['imk', obj.imageName];
            %1) restrict to desired patch contrast:
            LnResp = imageData.(fieldName).LnModelResponse;
            if strcmp(obj.patchContrast,'all')
                inds = 1:length(LnResp);
            elseif strcmp(obj.patchContrast,'positive')
                inds = find(LnResp > 0);
            elseif strcmp(obj.patchContrast,'negative')
                inds = find(LnResp <= 0);
            end
            xLoc = imageData.(fieldName).location(inds,1);
            yLoc = imageData.(fieldName).location(inds,2);
            subunitResp = imageData.(fieldName).SubunitModelResponse(inds);
            LnResp = imageData.(fieldName).LnModelResponse(inds);
            
            %2) do patch sampling:
            responseDifferences = subunitResp - LnResp;
            if strcmp(obj.patchSampling,'random')
                %get patch indices:
                pullInds = randsample(1:length(xLoc),obj.startPatches);
            else strcmp(obj.patchSampling,'ranked')
                %pull more than needed to account for empty bins at tail
                [~, ~, bin] = histcounts(responseDifferences,1.5*obj.startPatches);
                populatedBins = unique(bin);
                %pluck one patch from each bin
                pullInds = arrayfun(@(b) find(b == bin,1),populatedBins);
                %get patch indices:
                pullInds = randsample(pullInds,obj.startPatches);
            end
            obj.patchLocations(1,1:obj.startPatches) = xLoc(pullInds); %in VH pixels
            obj.patchLocations(2,1:obj.startPatches) = yLoc(pullInds);
            subunitResp = subunitResp(pullInds);
            LnResp = LnResp(pullInds);
            responseDifferences = subunitResp - LnResp;
            
            obj.currentPatchNo = obj.startPatches; % go through all image patches first
            
%             figure(30); clf;
%             subplot(211); hist(responseDifferences,100);
%             subplot(212); plot(subunitResp,LnResp,'ko');
%             title('On model responses')
            
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
            %display(size(obj.patchLocations));
            for ff = 1:obj.startPatches
                tempPatch = obj.wholeImageMatrix(round(obj.patchLocations(1,ff)-radX):round(obj.patchLocations(1,ff)+radX),...
                    round(obj.patchLocations(2,ff)-radY):round(obj.patchLocations(2,ff)+radY));
                if strcmp(obj.displayMode,'trunc')
                % now the contrast are in [-1 1]
                 tempPatch = edu.washington.riekelab.yu.utils.truncpic(tempPatch, obj.backgroundIntensity); 
                end
                tempPatch = (tempPatch - obj.backgroundIntensity)/obj.backgroundIntensity;
                equivalentContrast = sum(sum(weightingFxn .* tempPatch));
                obj.allEquivalentIntensityValues(ff) = obj.backgroundIntensity + ...
                    equivalentContrast * obj.backgroundIntensity;
            end
            if strcmp(obj.searchMode,'Off')
                 obj.searchTag = 'Off';
                 % readin the index
                 cur_Dir = mfilename('fullpath');
                 resource_loc = strcat(cur_Dir(1:strfind(cur_Dir,'edu')-2),'resource\');
                 load ([resource_loc,obj.imageName,'temp_locs.mat']);
                 obj.currentPatchIndex = temp_locs;
            else obj.searchTag = 'On';
                 obj.currentPatchIndex = 1:obj.startPatches; % start from all image patches
                 searchRound = ceil(log2(obj.startPatches/obj.noPatches))+1;
                 obj.descentSeq = [];
               for i = 1:searchRound
                % generate a sequence so that we can map the current epoch
                % number into the search process
                  if i == 1
                     obj.descentSeq(i) = floor(obj.startPatches/(2^(i-1)));
                  else
                    if (floor(obj.startPatches/2^(i-1))>=obj.noPatches)
                     obj.descentSeq(i) = obj.descentSeq(i-1)+floor(obj.startPatches/(2^(i-1)));
                    else break;
                    end
                  end
               end
            obj.patchResponse = zeros(obj.startPatches,2); % store temporal mean results
            display(obj.descentSeq);
            end
        end
        
         function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            evenInd = mod(obj.numEpochsCompleted,2);
            epochInd = floor(obj.numEpochsCompleted/2)+1; 
            if evenInd == 1 %even, show uniform linear equivalent intensity
                obj.stimulusTag = 'intensity';
            elseif evenInd == 0 %odd, show image
                obj.stimulusTag = 'image';                
            end
            
            if (strcmpi(obj.searchTag,'On'))
                % search state 
                roundInd = find(obj.descentSeq >=epochInd,1); 
                if roundInd == 1
                    obj.imagePatchIndex = epochInd;
                else
                    obj.imagePatchIndex = epochInd - obj.descentSeq(roundInd-1); 
                end
           
            elseif strcmpi(obj.searchMode,'Off')
                 obj.imagePatchIndex = mod(epochInd,length(obj.currentPatchIndex))+1;
            elseif (strcmpi(obj.searchTag, 'Off'))
                % prepre for rendering the targeted group of responses
                 obj.imagePatchIndex = mod(epochInd - obj.descentSeq(end),obj.noPatches)+1;
            end
            %map to the current poll of image patches
            %display(size(obj.currentPatchIndex));
            obj.imagePatchIndex = obj.currentPatchIndex(obj.imagePatchIndex);
            
            %display('obj.imagePatchIndex:');
            %display(obj.imagePatchIndex);
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
            if strcmp(obj.displayMode,'trunc')
             obj.imagePatchMatrix = edu.washington.riekelab.yu.utils.truncpic(obj.imagePatchMatrix,obj.backgroundIntensity);
            end
            obj.imagePatchMatrix = obj.imagePatchMatrix.*255;
            obj.imagePatchMatrix = uint8(obj.imagePatchMatrix);
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
        
        function completeEpoch(obj, epoch)
            % store differences between disc responses and patch responses
            % and generate the next  currentPatchIndex if necessary
            % determine if the search Tag is still on
            completeEpoch@symphonyui.core.Protocol(obj,epoch);
            if (strcmp(obj.searchMode,'Off'))
                 obj.searchTag = 'Off';
                %display('off_confirmed');
            elseif (obj.numEpochsCompleted > 2*obj.descentSeq(end))
                 obj.searchTag = 'Off';
            else absPatchLoc = obj.imagePatchIndex; % absolute location of patch
                 response = epoch.getResponse(obj.rig.getDevice(obj.amp));
                 sampleRate = response.sampleRate.quantityInBaseUnits;
                 prePts = obj.preTime/1000*sampleRate;
                 stimPts = obj.stimTime/1000*sampleRate;
                 epochResponseTrace = response.getData();
                 epochResponseTrace = epochResponseTrace - mean(epochResponseTrace(1:prePts));
                 meanResp = mean(epochResponseTrace(prePts+1:prePts+stimPts));
                 % store average responses for each tag
                 if strcmp(obj.stimulusTag,'image')
                   obj.patchResponse(absPatchLoc,1) = obj.patchResponse(absPatchLoc,1)+meanResp;
                 elseif strcmp(obj.stimulusTag, 'intensity')
                   obj.patchResponse(absPatchLoc,2) = meanResp+obj.patchResponse(absPatchLoc,2);
                 end
                 % decide whether need to establish new set
                 epochInd = floor((obj.numEpochsCompleted-1)/2)+1;
                 %display('epochInd');
                 %display(epochInd);
                 if (length(find(obj.descentSeq==epochInd))>0)&&(mod(obj.numEpochsCompleted,2)==0)
                     % now need to update obj.currentPatchIndex
                     r = find(obj.descentSeq==epochInd,1);
                     if r == length(obj.descentSeq)
                         % search finished
                         tempPatchIndex = ones(obj.noPatches,1);
                          obj.searchTag = 'Off';
                         display('searchoff');
                          % can save temporal searched image locations
                          % later
                     else
                         if (obj.descentSeq(r+1)-obj.descentSeq(r))>obj.noPatches
                         tempPatchIndex = ones(obj.descentSeq(r+1)-obj.descentSeq(r),1);
                         else tempPatchIndex = ones(obj.noPatches,1);
                         end
                     end
                     [B,tempInd] = sort(abs(obj.patchResponse(:,1))-abs(obj.patchResponse(:,2)),'descend');
                     tempPatchIndex = tempInd(1:length(tempPatchIndex));
                     obj.currentPatchIndex = tempPatchIndex;
                 end
                 if strcmp(obj.searchTag,'Off')
                     % store results
                    cur_Dir = mfilename('fullpath');
                    resource_loc = strcat(cur_Dir(1:strfind(cur_Dir,'edu')-2),'resource\');
                    save([resource_loc,obj.imageName,'temp_locs.mat']);
                    temp_locs = obj.currentPatchIndex;
                    save([resource_loc,obj.imageName,'temp_locs.mat'],'temp_locs');
                 end
                     
            end
        end
        %{
        function tf = shouldWaitToContinuePreparingEpochs(obj)
            while (obj.numEpochsCompleted < obj.numEpochsPrepared)
                tf = true;
                pause(0.01);
            end
            tf  = false;
         end
        %}
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
end

