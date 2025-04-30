function skymask = readSkymask(filename)
    % 读取skymask CSV文件
    fprintf('Reading skymask from %s\n', filename);

    try
        % 使用readtable读取CSV文件(更高级的方法)
        data = readtable(filename);
        skymask.azimuth = data.Azimuth_angle_deg;
        skymask.elevation = data.Elevation_angle_deg;
    catch
        % 如果readtable失败，尝试使用基本方法
        fprintf('尝试使用基本方法读取CSV...\n');

        fid = fopen(filename, 'r');

        if fid == -1
            error('无法打开skymask文件: %s', filename);
        end

        % 读取CSV数据
        data = textscan(fid, '%f,%f', 'HeaderLines', 1);
        fclose(fid);

        if isempty(data{1}) || isempty(data{2})
            error('Skymask文件格式错误或为空');
        end

        skymask.azimuth = data{1};
        skymask.elevation = data{2};
    end

    fprintf('成功读取skymask数据: %d个点\n', length(skymask.azimuth));
end
