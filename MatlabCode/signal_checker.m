% --- 信号质量检查工具：修复版脚本 ---
% 逐个显示文件夹中的txt信号文件，并提供一个勾选框
% 以记录信号质量不佳的文件名。

clc;
close all;
clear all;

% 初始化一个结构体来存储所有需要共享的变量
handles.folder_path = uigetdir('', '请选择包含TXT信号文件的文件夹');
if handles.folder_path == 0
    disp('用户取消了操作。');
    return;
end

% 获取文件夹中所有txt文件
handles.file_list = dir(fullfile(handles.folder_path, '*.txt'));
if isempty(handles.file_list)
    errordlg('在指定的文件夹中未找到任何 .txt 文件。', '错误');
    return;
end

handles.num_files = length(handles.file_list);
handles.current_file_index = 1;
handles.bad_quality_files = {}; % 用于存储被勾选的文件名

% 创建图形界面
fig = figure('Name', '信号质量检查工具', 'NumberTitle', 'off', 'Position', [100, 100, 800, 600], 'MenuBar', 'none');

ax = axes('Parent', fig, 'Position', [0.1, 0.3, 0.8, 0.6]);
xlabel(ax, '时间 (s)');
ylabel(ax, '幅值');
grid(ax, 'on');

% 创建UI控件，并通过 UserData 传递 handles 结构体
uicontrol('Style', 'text', 'String', '文件进度:', 'Position', [10, 50, 60, 20]);
handles.progress_text = uicontrol('Style', 'text', 'String', '', 'Position', [75, 50, 100, 20]);

handles.file_name_text = uicontrol('Style', 'text', 'String', '', 'Position', [10, 20, 780, 20], 'HorizontalAlignment', 'left');

handles.bad_quality_checkbox = uicontrol('Style', 'checkbox', 'String', '信号质量不佳', 'Position', [200, 50, 120, 20]);

uicontrol('Style', 'pushbutton', 'String', '上一个', 'Position', [350, 50, 80, 30], 'Callback', {@prev_file_callback, fig});
uicontrol('Style', 'pushbutton', 'String', '下一个', 'Position', [450, 50, 80, 30], 'Callback', {@next_file_callback, fig});

uicontrol('Style', 'pushbutton', 'String', '保存并退出', 'Position', [600, 50, 100, 30], 'Callback', {@save_and_exit_callback, fig});

% 将 handles 结构体存储在 figure 的 UserData 中
set(fig, 'UserData', handles);

% 初始化显示第一个文件
display_file(fig);

% --- 回调函数 ---
% 所有回调函数现在都接受 figure 句柄作为输入，并通过它获取 handles

function display_file(fig)
    handles = get(fig, 'UserData');
    
    if handles.current_file_index < 1
        handles.current_file_index = 1;
    elseif handles.current_file_index > handles.num_files
        handles.current_file_index = handles.num_files;
    end
    
    file_name = handles.file_list(handles.current_file_index).name;
    full_file_path = fullfile(handles.folder_path, file_name);
    
    try
        data = importdata(full_file_path);
        signal_data = data(:, 1);
        
        ax = findobj(fig, 'Type', 'axes');
        cla(ax);
        
        plot(ax, signal_data);
        title(ax, ['原始信号图: ', file_name], 'Interpreter', 'none');
        
        set(handles.file_name_text, 'String', ['当前文件：', file_name]);
        set(handles.progress_text, 'String', sprintf('%d / %d', handles.current_file_index, handles.num_files));
        
        is_bad = ismember(file_name, handles.bad_quality_files);
        set(handles.bad_quality_checkbox, 'Value', is_bad);

    catch ME
        errordlg(['加载文件失败: ', file_name, newline, ME.message], '文件错误');
        handles.current_file_index = handles.current_file_index + 1;
        set(fig, 'UserData', handles); % 更新 handles
        if handles.current_file_index <= handles.num_files
            display_file(fig);
        else
            save_and_exit(fig);
        end
    end
end

function record_checkbox_state(fig)
    handles = get(fig, 'UserData');
    file_name = handles.file_list(handles.current_file_index).name;
    is_checked = get(handles.bad_quality_checkbox, 'Value');
    
    if is_checked && ~ismember(file_name, handles.bad_quality_files)
        handles.bad_quality_files{end+1} = file_name;
        disp(['已标记文件: ', file_name, ' 为质量不佳。']);
    elseif ~is_checked && ismember(file_name, handles.bad_quality_files)
        handles.bad_quality_files(ismember(handles.bad_quality_files, file_name)) = [];
        disp(['已取消标记文件: ', file_name]);
    end
    
    set(fig, 'UserData', handles); % 更新 handles
end

function next_file_callback(~, ~, fig)
    record_checkbox_state(fig);
    handles = get(fig, 'UserData');
    if handles.current_file_index < handles.num_files
        handles.current_file_index = handles.current_file_index + 1;
        set(fig, 'UserData', handles);
        display_file(fig);
    else
        save_and_exit(fig);
    end
end

function prev_file_callback(~, ~, fig)
    record_checkbox_state(fig);
    handles = get(fig, 'UserData');
    if handles.current_file_index > 1
        handles.current_file_index = handles.current_file_index - 1;
        set(fig, 'UserData', handles);
        display_file(fig);
    else
        disp('已是第一个文件。');
    end
end

function save_and_exit_callback(~, ~, fig)
    record_checkbox_state(fig);
    save_and_exit(fig);
end

function save_and_exit(fig)
    handles = get(fig, 'UserData');
    if ~isempty(handles.bad_quality_files)
        output_file = fullfile(handles.folder_path, 'bad_quality_files.txt');
        fid = fopen(output_file, 'wt');
        if fid == -1
            errordlg('无法创建记录文件。', '文件写入错误');
            return;
        end
        fprintf(fid, '%s\n', handles.bad_quality_files{:});
        fclose(fid);
        disp('----------------------------------');
        disp(['已将质量不佳的文件名保存到: ', output_file]);
        disp('----------------------------------');
    else
        disp('没有文件被标记为质量不佳。');
    end
    close(fig);
end