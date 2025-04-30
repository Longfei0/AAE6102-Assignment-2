%--------------------------------------------------------------------------
% GNSS城市环境定位改进 - Task 2入口脚本
% 基于SoftGNSS框架,使用skymask改进城市环境下的GNSS定位
%--------------------------------------------------------------------------

%% 清理环境
clear all; close all; clc;

%% 添加必要路径
addpath . ./ . ./ include % 主程序函数
addpath ('../../Common') % 公共函数
addpath ('../..') % 主目录
addpath ('.') % 当前目录

%% 初始化设置
fprintf('初始化城市环境设置...\n');
settings = initSettings_urban();

%% 数据文件准备
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

%% 探测数据
fprintf('探测原始数据...\n');
probeData(settings);
fprintf('按任意键继续处理...\n');
pause;

%% 获取过程
% 检查是否有缓存的获取结果
if exist('acqResults_urban.mat', 'file')
    load('acqResults_urban.mat');
    fprintf('加载已有获取结果...\n');
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
    save('acqResults_urban.mat', 'acqResults');
end

%% 初始化通道
fprintf('初始化通道...\n');

if (any(acqResults.carrFreq))
    channel = preRun(acqResults, settings);
    showChannelStatus(channel, settings);
else
    % 没有检测到卫星信号
    disp('未检测到GNSS信号，处理终止');
    return;
end

%% 跟踪过程
if exist('trackResults_urban.mat', 'file')
    load('trackResults_urban.mat');
    fprintf('加载已有跟踪结果...\n');
else
    % 重新打开文件并定位到起始点
    fseek(fid, dataAdaptCoeff * settings.skipNumberOfBytes, 'bof');

    % 执行跟踪
    fprintf('执行信号跟踪...\n');
    [trackResults, channel] = tracking(fid, channel, settings);
    save('trackResults_urban.mat', 'trackResults', 'settings', 'acqResults', 'channel');
end

% 关闭文件
fclose(fid);

%% 导航解算
fprintf('执行改进的导航解算(使用skymask)...\n');
[navSolutions, eph] = improvedPostNavigation(trackResults, settings);

% 保存结果
save('improved_urban_results.mat', 'navSolutions', 'eph', 'settings');

% 可视化结果
plotImprovedResults(navSolutions, settings);

fprintf('处理完成! 结果已保存至improved_urban_results.mat\n');

% 在init_urban_skymask.m文件中添加
try
    fprintf('加载settings...\n');
    disp(settings.skymaskFile); % 打印文件路径

    fprintf('尝试调用readSkymask...\n');
    skymask = readSkymask(settings.skymaskFile);

    % 后续代码...
catch err
    % 详细捕获错误信息
    fprintf('错误发生在: %s\n', err.stack(1).name);
    fprintf('行号: %d\n', err.stack(1).line);
    fprintf('错误信息: %s\n', err.message);
    fprintf('错误堆栈:\n');
    disp(err.stack);
end
