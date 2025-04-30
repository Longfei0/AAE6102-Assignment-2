function test_stat = computeTestStatistic(residuals, W)
    % 计算加权残差平方和
    test_stat = residuals' * W * residuals;
end