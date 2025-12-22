% 测试MATLAB读取Python生成的mat文件
% 检查字段类型和内容

clc;
clear;

fprintf('测试MATLAB读取Python生成的mat文件\n');
fprintf('==================================================\n\n');

% 首先生成一个测试文件
fprintf('步骤1: 使用Python生成测试mat文件...\n');
[status, result] = system('python test_mat_format.py');

% 创建Python脚本来生成持久化的测试文件
python_code = [...
    'import numpy as np\n' ...
    'from scipy.io import savemat\n' ...
    'time_axis = np.arange(0, 10, 0.004)\n' ...
    'original_signal = np.sin(2 * np.pi * 10 * time_axis)\n' ...
    'processed_signal = 0.8 * np.sin(2 * np.pi * 10 * time_axis)\n' ...
    'plot_data = {\n' ...
    '    ''time_axis'': time_axis,\n' ...
    '    ''original_signal'': original_signal,\n' ...
    '    ''processed_signal'': processed_signal,\n' ...
    '    ''fs'': np.array([250]),\n' ...
    '    ''filename'': ''test_file.txt'',\n' ...
    '    ''stage_name'': ''静息''\n' ...
    '}\n' ...
    'savemat(''matlab_test.mat'', plot_data, oned_as=''column'', do_compression=False)\n' ...
    'print(''测试文件已生成: matlab_test.mat'')\n'
];

% 写入临时Python脚本
fid = fopen('temp_gen_mat.py', 'w', 'n', 'UTF-8');
fprintf(fid, '%s', python_code);
fclose(fid);

% 执行Python脚本
[status, cmdout] = system('python temp_gen_mat.py');
fprintf('%s\n', cmdout);

% 删除临时脚本
delete('temp_gen_mat.py');

% 检查文件是否存在
if ~isfile('matlab_test.mat')
    error('测试文件生成失败！');
end

fprintf('\n步骤2: MATLAB读取测试文件...\n');

try
    % 读取mat文件
    data = load('matlab_test.mat');
    
    fprintf('\n成功读取！文件包含以下字段:\n');
    fields = fieldnames(data);
    for i = 1:length(fields)
        field_name = fields{i};
        field_value = data.(field_name);
        fprintf('  %s: ', field_name);
        fprintf('class=%s, ', class(field_value));
        fprintf('size=[%s]\n', num2str(size(field_value)));
    end
    
    % 测试字符串字段的读取
    fprintf('\n步骤3: 测试字符串字段读取...\n');
    
    fprintf('\nfilename字段:\n');
    fprintf('  原始类型: %s\n', class(data.filename));
    fprintf('  原始大小: [%s]\n', num2str(size(data.filename)));
    fprintf('  原始内容: %s\n', mat2str(data.filename));
    
    % 尝试转换为字符串
    if iscell(data.filename)
        filename_str = data.filename{1};
    elseif ischar(data.filename)
        filename_str = data.filename;
    else
        filename_str = char(data.filename);
    end
    fprintf('  转换后的字符串: %s\n', filename_str);
    
    fprintf('\nstage_name字段:\n');
    fprintf('  原始类型: %s\n', class(data.stage_name));
    fprintf('  原始大小: [%s]\n', num2str(size(data.stage_name)));
    
    % 尝试转换为字符串
    if iscell(data.stage_name)
        stage_name_str = data.stage_name{1};
    elseif ischar(data.stage_name)
        stage_name_str = data.stage_name;
    else
        stage_name_str = char(data.stage_name);
    end
    fprintf('  转换后的字符串: %s\n', stage_name_str);
    
    % 测试数值字段
    fprintf('\n步骤4: 测试数值字段...\n');
    fprintf('  time_axis: min=%.4f, max=%.4f, length=%d\n', ...
        min(data.time_axis), max(data.time_axis), length(data.time_axis));
    fprintf('  original_signal: min=%.4f, max=%.4f\n', ...
        min(data.original_signal), max(data.original_signal));
    fprintf('  processed_signal: min=%.4f, max=%.4f\n', ...
        min(data.processed_signal), max(data.processed_signal));
    
    fprintf('\n测试成功！\n');
    
catch ME
    fprintf('\n错误: %s\n', ME.message);
    fprintf('错误堆栈:\n');
    for i = 1:length(ME.stack)
        fprintf('  文件: %s, 行: %d, 函数: %s\n', ...
            ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
    end
end

% 清理测试文件
if isfile('matlab_test.mat')
    delete('matlab_test.mat');
    fprintf('\n已删除测试文件: matlab_test.mat\n');
end

fprintf('\n==================================================\n');
fprintf('测试完成！\n');
