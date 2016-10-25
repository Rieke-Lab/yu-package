classdef NormCosLinearEquivalentDisc < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms 
        imageName = '00152' %van hateren image names
        startPatches = 30 %number of different image patches (fixations) to show
        noPatches = 3 % selected patch for stimulus
        selectMethod = 'default'
        frequency = 2 % alternating prequencies
        apertureDiameter = 200 % um
        linearIntegrationFunction = 'gaussian center'
        patchContrast = 'all'
        rfSigmaCenter = 50 % (um) Enter from fit RFmfilename('fullpath')mfilename('fullpath')
        centerOffset = [0, 0] % [x,y] (um)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(180) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        imageNameType = symphonyui.core.PropertyType('char', 'row', {'00152','00377','00405','00459','00657','01151','01154',...
            '01192','01769','01829','02265','02281','02733','02999','03093',...
            '03347','03447','03584','03758','03760'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        selectMethodType = symphonyui.core.PropertyType('char', 'row', {'default','ToSearch'})
        patchContrastType = symphonyui.core.PropertyType('char', 'row', {'all','negative','positive'})
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        centerOffsetType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        
        wholeImageMatrix
        imagePatchMatrix
        allEquivalentIntensityValues 
        patchLocations
        currentPatchNo
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
            contrastImage = (img - obj.backgroundIntensity) ./ obj.backgroundIntensity;
            img = img.*255; %rescale s.t. brightest point is maximum monitor level
            obj.wholeImageMatrix = uint8(img);
            
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* ...
                obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            stimSize_VHpix = stimSize ./ (3.3); %um / (um/pixel) -> pixel
            radX = round(stimSize_VHpix(1) / 2); %boundaries for fixation draws depend on stimulus size
            radY = round(stimSize_VHpix(2) / 2);
            
            %get patch locations:
            %1: search mode
            if(strcmpi(obj.selectMethod, 'ToSearch'))
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
            
            % may still need to set up the seed    
            %pull more than needed to account for empty bins at tail
            [~, ~, bin] = histcounts(responseDifferences,1.5*obj.noPatches);
             populatedBins = unique(bin);
                %pluck one patch from each bin
             pullInds = arrayfun(@(b) find(b == bin,1),populatedBins);
                %get patch indices:
             pullInds = randsample(pullInds,obj.noPatches);
                
            obj.patchLocations(1,1:obj.noPatches) = xLoc(pullInds); %in VH pixels
            obj.patchLocations(2,1:obj.noPatches) = yLoc(pullInds);
            subunitResp = subunitResp(pullInds);
            LnResp = LnResp(pullInds);
            responseDifferences = subunitResp - LnResp;
            obj.currentPatchNo = obj.startPatches; % go through all image patches first
            elseif (strcmpi(obj.selectMethod,'default'))
                 cur_Dir = mfilename('fullpath');
                 resource_loc = strcat(cur_Dir(1:strfind(cur_dir,'edu')-2),'resource\');
                 load ([resource_loc,obj.ImageName,'_sorted_locs.mat'])
                 obj.noPatches = min(obj.noPatches,size(inh_loc,1));
                 xLoc = inh_loc(1:obj.noPatches,1);
                 yLoc = inh_loc(1:obj.noPatches,2);
                 obj.patchLocations(1,1:obj.noPatches) = xLoc';
                 obj.patchLocations(2:1:obj.noPatches) = yLoc';
                 obj.currentPatchNo = obj.noPatches;
            end
            
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
            
            for ff = 1:obj.currentPatchNo
                tempPatch = contrastImage(round(obj.patchLocations(1,ff)-radX):round(obj.patchLocations(1,ff)+radX),...
                    round(obj.patchLocations(2,ff)-radY):round(obj.patchLocations(2,ff)+radY));
                % now the contrast are in [-1 1]
                tempPatch = edu.washington.riekelab.yu.utils.truncpic(tempPatch); 
                equivalentContrast = sum(sum(weightingFxn .* tempPatch));
                obj.allEquivalentIntensityValues(ff) = obj.backgroundIntensity + ...
                    equivalentContrast * obj.backgroundIntensity;
            end
        end
        
         function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            if (strcmpi(obj.selectMethod,'default'))
                % prepare the sinusoidal stimulation 
            elseif (strcmpi(obj.selectMethod, 'ToSearch'))
                % prepare for the searching steps
            end
            %pull patch location and equivalent contrast:
            obj.imagePatchIndex = floor(mod(obj.numEpochsCompleted/2,obj.noPatches) + 1);
            evenInd = mod(obj.numEpochsCompleted,2);
            if evenInd == 1 %even, show uniform linear equivalent intensity
                obj.stimulusTag = 'intensity';
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
%             figure(30); clf;
%             imagesc(obj.imagePatchMatrix); colormap(gray); axis image; axis equal;

            epoch.addParameter('currentStimSet', obj.currentStimSet);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('imagePatchIndex', obj.imagePatchIndex);
            epoch.addParameter('currentPatchLocation', obj.currentPatchLocation);
            epoch.addParameter('equivalentIntensity', obj.equivalentIntensity);
            epoch.addParameter('stimulusTag', obj.stimulusTag);
        end
    end
    
end

