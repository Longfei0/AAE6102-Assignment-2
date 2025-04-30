function visible = isSatVisible(az, el, skymask)
    % 判断卫星是否可见
    % 输入:
    %   az - 卫星方位角(度)
    %   el - 卫星仰角(度)
    %   skymask - 包含方位角和最小仰角的结构体
    
    % 检查输入有效性
    if isnan(az) || isnan(el) || el < 0
        visible = false;
        return;
    end
    
    % 将方位角规范化到0-360度
    az = mod(az, 360);
    
    % 找到最接近的方位角索引
    [~, idx] = min(abs(skymask.azimuth - az));
    
    % 获取该方位角的最小可见仰角
    minElevation = skymask.elevation(idx);
    
    % 判断卫星是否可见
    visible = (el >= minElevation);
    
    % 添加调试信息
    % fprintf('Az: %.2f, El: %.2f, Min: %.2f, Visible: %d\n', az, el, minElevation, visible);
end