function plotImprovedResultsBack(navSolutions, settings)
    % 可视化改进前后的定位结果对比
    % 输入:
    %   navSolutions - 改进后的导航解算结果
    %   settings - 导航设置参数
    
    %% 加载原始导航结果进行比较
    originalNavFile = fullfile('outputs', 'navSolutions_urban.mat');
    if exist(originalNavFile, 'file')
        originalData = load(originalNavFile);
        original_navSolutions = originalData.navSolutions;
        fprintf('已加载原始导航结果用于对比\n');
    else
        warning('无法找到原始导航结果文件：%s\n使用改进后的结果进行分析', originalNavFile);
        original_navSolutions = navSolutions;
    end
    
    %% 计算地面真值ECEF坐标
    groundTruth = [settings.groundTruth.lat, settings.groundTruth.lon, settings.groundTruth.alt];
    
    % 使用WGS84椭球参数将地面真值转换为ECEF坐标
    latRad = groundTruth(1) * pi/180;
    lonRad = groundTruth(2) * pi/180;
    alt = groundTruth(3);
    
    % WGS84参数
    a = 6378137.0; % 半长轴
    f = 1/298.257223563; % 扁率
    e2 = 2*f - f^2; % 偏心率平方
    
    % 计算卯酉圈半径
    N = a / sqrt(1 - e2 * sin(latRad)^2);
    
    % 计算ECEF坐标
    X_true = (N + alt) * cos(latRad) * cos(lonRad);
    Y_true = (N + alt) * cos(latRad) * sin(lonRad);
    Z_true = (N * (1-e2) + alt) * sin(latRad);
    
    %% 计算原始和改进后的位置误差
    
    % 原始导航结果
    orig_validIdx = ~isnan(original_navSolutions.X) & ~isnan(original_navSolutions.Y) & ~isnan(original_navSolutions.Z);
    
    if ~any(orig_validIdx)
        warning('原始导航结果中没有有效数据点');
        orig_errX = [];
        orig_errY = [];
        orig_errZ = [];
        orig_err3D = [];
    else
        orig_errX = original_navSolutions.X(orig_validIdx) - X_true;
        orig_errY = original_navSolutions.Y(orig_validIdx) - Y_true;
        orig_errZ = original_navSolutions.Z(orig_validIdx) - Z_true;
        orig_err3D = sqrt(orig_errX.^2 + orig_errY.^2 + orig_errZ.^2);
    end
    
    % 改进后的导航结果
    impr_validIdx = ~isnan(navSolutions.X) & ~isnan(navSolutions.Y) & ~isnan(navSolutions.Z);
    
    if ~any(impr_validIdx)
        error('改进后的导航结果中没有有效数据点');
    end
    
    impr_errX = navSolutions.X(impr_validIdx) - X_true;
    impr_errY = navSolutions.Y(impr_validIdx) - Y_true;
    impr_errZ = navSolutions.Z(impr_validIdx) - Z_true;
    impr_err3D = sqrt(impr_errX.^2 + impr_errY.^2 + impr_errZ.^2);
    
    %% 1. 平面位置对比图 (地图视图)
    figure('Name', '平面位置对比 (经纬度)');
    
    % 创建地图坐标轴
    if exist('geoaxes','file') == 2  % 检查是否支持地图绘制
        ax = geoaxes;
        geobasemap(ax, 'satellite');
        hold(ax, 'on');
        
        % 绘制地面真值
        geoplot(ax, groundTruth(1), groundTruth(2), 'yo', 'MarkerSize', 10, 'MarkerFaceColor', 'y', 'DisplayName', '真实位置');
        
        % 绘制原始解算结果
        if any(orig_validIdx)
            geoplot(ax, original_navSolutions.latitude(orig_validIdx), original_navSolutions.longitude(orig_validIdx), ...
                'bx', 'MarkerSize', 6, 'DisplayName', '原始解算位置');
        end
        
        % 绘制改进解算结果
        geoplot(ax, navSolutions.latitude(impr_validIdx), navSolutions.longitude(impr_validIdx), ...
            'r.', 'MarkerSize', 8, 'DisplayName', '改进后位置');
        
        title('平面位置对比 (卫星地图)');
        legend('Location', 'best');
        geolimits([min(groundTruth(1)-0.0002, min(navSolutions.latitude(impr_validIdx)))-0.0001, ...
                  max(groundTruth(1)+0.0002, max(navSolutions.latitude(impr_validIdx)))+0.0001], ...
                 [min(groundTruth(2)-0.0002, min(navSolutions.longitude(impr_validIdx)))-0.0001, ...
                  max(groundTruth(2)+0.0002, max(navSolutions.longitude(impr_validIdx)))+0.0001]);
    else
        % 备选方案：普通坐标系绘图
        plot(original_navSolutions.longitude(orig_validIdx), original_navSolutions.latitude(orig_validIdx), 'bx', 'MarkerSize', 6);
        hold on;
        plot(navSolutions.longitude(impr_validIdx), navSolutions.latitude(impr_validIdx), 'r.', 'MarkerSize', 8);
        plot(groundTruth(2), groundTruth(1), 'yo', 'MarkerSize', 10, 'MarkerFaceColor', 'y');
        legend('原始解算位置', '改进后位置', '真实位置', 'Location', 'best');
        title('平面位置对比 (WGS84)');
        xlabel('经度 (度)');
        ylabel('纬度 (度)');
        grid on;
        axis equal;
    end
    
    %% 2. 高度误差对比
    figure('Name', '高度对比');
    
    if any(orig_validIdx)
        plot(1:sum(orig_validIdx), original_navSolutions.height(orig_validIdx), 'b-', 'LineWidth', 1.5, 'DisplayName', '原始高度');
        hold on;
    end
    
    plot(1:sum(impr_validIdx), navSolutions.height(impr_validIdx), 'r-', 'LineWidth', 1.5, 'DisplayName', '改进后高度');
    plot([1, max(sum(orig_validIdx), sum(impr_validIdx))], [groundTruth(3), groundTruth(3)], 'k--', 'LineWidth', 2, 'DisplayName', '真实高度');
    
    legend('Location', 'best');
    title('高度对比');
    xlabel('测量点');
    ylabel('高度 (m)');
    grid on;
    
    %% 3. ECEF坐标误差对比
    figure('Name', 'ECEF坐标误差对比');
    
    subplot(3, 1, 1);
    if any(orig_validIdx)
        plot(1:sum(orig_validIdx), orig_errX, 'b-', 'LineWidth', 1, 'DisplayName', '原始X误差');
        hold on;
    end
    plot(1:sum(impr_validIdx), impr_errX, 'r-', 'LineWidth', 1.5, 'DisplayName', '改进后X误差');
    legend('Location', 'best');
    title('X坐标误差');
    ylabel('误差 (m)');
    grid on;
    
    subplot(3, 1, 2);
    if any(orig_validIdx)
        plot(1:sum(orig_validIdx), orig_errY, 'b-', 'LineWidth', 1, 'DisplayName', '原始Y误差');
        hold on;
    end
    plot(1:sum(impr_validIdx), impr_errY, 'r-', 'LineWidth', 1.5, 'DisplayName', '改进后Y误差');
    legend('Location', 'best');
    title('Y坐标误差');
    ylabel('误差 (m)');
    grid on;
    
    subplot(3, 1, 3);
    if any(orig_validIdx)
        plot(1:sum(orig_validIdx), orig_errZ, 'b-', 'LineWidth', 1, 'DisplayName', '原始Z误差');
        hold on;
    end
    plot(1:sum(impr_validIdx), impr_errZ, 'r-', 'LineWidth', 1.5, 'DisplayName', '改进后Z误差');
    legend('Location', 'best');
    title('Z坐标误差');
    xlabel('测量点');
    ylabel('误差 (m)');
    grid on;
    
    %% 4. 3D误差对比
    figure('Name', '3D定位误差对比');
    
    if any(orig_validIdx)
        plot(1:sum(orig_validIdx), orig_err3D, 'b-', 'LineWidth', 1.5, 'DisplayName', '原始3D误差');
        hold on;
    end
    
    plot(1:sum(impr_validIdx), impr_err3D, 'r-', 'LineWidth', 2, 'DisplayName', '改进后3D误差');
    legend('Location', 'best');
    title('3D定位误差对比');
    xlabel('测量点');
    ylabel('误差 (m)');
    grid on;
    
    %% 5. CDF误差分析
    figure('Name', '累积误差分布 (CDF)');
    
    if any(orig_validIdx)
        [f_orig, x_orig] = custom_ecdf(orig_err3D);
        plot(x_orig, f_orig, 'b-', 'LineWidth', 1.5, 'DisplayName', '原始定位误差');
        hold on;
    end
    
    [f_impr, x_impr] = custom_ecdf(impr_err3D);
    plot(x_impr, f_impr, 'r-', 'LineWidth', 2, 'DisplayName', '改进后定位误差');
    
    grid on;
    title('累积误差分布');
    xlabel('3D误差 (m)');
    ylabel('累积概率');
    legend('Location', 'best');
    
    %% 6. 误差统计表格可视化
    figure('Name', '误差统计数据');
    
    % 设置标题和标签字体
    titleFont = 14;
    labelFont = 12;
    
    % 创建数据表格
    if any(orig_validIdx)
        metrics = {'均方根误差 (RMS)', 'X轴'; ...
                   '均方根误差 (RMS)', 'Y轴'; ...
                   '均方根误差 (RMS)', 'Z轴'; ...
                   '均方根误差 (RMS)', '3D'; ...
                   '最大误差', '3D'; ...
                   '最小误差', '3D'; ...
                   '平均误差', '3D'; ...
                   '50% 误差 (中位数)', '3D'; ...
                   '67% 误差', '3D'; ...
                   '95% 误差', '3D'};
               
        orig_values = [rms(orig_errX); ...
                       rms(orig_errY); ...
                       rms(orig_errZ); ...
                       rms(orig_err3D); ...
                       max(orig_err3D); ...
                       min(orig_err3D); ...
                       mean(orig_err3D); ...
                       prctile(orig_err3D, 50); ...
                       prctile(orig_err3D, 67); ...
                       prctile(orig_err3D, 95)];
    else
        metrics = {'均方根误差 (RMS)', 'X轴'; ...
                   '均方根误差 (RMS)', 'Y轴'; ...
                   '均方根误差 (RMS)', 'Z轴'; ...
                   '均方根误差 (RMS)', '3D'; ...
                   '最大误差', '3D'; ...
                   '最小误差', '3D'; ...
                   '平均误差', '3D'; ...
                   '50% 误差 (中位数)', '3D'; ...
                   '67% 误差', '3D'; ...
                   '95% 误差', '3D'};
               
        orig_values = nan(10, 1);
    end
    
    impr_values = [rms(impr_errX); ...
                   rms(impr_errY); ...
                   rms(impr_errZ); ...
                   rms(impr_err3D); ...
                   max(impr_err3D); ...
                   min(impr_err3D); ...
                   mean(impr_err3D); ...
                   prctile(impr_err3D, 50); ...
                   prctile(impr_err3D, 67); ...
                   prctile(impr_err3D, 95)];
               
    if any(orig_validIdx)
        improvement = 100 * (orig_values - impr_values) ./ orig_values;
    else
        improvement = nan(10, 1);
    end
    
    % 创建表格数据
    tableData = [metrics, num2cell(orig_values), num2cell(impr_values), num2cell(improvement)];
    
    % 将数据输出到控制台
    fprintf('\n=== 定位效果改进统计 ===\n');
    if any(orig_validIdx)
        fprintf('指标                   原始结果      改进后结果     改进百分比\n');
        fprintf('--------------------------------------------------------------\n');
        fprintf('X轴均方根误差:       %8.2f m      %8.2f m      %8.2f%%\n', rms(orig_errX), rms(impr_errX), improvement(1));
        fprintf('Y轴均方根误差:       %8.2f m      %8.2f m      %8.2f%%\n', rms(orig_errY), rms(impr_errY), improvement(2));
        fprintf('Z轴均方根误差:       %8.2f m      %8.2f m      %8.2f%%\n', rms(orig_errZ), rms(impr_errZ), improvement(3));
        fprintf('3D均方根误差:        %8.2f m      %8.2f m      %8.2f%%\n', rms(orig_err3D), rms(impr_err3D), improvement(4));
        fprintf('最大3D误差:          %8.2f m      %8.2f m      %8.2f%%\n', max(orig_err3D), max(impr_err3D), improvement(5));
        fprintf('最小3D误差:          %8.2f m      %8.2f m      %8.2f%%\n', min(orig_err3D), min(impr_err3D), improvement(6));
        fprintf('平均3D误差:          %8.2f m      %8.2f m      %8.2f%%\n', mean(orig_err3D), mean(impr_err3D), improvement(7));
        fprintf('50%%误差(中位数):     %8.2f m      %8.2f m      %8.2f%%\n', prctile(orig_err3D, 50), prctile(impr_err3D, 50), improvement(8));
        fprintf('67%%误差:            %8.2f m      %8.2f m      %8.2f%%\n', prctile(orig_err3D, 67), prctile(impr_err3D, 67), improvement(9));
        fprintf('95%%误差:            %8.2f m      %8.2f m      %8.2f%%\n', prctile(orig_err3D, 95), prctile(impr_err3D, 95), improvement(10));
    else
        fprintf('指标                   改进后结果  \n');
        fprintf('---------------------------------\n');
        fprintf('X轴均方根误差:       %8.2f m   \n', rms(impr_errX));
        fprintf('Y轴均方根误差:       %8.2f m   \n', rms(impr_errY));
        fprintf('Z轴均方根误差:       %8.2f m   \n', rms(impr_errZ));
        fprintf('3D均方根误差:        %8.2f m   \n', rms(impr_err3D));
        fprintf('最大3D误差:          %8.2f m   \n', max(impr_err3D));
        fprintf('最小3D误差:          %8.2f m   \n', min(impr_err3D));
        fprintf('平均3D误差:          %8.2f m   \n', mean(impr_err3D));
        fprintf('50%%误差(中位数):     %8.2f m   \n', prctile(impr_err3D, 50));
        fprintf('67%%误差:            %8.2f m   \n', prctile(impr_err3D, 67));
        fprintf('95%%误差:            %8.2f m   \n', prctile(impr_err3D, 95));
    end
    
    % 创建可视化表格
    if any(orig_validIdx)
        header = {'指标类型', '组件', '原始结果(m)', '改进结果(m)', '改进百分比(%)'};
        uitable('Data', tableData, 'ColumnName', header, ...
            'Position', [50 50 500 250], 'ColumnWidth', {120, 80, 100, 100, 100});
    else
        header = {'指标类型', '组件', '原始结果(m)', '改进结果(m)', '改进百分比(%)'};
        uitable('Data', tableData, 'ColumnName', header, ...
            'Position', [50 50 500 250], 'ColumnWidth', {120, 80, 100, 100, 100});
    end
    
    % 设置表格标题
    annotation('textbox', [0.25, 0.85, 0.5, 0.1], ...
        'String', '城市环境GNSS定位改进效果统计表', ...
        'FontSize', 16, 'FontWeight', 'bold', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center');
    
    %% 7. 可见卫星数量对比 (如果有数据)
    if isfield(navSolutions, 'numSVs') && isfield(original_navSolutions, 'numSVs')
        figure('Name', '可见卫星数量对比');
        
        plot(1:length(original_navSolutions.numSVs), original_navSolutions.numSVs, 'b-', 'LineWidth', 1.5, 'DisplayName', '原始解算');
        hold on;
        plot(1:length(navSolutions.numSVs), navSolutions.numSVs, 'r-', 'LineWidth', 1.5, 'DisplayName', '使用skymask后');
        
        legend('Location', 'best');
        title('可见卫星数量对比');
        xlabel('测量点');
        ylabel('可见卫星数量');
        grid on;
    end
    
    %% 8. 散点图对比
    figure('Name', '3D误差与卫星数量的关系');
    
    if isfield(navSolutions, 'numSVs') && any(orig_validIdx) && isfield(original_navSolutions, 'numSVs')
        subplot(1, 2, 1);
        scatter(original_navSolutions.numSVs(orig_validIdx), orig_err3D, 50, 'b', 'filled', 'o', 'DisplayName', '原始解算');
        title('原始解算: 卫星数量与3D误差关系');
        xlabel('可见卫星数量');
        ylabel('3D误差 (m)');
        grid on;
        
        subplot(1, 2, 2);
    end
    
    if isfield(navSolutions, 'numSVs')
        scatter(navSolutions.numSVs(impr_validIdx), impr_err3D, 50, 'r', 'filled', 'o', 'DisplayName', '改进后解算');
        title('改进后解算: 卫星数量与3D误差关系');
        xlabel('可见卫星数量');
        ylabel('3D误差 (m)');
        grid on;
    end
    
    % 保存图表到outputs目录
    if ~exist('outputs/figures', 'dir')
        mkdir('outputs/figures');
    end
    
    % 保存所有打开的图表
    figHandles = findobj('Type', 'figure');
    for i = 1:length(figHandles)
        figName = sprintf('outputs/figures/improved_result_figure%d.png', i);
        saveas(figHandles(i), figName);
        fprintf('图表已保存到: %s\n', figName);
    end
end

% 添加自定义ECDF函数
function [f, x] = custom_ecdf(data)
    % 简单实现的ECDF函数，不依赖Statistics Toolbox
    data = sort(data(:));  % 确保数据是列向量并排序
    n = length(data);
    
    % 获取唯一值
    x = unique(data);
    
    % 计算每个值的累积频率
    f = zeros(size(x));
    for i = 1:length(x)
        f(i) = sum(data <= x(i)) / n;
    end
    
    % 添加起始点
    x = [min(x); x];
    f = [0; f];
end
