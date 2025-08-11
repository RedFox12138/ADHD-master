% 清除工作区和命令窗口
clear;
clc;

% 参数设置
high_threshold = 3;   % 高阈值（根据实际数据调整）
low_threshold = -2;   % 低阈值（根据实际数据调整）
min_peak_distance = 50; % 最小尖峰间隔（样本点）
txt_filename = 'D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电\0519 XY额头干电极_processed.txt'; % 替换为你的TXT文件名

% 1. 从TXT文件读取数据
% 假设TXT文件中只有一列数据（眼电信号）
try
    eog_signal = load(txt_filename);
catch
    error('无法读取文件，请检查文件名和路径');
end

% 转换为列向量（如果还不是）
eog_signal = eog_signal(:);

% 2. 检测高阈值尖峰（正尖峰）
[high_peaks, high_locs] = findpeaks(eog_signal, ...
                                   'MinPeakHeight', high_threshold, ...
                                   'MinPeakDistance', min_peak_distance);

% 3. 检测低阈值尖峰（负尖峰）
% 对信号取反以检测负尖峰
[low_peaks, low_locs] = findpeaks(-eog_signal, ...
                                 'MinPeakHeight', -low_threshold, ...
                                 'MinPeakDistance', min_peak_distance);
low_peaks = -low_peaks; % 恢复原始值

% 4. 计算平均幅值
high_peaks_mean = mean(high_peaks);
low_peaks_mean = mean(low_peaks);

% 5. 显示结果
fprintf('检测到的高尖峰数量: %d\n', length(high_peaks));
fprintf('高尖峰平均幅值: %.2f\n', high_peaks_mean);
fprintf('检测到的低尖峰数量: %d\n', length(low_peaks));
fprintf('低尖峰平均幅值: %.2f\n', low_peaks_mean);

% 6. 绘制结果图
figure;
plot(eog_signal, 'b-', 'DisplayName', 'EOG信号');
hold on;
plot(high_locs, high_peaks, 'r^', 'MarkerFaceColor', 'r', 'DisplayName', '高尖峰');
plot(low_locs, low_peaks, 'gv', 'MarkerFaceColor', 'g', 'DisplayName', '低尖峰');
yline(high_threshold, '--r', '高阈值', 'DisplayName', '高阈值');
yline(low_threshold, '--g', '低阈值', 'DisplayName', '低阈值');
hold off;

title('眼电信号尖峰检测');
xlabel('样本点');
ylabel('幅值');
legend('Location', 'best');
grid on;
%%
% 清除工作区和命令窗口
clear;
clc;

% 参数设置
txt_filename = 'D:\Pycharm_Projects\ADHD-master\data\额头信号\0519 SF头部凝胶.txt'; % 替换为你的TXT文件名
window_size = 100; % 用于计算包络的滑动窗口大小（样本点）
smoothing_factor = 0.1; % 包络平滑因子（0-1之间，越小越平滑）

% 1. 从TXT文件读取数据
try
    signal = load(txt_filename);
catch
    error('无法读取文件，请检查文件名和路径');
end

% 转换为列向量（如果还不是）
signal = signal(:);

% 2. 计算上包络（upper envelope）
upper_env = movmax(signal, window_size); % 滑动窗口最大值
upper_env = smoothdata(upper_env, 'gaussian', round(window_size*smoothing_factor)); % 平滑处理

% 3. 计算下包络（lower envelope）
lower_env = movmin(signal, window_size); % 滑动窗口最小值
lower_env = smoothdata(lower_env, 'gaussian', round(window_size*smoothing_factor)); % 平滑处理

% 4. 计算包络差值
envelope_diff = upper_env - lower_env;

% 5. 计算包络差值的平均值
mean_diff = mean(envelope_diff);

% 6. 显示结果
fprintf('信号上下包络差值的平均值: %.4f\n', mean_diff);

% 7. 绘制结果图
figure;
plot(signal, 'b-', 'DisplayName', '原始信号');
hold on;
plot(upper_env, 'r-', 'LineWidth', 1.5, 'DisplayName', '上包络');
plot(lower_env, 'g-', 'LineWidth', 1.5, 'DisplayName', '下包络');
plot(envelope_diff, 'm-', 'LineWidth', 1.5, 'DisplayName', '包络差值');
hold off;

title('干电极信号包络分析');
xlabel('样本点');
ylabel('幅值');
legend('Location', 'best');
grid on;

% 单独绘制包络差值
figure;
plot(envelope_diff, 'm-', 'LineWidth', 1.5);
title('上下包络差值');
xlabel('样本点');
ylabel('差值幅值');
grid on;