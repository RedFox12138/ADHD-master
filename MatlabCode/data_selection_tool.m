function data_selection_tool()
    % 数据筛选工具 - 用于选择静息阶段和注意力阶段
    % 使用方法：在MATLAB命令窗口输入 data_selection_tool()
    
    % 选择包含txt文件的文件夹
    folder_path = uigetdir(pwd, '请选择包含txt文件的文件夹');
    if folder_path == 0
        disp('未选择文件夹，程序退出');
        return;
    end
    
    % 获取文件夹中所有txt文件
    txt_files = dir(fullfile(folder_path, '*.txt'));
    num_files = length(txt_files);
    
    if num_files == 0
        msgbox('所选文件夹中没有txt文件！', '错误', 'error');
        return;
    end
    
    fprintf('找到 %d 个txt文件\n', num_files);
    
    % 循环处理每个文件
    for i = 1:num_files
        current_file = txt_files(i).name;
        file_path = fullfile(folder_path, current_file);
        
        fprintf('\n正在处理第 %d/%d 个文件: %s\n', i, num_files, current_file);
        
        % 读取信号数据
        try
            signal = load(file_path);
            % 如果是多列数据，只取第一列
            if size(signal, 2) > 1
                signal = signal(:, 1);
            end
            signal = signal(:);  % 确保是列向量
        catch ME
            fprintf('读取文件失败: %s\n', ME.message);
            continue;
        end
        
        % 调用选择界面
        [rest_stage, attention_stage, skip_flag] = select_stages(signal, current_file, i, num_files);
        
        if skip_flag
            fprintf('跳过文件: %s\n', current_file);
            continue;
        end
        
        % 保存到mat文件
        [~, file_name, ~] = fileparts(current_file);
        mat_file_path = fullfile(folder_path, [file_name, '.mat']);
        
        try
            save(mat_file_path, 'rest_stage', 'attention_stage');
            fprintf('成功保存: %s\n', mat_file_path);
        catch ME
            fprintf('保存文件失败: %s\n', ME.message);
        end
    end
    
    msgbox(sprintf('处理完成！共处理 %d 个文件', num_files), '完成', 'help');
end


