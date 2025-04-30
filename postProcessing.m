% Script postProcessing.m processes the raw signal from the specified data
% file (in settings) operating on blocks of 37 seconds of data.
%
% First it runs acquisition code identifying the satellites in the file,
% then the code and carrier for each of the satellites are tracked, storing
% the 1msec accumulations.  After processing all satellites in the 37 sec
% data block, then postNavigation is called. It calculates pseudoranges
% and attempts a position solutions. At the end plots are made for that
% block of data.

%--------------------------------------------------------------------------
%                           SoftGNSS v3.0
%
% Copyright (C) Darius Plausinaitis
% Written by Darius Plausinaitis, Dennis M. Akos
% Some ideas by Dennis M. Akos
%--------------------------------------------------------------------------
%This program is free software; you can redistribute it and/or
%modify it under the terms of the GNU General Public License
%as published by the Free Software Foundation; either version 2
%of the License, or (at your option) any later version.
%
%This program is distributed in the hope that it will be useful,
%but WITHOUT ANY WARRANTY; without even the implied warranty of
%MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%GNU General Public License for more details.
%
%You should have received a copy of the GNU General Public License
%along with this program; if not, write to the Free Software
%Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
%USA.
%--------------------------------------------------------------------------

%                         THE SCRIPT "RECIPE"
%
% The purpose of this script is to combine all parts of the software
% receiver.
%
% 1.1) Open the data file for the processing and seek to desired point.
%
% 2.1) Acquire satellites
%
% 3.1) Initialize channels (preRun.m).
% 3.2) Pass the channel structure and the file identifier to the tracking
% function. It will read and process the data. The tracking results are
% stored in the trackResults structure. The results can be accessed this
% way (the results are stored each millisecond):
% trackResults(channelNumber).XXX(fromMillisecond : toMillisecond), where
% XXX is a field name of the result (e.g. I_P, codePhase etc.)
%
% 4) Pass tracking results to the navigation solution function. It will
% decode navigation messages, find satellite positions, measure
% pseudoranges and find receiver position.
%
% 5) Plot the results.

%% Initialization =========================================================
addpath include
addpath common
disp ('Starting processing...');

settings = initSettings();
[fid, message] = fopen(settings.fileName, 'rb');
probeData(settings);
%Initialize the multiplier to adjust for the data type
if (settings.fileType == 1)
    dataAdaptCoeff = 1;
else
    dataAdaptCoeff = 2;
end

%If success, then process the data
if (fid > 0)

    % Move the starting point of processing. Can be used to start the
    % signal processing at any point in the data record (e.g. good for long
    % records or for signal processing in blocks).
    fseek(fid, dataAdaptCoeff * settings.skipNumberOfBytes, 'bof');

    %% Acquisition ============================================================

    % 跳过获取步骤如果已有结果
    if exist('acqResults_urban.mat', 'file')
        load('acqResults_urban.mat');
        fprintf('加载已有获取结果...\n');
    else
        % 计算每个扩频码的样本数
        samplesPerCode = round(settings.samplingFreq / ...
            (settings.codeFreqBasis / settings.codeLength));

        % 打开数据文件
        [fid, message] = fopen(settings.fileName, 'rb');

        if fid < 0
            error('无法打开文件 %s: %s', settings.fileName, message);
        end

        % 根据文件类型设置数据适配系数
        if (settings.fileType == 1)
            dataAdaptCoeff = 1;
        else
            dataAdaptCoeff = 2;
        end

        % 移动到文件中的起始点
        fseek(fid, dataAdaptCoeff * settings.skipNumberOfBytes, 'bof');

        % 读取获取所需数据 (11ms的信号)
        data = fread(fid, dataAdaptCoeff * 11 * samplesPerCode, settings.dataType)';

        % 关闭文件
        fclose(fid);

        % 处理复数数据
        if (dataAdaptCoeff == 2)
            data1 = data(1:2:end);
            data2 = data(2:2:end);
            data = data1 + 1i .* data2;
        end

        fprintf('执行信号获取...\n');
        acqResults = acquisition(data, settings);
        save('acqResults_urban.mat', 'acqResults');
    end

    %% Initialize channels and prepare for the run ============================

    % Start further processing only if a GNSS signal was acquired (the
    % field FREQUENCY will be set to 0 for all not acquired signals)
    if (any(acqResults.carrFreq))
        channel = preRun(acqResults, settings);
        showChannelStatus(channel, settings);
    else
        % No satellites to track, exit
        disp('No GNSS signals detected, signal processing finished.');
        trackResults = [];
        return;
    end

    %% Track the signal =======================================================
    if ~exist(['trackingResults', '.mat'])
        startTime = now;
        disp (['   Tracking started at ', datestr(startTime)]);

        % Process all channels for given data block
        [trackResults, channel] = tracking(fid, channel, settings);

        % Close the data file
        fclose(fid);

        disp(['   Tracking is over (elapsed time ', ...
                  datestr(now - startTime, 13), ')'])

        % Auto save the acquisition & tracking results to a file to allow
        % running the positioning solution afterwards.
        %     disp('   Saving Acq & Tracking results to file "trackingResults.mat"')
        %     save('trackingResults', ...
        %         'trackResults', 'settings', 'acqResults', 'channel');

    else
        load('trackingResults.mat');
    end

    %% Calculate navigation solutions =========================================
    disp('   Calculating navigation solutions...');

    [navSolutions, eph] = postNavigation(trackResults, settings);

    % 在postProcessing.m中postNavigation行之后添加:
    if contains(settings.fileName, 'Opensky')
        save('opensky_for_raim.mat', 'navSolutions', 'eph', 'settings', 'trackResults');
        fprintf('Open-Sky数据已保存，可用于RAIM算法\n');
    end

    disp('   Processing is complete for this data block');

    %% Plot all results =======================================================
    disp ('   Ploting results...');

    if settings.plotTracking
        plotTracking(1:settings.numberOfChannels, trackResults, settings);
    end

    plotNavigation(navSolutions, settings);

    disp('Post processing of the signal is over.');

else
    % Error while opening the data file.
    error('Unable to read file %s: %s.', settings.fileName, message);
end % if (fid > 0)
