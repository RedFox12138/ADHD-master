%% 单个文件预处理各阶段绘图脚本（简化版）
% 用途：快速绘制指定的单个预处理数据文件
% 使用方法：修改下面的 target_filename 变量，然后运行脚本

clear; close all; clc;
%% ========== 在这里指定要绘制的文件名 ==========
target_filename = '1013 TY额头躲避游戏2_静息_preprocessing_stages.mat';
% ==============================================

%% 配置参数
data_folder = 'D:\Pycharm_Projects\ADHD-master\毕设画图\预处理各阶段数据';
output_folder = 'D:\Pycharm_Projects\ADHD-master\毕设画图\预处理图像';

% 创建输出文件夹
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% 完整文件路径
mat_path = fullfile(data_folder, target_filename);

% 检查文件是否存在
if ~exist(mat_path, 'file')
    error('未找到文件: %s\n请检查文件名是否正确！', mat_path);
end

fprintf('====================================\n');
fprintf('正在处理: %s\n', target_filename);
fprintf('====================================\n\n');

%% 加载数据
data = load(mat_path);

% 提取信号和采样率
original = data.original;              % 原始数据
after_notch = data.after_notch;        % 陷波后（50Hz+100Hz）
after_bandpass = data.after_bandpass;  % 陷波+带通后
fs = data.fs;

% 计算时间轴
N = length(original);
t = (0:N-1) / fs;

fprintf('信号长度: %d 个点 (%.2f秒)\n', N, N/fs);
fprintf('采样率: %.0f Hz\n\n', fs);

%% 计算固定的频域坐标范围
% 频域：需要计算所有信号的频谱后统一范围
[freq1, amp_db1] = compute_fft_spectrum(original, fs);
[freq2, amp_db2] = compute_fft_spectrum(after_notch, fs);
[freq3, amp_db3] = compute_fft_spectrum(after_bandpass, fs);

% 只考虑0-120Hz范围内的数据
idx_freq = freq1 <= 120;
all_amp_db = [amp_db1(idx_freq); amp_db2(idx_freq); amp_db3(idx_freq)];
all_amp_db(isinf(all_amp_db) | isnan(all_amp_db)) = [];  % 去除无穷大值和NaN

% 调试信息
fprintf('频谱数据统计:\n');
fprintf('  有效数据点数: %d\n', length(all_amp_db));
if ~isempty(all_amp_db)
    fprintf('  最小值: %.2f dB\n', min(all_amp_db));
    fprintf('  最大值: %.2f dB\n', max(all_amp_db));
end

% 检查是否有有效数据并计算范围
if isempty(all_amp_db)
    fprintf('  警告: 没有有效频谱数据，使用默认范围\n');
    y_lim_freq = [-100, 0];  % 默认范围
else
    y_min_freq = min(all_amp_db);
    y_max_freq = max(all_amp_db);
    
    % 确保最大最小值不相同
    if abs(y_max_freq - y_min_freq) < 1e-6
        % 如果范围太小，使用信号值为中心的固定范围
        center = (y_max_freq + y_min_freq) / 2;
        if ~isfinite(center)
            y_lim_freq = [-100, 0];
        else
            y_lim_freq = [center - 10, center + 10];
        end
    else
        y_margin_freq = (y_max_freq - y_min_freq) * 0.1;
        y_lim_freq = [y_min_freq - y_margin_freq, y_max_freq + y_margin_freq];
    end
end

% 最后检查确保范围有效
if ~isfinite(y_lim_freq(1)) || ~isfinite(y_lim_freq(2)) || y_lim_freq(1) >= y_lim_freq(2)
    fprintf('  警告: 计算的Y轴范围无效 [%.2f, %.2f]，使用默认范围\n', y_lim_freq(1), y_lim_freq(2));
    y_lim_freq = [-100, 0];  % 强制使用默认范围
end

% 确保是行向量并且是double类型
y_lim_freq = double(y_lim_freq(:)');
if length(y_lim_freq) ~= 2
    fprintf('  警告: Y轴范围不是2元素向量，使用默认范围\n');
    y_lim_freq = [-100, 0];
end

fprintf('固定频域坐标范围:\n');
fprintf('  频域 Y轴: [%.2f, %.2f] dB (类型: %s, 大小: %dx%d)\n', ...
    y_lim_freq(1), y_lim_freq(2), class(y_lim_freq), size(y_lim_freq, 1), size(y_lim_freq, 2));
fprintf('  频域 X轴: [0, 120] Hz\n');
fprintf('  时域 Y轴: 自动调整\n\n');

%% 1. 原始信号 - 时域
fprintf('正在绘制原始信号 - 时域...\n');
figure('Position', [100, 100, 1000, 600], 'Color', 'none');
plot(t, original, 'b', 'LineWidth', 2.5);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('time (s)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (mV)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
xlim([0, max(t)]);

%% 2. 原始信号 - 频域
fprintf('正在绘制原始信号 - 频域...\n');
figure('Position', [100, 100, 1000, 600], 'Color', 'none');
plot(freq1, amp_db1, 'b', 'LineWidth', 2.5);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('Frequency (Hz)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (dB)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
xlim([0, 120]);
ylim(y_lim_freq);

%% 3. 陷波后 - 时域
fprintf('正在绘制陷波后 - 时域...\n');
figure('Position', [100, 100, 1000, 600], 'Color', 'none');
plot(t, after_notch, 'b', 'LineWidth', 2.5);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('time (s)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (mV)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
xlim([0, max(t)]);

%% 4. 陷波后 - 频域
fprintf('正在绘制陷波后 - 频域...\n');
figure('Position', [100, 100, 1000, 600], 'Color', 'none');
plot(freq2, amp_db2, 'b', 'LineWidth', 2.5);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('Frequency (Hz)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (dB)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
xlim([0, 120]);
ylim(y_lim_freq);

%% 5. 陷波+带通后 - 时域
fprintf('正在绘制陷波+带通后 - 时域...\n');
figure('Position', [100, 100, 1000, 600], 'Color', 'none');
plot(t, after_bandpass, 'b', 'LineWidth', 2.5);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('time (s)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (mV)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
xlim([0, max(t)]);

%% 6. 陷波+带通后 - 频域
fprintf('正在绘制陷波+带通后 - 频域...\n');
figure('Position', [100, 100, 1000, 600], 'Color', 'none');
plot(freq3, amp_db3, 'b', 'LineWidth', 2.5);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('Frequency (Hz)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (dB)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
xlim([0, 120]);
ylim(y_lim_freq);

fprintf('完成！已生成6个独立的figure窗口\n');



%% 完成
fprintf('\n====================================\n');
fprintf('处理完成！\n');
fprintf('共生成6个独立的figure窗口\n');
fprintf('====================================\n');

%% 辅助函数：计算FFT频谱
function [freq, amplitude_db] = compute_fft_spectrum(signal, fs)
    N = length(signal);
    % 计算FFT
    Y = fft(signal);
    % 取单边谱
    P2 = abs(Y/N);
    P1 = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2*P1(2:end-1);
    % 转换为dB
    amplitude_db = 20*log10(P1);  % 使用20*log10用于幅度
    % 频率轴
    freq = fs*(0:floor(N/2))/N;
end