function [rest_stage, attention_stage, skip_flag] = select_stages(signal, file_name, current_idx, total_files)
    % 选择静息阶段和注意力阶段的GUI界面
    
    rest_stage = [];
    attention_stage = [];
    skip_flag = false;
    
    % 创建图形窗口
    fig = figure('Name', sprintf('[%d/%d] 数据选择工具 - %s', current_idx, total_files, file_name), ...
                 'NumberTitle', 'off', ...
                 'Position', [100, 100, 1200, 600], ...
                 'CloseRequestFcn', @close_callback);
    
    % 采样率和时间轴
    fs = 250;  % 采样率 250Hz
    time_points = (0:length(signal)-1) / fs;  % 时间轴（秒）
    
    % 绘制信号
    ax = axes('Parent', fig, 'Position', [0.08, 0.25, 0.88, 0.65]);
    plot(ax, time_points, signal, 'b-', 'LineWidth', 1);
    grid on;
    xlabel('时间 (秒)');
    ylabel('信号幅值');
    title(sprintf('文件: %s (请选择静息阶段和注意力阶段)', file_name), 'Interpreter', 'none');
    
    % 存储选择范围的变量
    rest_range = [];
    attention_range = [];
    rest_patch = [];
    attention_patch = [];
    
    % 创建控制按钮
    btn_width = 0.15;
    btn_height = 0.06;
    btn_y = 0.10;
    
    % 选择静息阶段按钮
    uicontrol('Style', 'pushbutton', ...
              'String', '选择静息阶段', ...
              'Units', 'normalized', ...
              'Position', [0.08, btn_y, btn_width, btn_height], ...
              'FontSize', 10, ...
              'Callback', @select_rest_callback);
    
    % 选择注意力阶段按钮
    uicontrol('Style', 'pushbutton', ...
              'String', '选择注意力阶段', ...
              'Units', 'normalized', ...
              'Position', [0.26, btn_y, btn_width, btn_height], ...
              'FontSize', 10, ...
              'Callback', @select_attention_callback);
    
    % 确认按钮
    uicontrol('Style', 'pushbutton', ...
              'String', '确认', ...
              'Units', 'normalized', ...
              'Position', [0.44, btn_y, btn_width, btn_height], ...
              'FontSize', 10, ...
              'FontWeight', 'bold', ...
              'ForegroundColor', [0, 0.5, 0], ...
              'Callback', @confirm_callback);
    
    % 跳过按钮
    uicontrol('Style', 'pushbutton', ...
              'String', '跳过', ...
              'Units', 'normalized', ...
              'Position', [0.62, btn_y, btn_width, btn_height], ...
              'FontSize', 10, ...
              'ForegroundColor', [0.8, 0, 0], ...
              'Callback', @skip_callback);
    
    % 清除选择按钮
    uicontrol('Style', 'pushbutton', ...
              'String', '清除选择', ...
              'Units', 'normalized', ...
              'Position', [0.68, btn_y, btn_width, btn_height], ...
              'FontSize', 10, ...
              'Callback', @clear_callback);
    
    % 退出按钮
    uicontrol('Style', 'pushbutton', ...
              'String', '退出程序', ...
              'Units', 'normalized', ...
              'Position', [0.86, btn_y, btn_width-0.03, btn_height], ...
              'FontSize', 10, ...
              'ForegroundColor', [0.5, 0, 0], ...
              'Callback', @exit_callback);
    
    % 状态文本
    status_text = uicontrol('Style', 'text', ...
                           'String', '请先选择静息阶段，然后选择注意力阶段', ...
                           'Units', 'normalized', ...
                           'Position', [0.08, 0.02, 0.88, 0.05], ...
                           'FontSize', 9, ...
                           'HorizontalAlignment', 'left', ...
                           'BackgroundColor', [0.94, 0.94, 0.94]);
    
    % 等待用户操作
    uiwait(fig);
    
    % 回调函数：选择静息阶段
    function select_rest_callback(~, ~)
        set(status_text, 'String', '请在图上拖动鼠标选择静息阶段的范围...');
        drawnow;
        
        % 使用ginput选择两个点
        axes(ax);
        [x, ~] = ginput(2);
        
        if length(x) == 2
            % 确保范围有效（将时间转换回采样点索引）
            x = sort(round(x * fs)) + 1;  % 转换为采样点索引
            x(1) = max(1, x(1));
            x(2) = min(length(signal), x(2));
            
            rest_range = x;
            
            % 删除旧的高亮区域
            if ~isempty(rest_patch) && isvalid(rest_patch)
                delete(rest_patch);
            end
            
            % 高亮显示选择的范围
            y_limits = ylim(ax);
            rest_patch = patch(ax, [(rest_range(1)-1)/fs, (rest_range(2)-1)/fs, (rest_range(2)-1)/fs, (rest_range(1)-1)/fs], ...
                              [y_limits(1), y_limits(1), y_limits(2), y_limits(2)], ...
                              'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            uistack(rest_patch, 'bottom');
            
            set(status_text, 'String', sprintf('静息阶段已选择: [%.2f, %.2f]秒，请继续选择注意力阶段', (rest_range(1)-1)/fs, (rest_range(2)-1)/fs));
        else
            set(status_text, 'String', '选择取消，请重新选择');
        end
    end
    
    % 回调函数：选择注意力阶段
    function select_attention_callback(~, ~)
        set(status_text, 'String', '请在图上拖动鼠标选择注意力阶段的范围...');
        drawnow;
        
        % 使用ginput选择两个点
        axes(ax);
        [x, ~] = ginput(2);
        
        if length(x) == 2
            % 确保范围有效（将时间转换回采样点索引）
            x = sort(round(x * fs)) + 1;  % 转换为采样点索引
            x(1) = max(1, x(1));
            x(2) = min(length(signal), x(2));
            
            attention_range = x;
            
            % 删除旧的高亮区域
            if ~isempty(attention_patch) && isvalid(attention_patch)
                delete(attention_patch);
            end
            
            % 高亮显示选择的范围
            y_limits = ylim(ax);
            attention_patch = patch(ax, [(attention_range(1)-1)/fs, (attention_range(2)-1)/fs, (attention_range(2)-1)/fs, (attention_range(1)-1)/fs], ...
                                   [y_limits(1), y_limits(1), y_limits(2), y_limits(2)], ...
                                   'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            uistack(attention_patch, 'bottom');
            
            set(status_text, 'String', sprintf('注意力阶段已选择: [%.2f, %.2f]秒，请点击"确认"保存', (attention_range(1)-1)/fs, (attention_range(2)-1)/fs));
        else
            set(status_text, 'String', '选择取消，请重新选择');
        end
    end
    
    % 回调函数：确认
    function confirm_callback(~, ~)
        if isempty(rest_range)
            msgbox('请先选择静息阶段！', '警告', 'warn');
            return;
        end
        
        if isempty(attention_range)
            msgbox('请先选择注意力阶段！', '警告', 'warn');
            return;
        end
        
        % 提取对应的信号段
        rest_stage = signal(rest_range(1):rest_range(2));
        attention_stage = signal(attention_range(1):attention_range(2));
        
        skip_flag = false;
        delete(fig);
    end
    
    % 回调函数：跳过
    function skip_callback(~, ~)
        answer = questdlg('确定要跳过这个文件吗？', ...
                         '确认跳过', ...
                         '是', '否', '否');
        
        if strcmp(answer, '是')
            skip_flag = true;
            delete(fig);
        end
    end
    
    % 回调函数：清除选择
    function clear_callback(~, ~)
        rest_range = [];
        attention_range = [];
        
        if ~isempty(rest_patch) && isvalid(rest_patch)
            delete(rest_patch);
        end
        
        if ~isempty(attention_patch) && isvalid(attention_patch)
            delete(attention_patch);
        end
        
        rest_patch = [];
        attention_patch = [];
        
        set(status_text, 'String', '已清除所有选择，请重新选择');
    end
    
    % 回调函数：关闭窗口
    function close_callback(~, ~)
        answer = questdlg('确定要关闭窗口吗？未保存的选择将丢失。', ...
                         '确认关闭', ...
                         '是', '否', '否');
        
        if strcmp(answer, '是')
            skip_flag = true;
            delete(fig);
        end
    end

    % 回调函数：退出程序
    function exit_callback(~, ~)
        answer = questdlg('确定要退出整个程序吗？后续文件将不再处理。', ...
                         '确认退出', ...
                         '是', '否', '否');
        
        if strcmp(answer, '是')
            skip_flag = true;
            delete(fig);
            % 强制退出整个程序
            error('用户退出程序');
        end
    end
end
