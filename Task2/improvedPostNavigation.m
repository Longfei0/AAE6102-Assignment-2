function [navSolutions, eph] = improvedPostNavigation(trackResults, settings)
    % 首先调用原始postNavigation获取基本结果
    [navSolutions, eph] = postNavigation(trackResults, settings);
    
    % 创建原始结果的备份用于比较
    origNavSolutions = navSolutions;
    
    % 如果未启用skymask，直接返回原始结果
    if ~isfield(settings, 'useSkymask') || ~settings.useSkymask
        fprintf('Skymask未启用，返回原始定位结果\n');
        return;
    end
    
    try
        % 加载skymask
        fullPath = settings.skymaskFile;
        if ~exist(fullPath, 'file')
            fprintf('警告: Skymask文件不存在: %s\n', fullPath);
            return;
        end
        
        skymask = readSkymask(fullPath);
        fprintf('使用skymask进行卫星可见性过滤: %s\n', fullPath);
        
        % 计算地面真值ECEF坐标
        [X_true, Y_true, Z_true] = geo2cart([settings.groundTruth.lat, 0, 0], ...
                                           [settings.groundTruth.lon, 0, 0], ...
                                           settings.groundTruth.alt, 5);
        groundTruthECEF = [X_true, Y_true, Z_true];
        
        % 初始化可见性统计
        visibilityStats = struct('epoch', {}, 'total', {}, 'visible', {}, 'used', {});
        
        % 处理每个测量点
        fprintf('开始应用skymask过滤...\n');
        fprintf('共有%d个测量点需处理\n', length(navSolutions.X));
        
        for currMeasNr = 1:length(navSolutions.X)
            % 找出当前测量点的有效卫星
            activeSats = find(~isnan(navSolutions.PRN(:, currMeasNr)));
            
            % 初始化可见卫星列表
            visibleSats = [];
            
            % 检查每颗卫星的可见性
            for i = 1:length(activeSats)
                satIdx = activeSats(i);
                az = navSolutions.az(satIdx, currMeasNr);
                el = navSolutions.el(satIdx, currMeasNr);
                
                % 检查卫星可见性
                if ~isnan(az) && ~isnan(el) && isSatVisible(az, el, skymask)
                    % 确保visibleSats是行向量
                    visibleSats = [visibleSats, satIdx]; %#ok<AGROW>
                end
            end
            
            % 强制转换为行向量
            visibleSats = visibleSats(:)';
            
            % 记录统计信息
            stats = struct('epoch', currMeasNr, ...
                           'total', length(activeSats), ...
                           'visible', length(visibleSats));
            
            % 如果可见卫星不足4颗，添加额外卫星
            if length(visibleSats) < 4
                fprintf('测量点 %d: 可见卫星不足4颗，添加高仰角卫星...\n', currMeasNr);
                
                % 找出剩余卫星
                remainingSats = setdiff(activeSats, visibleSats);
                if ~isempty(remainingSats)
                    % 按仰角排序
                    elevations = navSolutions.el(remainingSats, currMeasNr);
                    [~, idxSorted] = sort(elevations, 'descend');
                    
                    % 添加必要数量的卫星
                    numToAdd = min(4 - length(visibleSats), length(idxSorted));
                    if numToAdd > 0
                        additionalSats = remainingSats(idxSorted(1:numToAdd));
                        % 确保additionalSats也是行向量
                        additionalSats = additionalSats(:)';
                        visibleSats = [visibleSats, additionalSats];
                        fprintf('  添加了%d颗额外卫星以确保定位\n', numToAdd);
                    end
                end
            end
            
            % 如果仍然没有足够卫星，继续下一个测量点
            if length(visibleSats) < 4
                fprintf('测量点 %d: 可用卫星仍不足，保留原始解算结果\n', currMeasNr);
                stats.used = 0;
                visibilityStats = [visibilityStats; stats]; %#ok<AGROW>
                continue;
            end
            
            % 重新计算位置解 - 这是关键部分！
            try
                % 准备数据
                PRNs = navSolutions.PRN(visibleSats, currMeasNr);
                rawP = navSolutions.rawP(visibleSats, currMeasNr);
                
                % 获取卫星位置和时钟校正
                transmitTime = navSolutions.transmitTime(visibleSats, currMeasNr);
                [satPositions, satClkCorr] = satpos(transmitTime, PRNs, eph, settings);
                
                % 伪距校正
                clkCorrRawP = rawP + satClkCorr * settings.c;
                
                % 执行最小二乘定位
                [xyzdt, navSolutions.DOP(:, currMeasNr)] = ...
                    leastSquarePos(satPositions, satClkCorr, rawP, settings);
                
                % 保存新的位置结果
                navSolutions.X(currMeasNr) = xyzdt(1);
                navSolutions.Y(currMeasNr) = xyzdt(2);
                navSolutions.Z(currMeasNr) = xyzdt(3);
                navSolutions.dt(currMeasNr) = xyzdt(4);
                
                % 转换为大地坐标
                [navSolutions.latitude(currMeasNr), ...
                 navSolutions.longitude(currMeasNr), ...
                 navSolutions.height(currMeasNr)] = cart2geo(xyzdt(1), xyzdt(2), xyzdt(3), 5);
                
                % 更新UTM坐标
                [navSolutions.E(currMeasNr), ...
                 navSolutions.N(currMeasNr), ...
                 navSolutions.U(currMeasNr)] = cart2utm(xyzdt(1), xyzdt(2), xyzdt(3), ...
                                                      navSolutions.utmZone);
                                                  
                stats.used = length(visibleSats);
                fprintf('测量点 %d: 使用 %d/%d 颗卫星重新计算位置\n', ...
                       currMeasNr, length(visibleSats), length(activeSats));
            catch e
                fprintf('测量点 %d: 重新计算位置失败: %s\n', currMeasNr, e.message);
                stats.used = 0;
            end
            
            visibilityStats = [visibilityStats; stats]; %#ok<AGROW>
        end
        
        % 保存处理统计信息
        navSolutions.visibilityStats = visibilityStats;
        
        % 统计可见卫星占比
        totalVisible = sum([visibilityStats.visible]);
        totalSats = sum([visibilityStats.total]);
        fprintf('总体卫星可见率: %.1f%% (%d/%d)\n', ...
               100*totalVisible/totalSats, totalVisible, totalSats);
        
        % 记录使用skymask后改进的结果
        fprintf('已完成skymask过滤，位置解已更新\n');
        
        % 计算改进前后的误差
        if ~isnan(settings.groundTruth.lat) && ~isnan(settings.groundTruth.lon)
            % 计算原始解误差
            orig_err = calculatePositionErrors(origNavSolutions, groundTruthECEF);
            
            % 计算改进解误差
            imp_err = calculatePositionErrors(navSolutions, groundTruthECEF);
            
            fprintf('原始解平均3D误差: %.2f米\n', mean(orig_err));
            fprintf('改进解平均3D误差: %.2f米\n', mean(imp_err));
            fprintf('精度提升: %.2f%%\n', 100*(1-mean(imp_err)/mean(orig_err)));
            
            % 保存原始结果用于比较
            navSolutions.origSolution = origNavSolutions;
        end
        
    catch e
        fprintf('警告: skymask应用失败: %s\n', e.message);
        fprintf('在此行发生错误: %s 行号 %d\n', e.stack(1).file, e.stack(1).line);
    end
