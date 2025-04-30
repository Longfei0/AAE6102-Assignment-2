function results = processOpenSkyData(datafile)
    % 处理Open-Sky数据的主函数
    
    % 加载数据
    data = load(datafile);
    
    % 初始化结果
    numEpochs = size(data.epochs, 1);
    results = struct('positions', zeros(numEpochs, 3), ...
                    'velocities', zeros(numEpochs, 3), ...
                    'excluded_sv', cell(numEpochs, 1), ...
                    'PL', cell(numEpochs, 1), ...
                    'test_stats', zeros(numEpochs, 1));
    
    % 设置RAIM参数
    settings = struct(); % 根据需要设置参数
    
    % 处理每个时间点
    for i = 1:numEpochs
        % 获取当前时间点的伪距和卫星信息
        pseudoranges = data.pseudoranges(i, :);
        satellites = data.satellites(i, :);
        
        % 应用RAIM算法
        [pos, vel, raim_info] = weightedRAIM(pseudoranges, satellites, settings);
        
        % 存储结果
        results.positions(i,:) = pos;
        results.velocities(i,:) = vel;
        results.excluded_sv{i} = raim_info.excluded_sv;
        results.PL{i} = raim_info.PL;
        results.test_stats(i) = raim_info.test_stat;
    end
    
    % 结果可视化
    plotResults(results, data.ground_truth);
    
    % 如果实现了保护级别和Stanford图(加分项)
    if isfield(results, 'PL') && ~isempty([results.PL{:}])
        % 计算位置误差
        position_errors = zeros(numEpochs, 1);
        protection_levels = zeros(numEpochs, 1);
        
        for i = 1:numEpochs
            % 计算3D位置误差
            position_errors(i) = norm(results.positions(i,:) - data.ground_truth(i,:));
            
            % 获取保护级别
            if ~isempty(results.PL{i})
                protection_levels(i) = results.PL{i}.('3D_PL');
            end
        end
        
        % 绘制Stanford图
        plotStanfordDiagram(position_errors, protection_levels, 50); % 告警限制为50米
    end
end

function plotResults(results, ground_truth)
    % 绘制位置解算结果
    figure;
    
    % 绘制东北方向误差
    subplot(2,1,1);
    plot(results.positions(:,1) - ground_truth(:,1), results.positions(:,2) - ground_truth(:,2), 'b.');
    hold on;
    plot(0, 0, 'r*');
    xlabel('East Error (m)');
    ylabel('North Error (m)');
    title('Horizontal Position Error');
    grid on;
    
    % 绘制高度误差
    subplot(2,1,2);
    plot(1:length(results.positions), results.positions(:,3) - ground_truth(:,3), 'b-');
    xlabel('Epoch');
    ylabel('Height Error (m)');
    title('Vertical Position Error');
    grid on;
    
    % 打印统计数据
    e_errors = results.positions(:,1) - ground_truth(:,1);
    n_errors = results.positions(:,2) - ground_truth(:,2);
    u_errors = results.positions(:,3) - ground_truth(:,3);
    
    rmse_e = sqrt(mean(e_errors.^2));
    rmse_n = sqrt(mean(n_errors.^2));
    rmse_u = sqrt(mean(u_errors.^2));
    rmse_3d = sqrt(rmse_e^2 + rmse_n^2 + rmse_u^2);
    
    fprintf('RMSE East: %.3f m\n', rmse_e);
    fprintf('RMSE North: %.3f m\n', rmse_n);
    fprintf('RMSE Up: %.3f m\n', rmse_u);
    fprintf('RMSE 3D: %.3f m\n', rmse_3d);
    
    % 绘制排除的卫星统计图
    figure;
    excluded_counts = zeros(1, 32); % 假设最多32颗GPS卫星
    for i = 1:length(results.excluded_sv)
        if ~isempty(results.excluded_sv{i})
            for j = 1:length(results.excluded_sv{i})
                sv = results.excluded_sv{i}(j);
                excluded_counts(sv) = excluded_counts(sv) + 1;
            end
        end
    end
    
    bar(1:32, excluded_counts);
    xlabel('Satellite PRN');
    ylabel('Number of Exclusions');
    title('RAIM Satellite Exclusion Statistics');
    grid on;
end