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
        contrast = 0.9 % relative to mean (0-1)
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        barWidth = [5 10 20 40 80 160] % um
        rotation = 0; % deg
        backgroundIntensity = 0.5 % (0-1)
        centerOffset = [0, 0] % [x,y] (um)
        randomizeOrder = false;
        onlineAnalysis = 'none'
        numberOfAverages = uint16(20) % number of epochs to queue
        amp
    end
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        barWidthSequence
        currentBarWidth
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
             if length(obj.barWidth) > 1
                 % What is pmkmp?
                colors = edu.washington.riekelab.yu.utils.pmkmp(length(obj.barWidth),'CubicYF');
            else
                colors = [0 0 0];
             end
             
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentBarWidth'},...
                'sweepColor',colors);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                % custom figure handler
                if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
                    obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CRGanalysis);
                    f = obj.analysisFigure.getFigureHandle();
                    set(f, 'Name', 'CRGs');
                    obj.analysisFigure.userData.trialCounts = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F1 = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F2 = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.axesHandle = axes('Parent', f);
                else
                    obj.analysisFigure.userData.trialCounts = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F1 = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F2 = zeros(size(obj.barWidth));
                end
                
            end
            % Create bar width sequence.
            obj.barWidthSequence = obj.barWidth;
        end
        
         function CRGanalysis(obj, ~, epoch) %online analysis function
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            axesHandle = obj.analysisFigure.userData.axesHandle;
            trialCounts = obj.analysisFigure.userData.trialCounts;
            F1 = obj.analysisFigure.userData.F1;
            F2 = obj.analysisFigure.userData.F2;
            
            if strcmp(obj.onlineAnalysis,'extracellular') %spike recording
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
                %count spikes
                S = edu.washington.riekelab.yu.utils.spikeDetectorOnline(epochResponseTrace);
                epochResponseTrace = zeros(size(epochResponseTrace));
                epochResponseTrace(S.sp) = 1; %spike binary
                
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
            end

            L = length(epochResponseTrace); %length of signal, datapoints
            X = abs(fft(epochResponseTrace));
            X = X(1:L/2);
            f = sampleRate*(0:L/2-1)/L; %freq - hz
            [~, F1ind] = min(abs(f-obj.temporalFrequency)); %find index of F1 and F2 frequencies
            [~, F2ind] = min(abs(f-2*obj.temporalFrequency));

            F1power = 2*X(F1ind); %pA^2/Hz for current rec, (spikes/sec)^2/Hz for spike rate
            F2power = 2*X(F2ind); %double b/c of symmetry about zero
            
            barInd = find(obj.currentBarWidth == obj.barWidth);
            trialCounts(barInd) = trialCounts(barInd) + 1;
            F1(barInd) = F1(barInd) + F1power;
            F2(barInd) = F2(barInd) + F2power;
            
            cla(axesHandle);
            h1 = line(obj.barWidth, F1./trialCounts, 'Parent', axesHandle);
            set(h1,'Color','g','LineWidth',2,'Marker','o');
            h2 = line(obj.barWidth, F2./trialCounts, 'Parent', axesHandle);
            set(h2,'Color','r','LineWidth',2,'Marker','o');
            hl = legend(axesHandle,{'F1','F2'});
            xlabel(axesHandle,'Bar width (um)')
            ylabel(axesHandle,'Amplitude')

            obj.analysisFigure.userData.trialCounts = trialCounts;
            obj.analysisFigure.userData.F1 = F1;
            obj.analysisFigure.userData.F2 = F2;
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

