%--------------------------------------------------------------------------
%                           SoftGNSS v3.0
% 
% Copyright (C) Darius Plausinaitis and Dennis M. Akos
% Written by Darius Plausinaitis and Dennis M. Akos
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
%
%Script initializes settings and environment of the software receiver.
%Then the processing is started.

%--------------------------------------------------------------------------
% CVS record:
% $Id: init.m,v 1.14.2.21 2006/08/22 13:46:00 dpl Exp $

%% Clean up the environment first =========================================
clear all; close all; clc;

format ('compact');
format ('long', 'g');

%--- Include folders with functions ---------------------------------------
addpath include               % The software receiver functions
addpath ('Common')            % Common functions 
addpath ('.');                % Main directory

%% 创建输出目录 ==========================================================
if ~exist('outputs', 'dir')
    mkdir('outputs');
end

%% Print startup ==========================================================
fprintf(['\n',...
    'Welcome to:  softGNSS\n\n', ...
    'An open source GNSS SDR software project initiated by:\n\n', ...
    '              Danish GPS Center/Aalborg University\n\n', ...
    'The code was improved by GNSS Laboratory/University of Colorado.\n\n',...
    'The software receiver softGNSS comes with ABSOLUTELY NO WARRANTY;\n',...
    'for details please read license details in the file license.txt. This\n',...
    'is free software, and  you  are  welcome  to  redistribute  it under\n',...
    'the terms described in the license.\n\n']);
fprintf('                   -------------------------------\n\n');

%% 选择数据集 ==========================================================
datasetChoice = input('选择数据集: 1 - Opensky, 2 - Urban: ');

if datasetChoice == 1
    settings = initSettings_opensky();
    datasetName = 'opensky';
else
    settings = initSettings_urban();
    datasetName = 'urban';
end

%% 打开数据文件 =========================================================
[fid, message] = fopen(settings.fileName, 'rb');

% 文件打开检查
if fid < 0
    error('无法打开文件 %s: %s', settings.fileName, message);
end

% 初始化数据类型系数
if (settings.fileType == 1)
    dataAdaptCoeff = 1;
else
    dataAdaptCoeff = 2;
end

%% Generate plot of raw data and ask if ready to start processing =========
try
    fprintf('Probing data (%s)...\n', settings.fileName)
    probeData(settings);
catch
    % There was an error, print it and exit
    errStruct = lasterror;
    disp(errStruct.message);
    disp('  (run setSettings or change settings in "initSettings.m" to reconfigure)')    
    fclose(fid);
    return;
end
    
disp('  Raw IF data plotted ')
disp(' ');
gnssStart = input('Enter "1" to initiate GNSS processing or "0" to exit : ');

if (gnssStart == 0)
    fclose(fid);
    return;
end

%% 信号获取 (Acquisition) =================================================
acqResultsFile = fullfile('outputs', ['acqResults_', datasetName, '.mat']);

if exist(acqResultsFile, 'file') && ~settings.skipAcquisition
    fprintf('加载已有获取结果: %s\n', acqResultsFile);
    load(acqResultsFile);
else
    if settings.skipAcquisition
        fprintf('跳过信号获取\n');
        acqResults = [];
    else
        % 计算每个扩频码的样本数
        samplesPerCode = round(settings.samplingFreq / ...
            (settings.codeFreqBasis / settings.codeLength));
        
        % 移动到文件起始点
        fseek(fid, dataAdaptCoeff * settings.skipNumberOfBytes, 'bof');
        
        % 读取获取所需数据
        fprintf('读取获取数据...\n');
        data = fread(fid, dataAdaptCoeff * 11 * samplesPerCode, settings.dataType)';
        
        % 处理复数数据
        if (dataAdaptCoeff == 2)
            data1 = data(1:2:end);
            data2 = data(2:2:end);
            data = data1 + 1i .* data2;
        end
        
        % 执行获取
        fprintf('执行信号获取...\n');
        acqResults = acquisition(data, settings);
        save(acqResultsFile, 'acqResults', 'settings');
    end
end

%% 初始化通道 ============================================================
fprintf('初始化通道...\n');

if (any(acqResults.carrFreq))
    channel = preRun(acqResults, settings);
    showChannelStatus(channel, settings);
else
    % 没有检测到卫星信号
    disp('未检测到GNSS信号，处理终止');
    fclose(fid);
    return;
end

%% 跟踪过程 =============================================================
trackResultsFile = fullfile('outputs', ['trackResults_', datasetName, '.mat']);

if exist(trackResultsFile, 'file')
    fprintf('加载已有跟踪结果: %s\n', trackResultsFile);
    load(trackResultsFile);
else
    % 重新打开文件并定位到起始点
    fseek(fid, dataAdaptCoeff * settings.skipNumberOfBytes, 'bof');
    
    % 执行跟踪
    fprintf('执行信号跟踪...\n');
    [trackResults, channel] = tracking(fid, channel, settings);
    save(trackResultsFile, 'trackResults', 'settings', 'acqResults', 'channel');
end

%% 导航解算 =============================================================
fprintf('执行导航解算...\n');
[navSolutions, eph] = postNavigation(trackResults, settings);

% 保存结果
navResultsFile = fullfile('outputs', ['navSolutions_', datasetName, '.mat']);
save(navResultsFile, 'navSolutions', 'eph', 'settings');

%% 结束处理 =============================================================
fclose(fid);

%% 绘制结果 =============================================================
if settings.plotTracking
    plotTracking(1:settings.numberOfChannels, trackResults, settings);
end

plotNavigation(navSolutions, settings);

fprintf('处理完成! 结果已保存至 %s\n', navResultsFile);