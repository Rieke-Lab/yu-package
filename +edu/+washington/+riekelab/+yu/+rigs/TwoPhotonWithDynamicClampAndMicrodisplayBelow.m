classdef TwoPhotonWithDynamicClampAndMicrodisplayBelow < symphonyui.core.descriptions.RigDescription

    methods

        function obj = TwoPhotonWithDynamicClampAndMicrodisplayBelow()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import edu.washington.*;

            daq = HekaDaqController();
            obj.daqController = daq;

            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
            
            ramps = containers.Map();
            ramps('minimum') = linspace(0, 65535, 256);
            ramps('low')     = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_low_gamma_ramp.txt'));
            ramps('medium')  = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_medium_gamma_ramp.txt'));
            ramps('high')    = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_high_gamma_ramp.txt'));
            ramps('maximum') = linspace(0, 65535, 256);
            microdisplay = riekelab.devices.MicrodisplayDevice('gammaRamps', ramps, 'micronsPerPixel', 1.8, 'comPort', 'COM3');
            microdisplay.bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(microdisplay, 15);
            microdisplay.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'B1', 'B2', 'B3', 'B4', 'B12', 'B13'}));
            microdisplay.addResource('ndfAttenuations', containers.Map( ...
                {'white', 'red', 'green', 'blue'}, { ...
                containers.Map( ...
                    {'B1', 'B2', 'B3', 'B4', 'B12', 'B13'}, ...
                    {0.29, 0.62, 1.00, 2.23, 0.31, 1.07}), ...
                containers.Map( ...
                    {'B1', 'B2', 'B3', 'B4', 'B12', 'B13'}, ...
                    {0.29, 0.61, 0.99, 2.06, 0.31, 1.04}), ...
                containers.Map( ...
                    {'B1', 'B2', 'B3', 'B4', 'B12', 'B13'}, ...
                    {0.29, 0.62, 1.01, 2.20, 0.31, 1.07}), ...
                containers.Map( ...
                    {'B1', 'B2', 'B3', 'B4', 'B12', 'B13'}, ...
                    {0.31, 0.61, 1.00, 2.28, 0.31, 1.08})}));
            microdisplay.addResource('fluxFactorPaths', containers.Map( ...
                {'low', 'medium', 'high'}, { ...
                riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_low_flux_factors.txt'), ...
                riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_medium_flux_factors.txt'), ...
                riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_high_flux_factors.txt')}));
            microdisplay.addConfigurationSetting('lightPath', 'below', 'isReadOnly', true);
            microdisplay.addResource('spectrum', containers.Map( ...
                {'white', 'red', 'green', 'blue'}, { ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_white_spectrum.txt')), ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_red_spectrum.txt')), ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_green_spectrum.txt')), ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'two_photon', 'microdisplay_below_blue_spectrum.txt'))}));
            obj.addDevice(microdisplay);
            
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(daq.getStream('ai7'));
            obj.addDevice(frameMonitor);
            
            %DYNAMIC CLAMP STUFF
            currentInjected = UnitConvertingDevice('Injected current', 'V').bindStream(obj.daqController.getStream('ai1'));
            obj.addDevice(currentInjected);
            
            gExc = UnitConvertingDevice('Excitatory conductance', 'V').bindStream(daq.getStream('ao2'));
            obj.addDevice(gExc);
            gInh = UnitConvertingDevice('Inhibitory conductance', 'V').bindStream(daq.getStream('ao3'));
            obj.addDevice(gInh);
            
        end

    end

end


