function PL = computeProtectionLevel(A, W, pfa, pmd, sigma)
    % 计算保护级别矩阵
    P = inv(A' * W * A);
    
    % 计算斜率
    S_E = sqrt(P(1,1));
    S_N = sqrt(P(2,2));
    S_U = sqrt(P(3,3));
    
    % 计算保护级别（根据Walter & Enge, 1995）
    k_md = 5.33; % 对应10^-7的漏检概率
    HPL = k_md * sigma * sqrt(S_E^2 + S_N^2);
    VPL = k_md * sigma * S_U;
    
    % 3D保护级别
    PL = struct('HPL', HPL, 'VPL', VPL, '3D_PL', sqrt(HPL^2 + VPL^2));
end