end

% 辅助函数: 计算位置误差
function errors = calculatePositionErrors(solutions, truePos)
    valid = ~isnan(solutions.X);
    pos = [solutions.X(valid); solutions.Y(valid); solutions.Z(valid)]';
    errors = sqrt(sum((pos - repmat(truePos, size(pos, 1), 1)).^2, 2));
end

% 初始化导航结果结构体
function navSolutions = initNavigationResults(numberOfMeas, numberOfChannels)
    navSolutions.X = zeros(1, numberOfMeas);
    navSolutions.Y = zeros(1, numberOfMeas);
    navSolutions.Z = zeros(1, numberOfMeas);
    navSolutions.dt = zeros(1, numberOfMeas);
    navSolutions.latitude = zeros(1, numberOfMeas);
    navSolutions.longitude = zeros(1, numberOfMeas);
    navSolutions.height = zeros(1, numberOfMeas);
    navSolutions.DOP = zeros(5, numberOfMeas);
    navSolutions.az = zeros(numberOfChannels, numberOfMeas);
    navSolutions.el = zeros(numberOfChannels, numberOfMeas);
    navSolutions.rawP = zeros(numberOfChannels, numberOfMeas);
    navSolutions.transmitTime = zeros(numberOfChannels, numberOfMeas);
end
