function plotStanfordDiagram(position_errors, protection_levels, alarm_limit)
    % 创建Stanford图
    figure;
    scatter(position_errors, protection_levels, 'b.');
    hold on;
    
    % 添加斜线y=x
    max_val = max(max(position_errors), max(protection_levels));
    plot([0 max_val], [0 max_val], 'r-');
    
    % 添加告警限制线
    plot([0 max_val], [alarm_limit alarm_limit], 'r--');
    plot([alarm_limit alarm_limit], [0 max_val], 'r--');
    
    % 标记区域
    xlabel('Position Error (m)');
    ylabel('Protection Level (m)');
    title('Stanford Diagram');
    grid on;
    
    % 计算各个区域的统计数据
    normal = sum(position_errors <= protection_levels & position_errors <= alarm_limit);
    mi = sum(position_errors > protection_levels & position_errors <= alarm_limit);
    hmi = sum(position_errors > protection_levels & position_errors > alarm_limit);
    ua = sum(position_errors <= protection_levels & position_errors > alarm_limit);
    
    % 显示统计信息
    legend(['Normal: ', num2str(normal), ' (', num2str(100*normal/length(position_errors)), '%)'], ...
           ['MI: ', num2str(mi), ' (', num2str(100*mi/length(position_errors)), '%)'], ...
           ['HMI: ', num2str(hmi), ' (', num2str(100*hmi/length(position_errors)), '%)'], ...
           ['UA: ', num2str(ua), ' (', num2str(100*ua/length(position_errors)), '%)']);
end