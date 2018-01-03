classdef searchFigure < symphonyui.core.FigureHandler
    %SEARCHFIGURE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        ampDevice
        groups
        recordingType
    end
    
    properties (Access = private)
        axesHandle
        sweeps
        sweepIndex
        storedSweep
        plotTable
        dataTable
    end
    
    methods
        function obj = MeanResponseFigure(ampdevice, varargin)
            ip = inputParser();
            ip.addParameter('groupBy', [], @(x)iscellstr(x));
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('groups',1,@(x)isnumeric(x));
            ip.parse(varargin{:});
            
            obj.ampDevice = ampdevice;
            obj.groups = ip.Results.groups;
            obj.recordingType = ip.Results.recordingType;            
            obj.createUi();
            obj.plotTable = cell2table(cell(0,3),'VariableNames',{'seed' 'Sigma' 'Color'});
            obj.dataTable = cell2table(cell(0,6),'VariableNames',{'seed' 'Sigma' 'angle' 'mean' 'var' 'trials' 'Color'});
        end
        
        function createUi(obj)
            import appbox.*;

            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'rotation angle');
            ylabel(obj.axesHandle, 'Amplitude(pA)');
            title(obj.axesHandle,'Rotation stimulus');
        end
        
        function handleEpoch(obj, epoch)
            plotcolors = 'bgrkymc';
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            currentAngle = epoch.parameters('currentAngle');
            currentSigma = epoch.parameters('currentSigma');
            currentSeed = epoch.parameters('currentSeed');
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            if strcmp(obj.recordingType,'extracellular') %spike recording
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = length(S.sp); %spike count
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
                %charge transfer
                if strcmp(obj.recordingType,'exc') %measuring exc
                    chargeMult = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    chargeMult = 1;
                end
                newEpochResponse = chargeMult*mean(epochResponseTrace); %pA*datapoint
            end
            
            pcolor = 1;
            
            if (size(obj.plotTable,1)== 0)
                recordPlot = {currentSeed, currentSigma, 1};
                obj.plotTable = [obj.plotTable;recordPlot];
            else
                lastrecord = obj.plotTable(obj.plotTable.seed==currentSeed && ...
                    obj.plotTable.Sigma ==currentSigma,:);
                if size(lastrecord,1)==0
                    % the record is new
                    recordPlot = {currentSeed, currentSigma, max(obj.plotTables.Color)+1};
                    pcolor = recordPlot{3};
                    obj.plotTable = [obj.plotTable;recordPlot];
                else
                    pcolor = lastrecord.Color;
                end
            end
            
            lastData = obj.dataTable(obj.dataTable.seed == currentSeed && ...
                obj.dataTable.Sigma == currentSitma && obj.angle == currentAngle);
            if (size(lastData,1)==0)
                % new record
                recordData = {currentSeed,currentSigma, currentAngle, newEpochResponse,0,1,pcolor};
                obj.dataTable = [obj.dataTable;recordData];
            else
                meanResp = (lastData.mean*lastData.trials+newEpochResponse)/(lastData.trials+1);
                var = ((lastData.var+lastData.mean^2)*lastData.trials+newEpochResonse^2)/...
                    (lastData.trials+1)-meanResp^2;
                trial = lastData.trials+1;
                
            end
            recordData = {currentSeed,currentSigma,currentAngle,newEpochResponse,...
                'seed' 'Sigma' 'angle' 'mean' 'var' 'trials' 'Color'};
        end
    end
end

