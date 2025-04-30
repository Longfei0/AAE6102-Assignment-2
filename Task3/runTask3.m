% Task 3 - GPS RAIM 主脚本
clear;
clc;
close all;

% 设置数据文件路径
% datafile = 'opensky_for_raim.mat'; % 请根据实际数据路径修改
datafile = 'navSolutions_opensky.mat';

% 处理Open-Sky数据
fprintf('开始处理Open-Sky数据...\n');
results = processOpenSkyData(datafile);

% 保存结果
save('task3_results.mat', 'results');
fprintf('处理完成，结果已保存到task3_results.mat\n');

% 生成报告摘要
fprintf('\n=== RAIM 性能报告 ===\n');
fprintf('总时间点: %d\n', size(results.positions, 1));
fprintf('有效解算次数: %d (%.1f%%)\n', sum(all(~isnan(results.positions), 2)), ...
    100*sum(all(~isnan(results.positions), 2))/size(results.positions, 1));
fprintf('故障检测次数: %d\n', sum([results.test_stats] > 0));
fprintf('排除卫星次数: %d\n', sum(cellfun(@(x) ~isempty(x), results.excluded_sv)));

% 显示保护级别统计(如果有)
if ~isempty([results.PL{:}])
    valid_pl = cellfun(@(x) ~isempty(x) && isfinite(x.ThreeDPL), results.PL);
    if any(valid_pl)
        pl_values = cellfun(@(x) x.ThreeDPL, results.PL(valid_pl));
        fprintf('平均3D保护级别: %.2f m\n', mean(pl_values));
        fprintf('最大3D保护级别: %.2f m\n', max(pl_values));
    end
end