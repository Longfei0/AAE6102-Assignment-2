function [excluded_sv, best_pos] = findFaultySatellite(pseudoranges, satellites, settings)
    % 逐一排除每颗卫星并计算解
    best_test_stat = Inf;
    excluded_sv = [];
    best_pos = [];
    
    for i = 1:length(satellites)
        % 创建不包含第i颗卫星的子集
        satellites_subset = satellites;
        satellites_subset(i) = [];
        pseudoranges_subset = pseudoranges;
        pseudoranges_subset(i) = [];
        
        if length(satellites_subset) < 4
            continue; % 跳过，因为需要至少4颗卫星
        end
        
        % 计算排除后的解
        [pos_i, residuals_i, A_i, W_i] = enhancedLeastSquarePos(pseudoranges_subset, satellites_subset, settings);
        test_stat_i = computeTestStatistic(residuals_i, W_i);
        
        if test_stat_i < best_test_stat
            best_test_stat = test_stat_i;
            excluded_sv = satellites(i);
            best_pos = pos_i;
        end
    end
    
    % 检查排除后的解是否通过测试
    dof = length(satellites) - 5; % 排除一颗卫星后的自由度
    threshold = chi2inv(1-1e-2, dof);
    if best_test_stat > threshold
        excluded_sv = [];
        best_pos = [];
    end
end