function [X, residuals, A, W] = enhancedLeastSquarePos(pseudoranges, satellites, settings)
    % 基于Assignment 1的WLS代码扩展，返回额外信息用于RAIM
    
    % 初始化
    c = 299792458; % 光速
    MAX_ITER = 10; % 最大迭代次数
    iter = 0;
    
    % 初始位置估计（地球中心）
    X = [0; 0; 0; 0];
    
    % 初始化卫星位置矩阵
    n = length(satellites);
    sat_pos = zeros(n, 3);
    
    % 计算卫星位置
    for i = 1:n
        sat_pos(i, :) = satellites(i).pos;
    end
    
    % 初始化权重矩阵
    W = eye(n);
    
    % 根据卫星仰角更新权重（如果有仰角信息）
    if isfield(satellites, 'el')
        for i = 1:n
            % 使用sin²(elevation)作为权重
            W(i,i) = sin(satellites(i).el)^2;
            
            % 防止权重太小
            if W(i,i) < 0.01
                W(i,i) = 0.01;
            end
        end
    end
    
    % 最小二乘迭代求解
    while iter < MAX_ITER
        iter = iter + 1;
        
        % 当前位置的地球中心坐标
        x_ecef = X(1:3);
        
        % 计算几何矩阵A和观测残差向量omc
        A = zeros(n, 4);
        omc = zeros(n, 1);
        
        for i = 1:n
            % 卫星到接收机的向量
            dx = sat_pos(i, :)' - x_ecef;
            
            % 计算当前估计距离
            pr_est = norm(dx);
            
            % 计算单位向量（卫星到接收机方向）
            e = dx / pr_est;
            
            % 设计矩阵
            A(i, 1:3) = -e';
            A(i, 4) = 1;
            
            % 修正钟差影响的伪距测量
            pr_meas = pseudoranges(i) - X(4);
            
            % 观测残差
            omc(i) = pr_meas - pr_est;
        end
        
        % 解线性方程（加权最小二乘）
        dx = inv(A' * W * A) * A' * W * omc;
        
        % 更新位置估计
        X = X + dx;
        
        % 检查收敛性
        if norm(dx) < 1e-8
            break;
        end
    end
    
    % 最终残差
    residuals = omc;
end