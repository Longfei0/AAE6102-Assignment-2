function [az, el] = calculateAzEl(satPos, receiverPos)
    % 计算卫星方位角和仰角
    % 输入:
    %   satPos - 卫星ECEF坐标 [X, Y, Z]
    %   receiverPos - 接收机ECEF坐标 [X, Y, Z]
    % 输出:
    %   az - 方位角(度)
    %   el - 仰角(度)

    % 计算向量差
    vec = satPos - receiverPos;

    % 接收机位置的地心坐标转换为测地坐标
    X = receiverPos(1);
    Y = receiverPos(2);
    Z = receiverPos(3);

    % 计算大地经度
    lambda = atan2(Y, X);

    % 计算大地纬度的近似值 (简化计算)
    p = sqrt(X ^ 2 + Y ^ 2);
    phi = atan2(Z, p);

    % 从ECEF到ENU的转换矩阵
    R = [-sin(lambda), cos(lambda), 0;
         -sin(phi) * cos(lambda), -sin(phi) * sin(lambda), cos(phi);
         cos(phi) * cos(lambda), cos(phi) * sin(lambda), sin(phi)];

    % 转换向量到ENU坐标系
    enu = R * vec';

    % 计算方位角和仰角
    east = enu(1);
    north = enu(2);
    up = enu(3);

    % 方位角: 从北开始顺时针
    az = atan2(east, north) * 180 / pi;

    if az < 0
        az = az + 360;
    end

    % 仰角: 从水平面向上
    el = atan2(up, sqrt(east ^ 2 + north ^ 2)) * 180 / pi;
end
