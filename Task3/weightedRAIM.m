function [pos, vel, raim_info] = weightedRAIM(pseudoranges, satellites, settings)
    % 加权RAIM算法实现
    
    % 初始化RAIM信息结构体
    raim_info = struct('detection', false, 'exclusion', false, ...
                     'excluded_sv', [], 'PL', [], 'test_stat', []);
    
    % 检查可用卫星数量（至少需要5颗）
    if length(satellites) < 5
        warning('RAIM requires at least 5 satellites');
        pos = []; vel = [];
        return;
    end
    
    % 设置参数
    sigma = 3; % 伪距测量标准差为3米
    pfa = 1e-2; % 虚警概率
    pmd = 1e-7; % 漏检概率
    
    % 第一步：使用所有卫星的WLS解
    [pos_all, residuals, A, W] = enhancedLeastSquarePos(pseudoranges, satellites, settings);
    
    % 计算测试统计量
    test_statistic = computeTestStatistic(residuals, W);
    raim_info.test_stat = test_statistic;
    
    % 计算阈值（基于自由度和虚警概率）
    dof = length(satellites) - 4; % 自由度
    threshold = chi2inv(1-pfa, dof);
    
    % RAIM检测
    if test_statistic > threshold
        raim_info.detection = true;
        
        % RAIM排除
        [excluded_sv, best_pos] = findFaultySatellite(pseudoranges, satellites, settings);
        
        if ~isempty(excluded_sv)
            raim_info.exclusion = true;
            raim_info.excluded_sv = excluded_sv;
            pos = best_pos;
        else
            pos = pos_all;
        end
    else
        % 无故障检测
        pos = pos_all;
    end
    
    % 计算速度（使用您现有的函数）
    vel = leastSquareVel(pseudoranges, satellites, settings);
    
    % 计算保护级别（加分项）
    raim_info.PL = computeProtectionLevel(A, W, pfa, pmd, sigma);
end