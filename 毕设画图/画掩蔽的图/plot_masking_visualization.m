%% 画掩蔽的图脚本
% 复现 DAT-Net-Unsupervised-v2/unsupervised_artifact_v2.py 中的伪影加权和相邻域掩蔽过程
% 功能：画三张图
%   1. 原始信号
%   2. 原始信号叠加伪影概率阴影
%   3. 原始信号执行掩蔽后的图
% 
% 画图风格参考: ADHD-master/毕设画图/绘制真实的眼动伪影/plot_artifacts.m

clear; close all; clc;

%% ==================== 1. 参数设置 (人为可选) ====================
sample_idx = 2;        % <--- 【请在此处修改】 选择要画的信号索引（每个样本已经是6秒数据）

% 数据路径配置
real_data_path = 'D:\Pycharm_Projects\EOG Remove\真实数据集\eog_dataset.mat';

% 算法参数（按照用户指定的参数）
fs = 250;                   % 采样率
MASK_BASE = 0.1;           % 基础掩蔽概率
BOOST_SCALE = 0.3;         % 伪影区域额外增加的掩蔽强度
ARTIFACT_WIN_SIZE = 150;   % 伪影概率计算的窗口大小
MASK_NEIGHBORHOOD = 35;    % 相邻域掩蔽的邻域半径
LOWPASS_CUTOFF = 4.0;      % 伪影检测的低频截止频率


%% ==================== 2. 加载数据 ====================
fprintf('正在加载数据 (Sample %d)...\n', sample_idx);

if ~exist(real_data_path, 'file')
    error('无法找到数据文件: %s', real_data_path);
end

data_struct = load(real_data_path);

% 自动查找数据字段
field_names = fieldnames(data_struct);
data_found = false;
raw_data = [];

% 尝试常见的字段名
candidate_fields = {'eog_dataset', 'eeg_data', 'data', 'Test_Contaminated'};
for i = 1:length(candidate_fields)
    if isfield(data_struct, candidate_fields{i})
        raw_data = data_struct.(candidate_fields{i});
        fprintf('使用字段: %s\n', candidate_fields{i});
        data_found = true;
        break;
    end
end

if ~data_found
    fprintf('未找到常见字段，使用第一个字段: %s\n', field_names{1});
    raw_data = data_struct.(field_names{1});
end

% 数据格式：raw_data 是 (n, 1500)，n是样本数，1500是6秒的数据长度
[num_samples, signal_length] = size(raw_data);
fprintf('数据集形状: %d 样本 x %d 采样点\n', num_samples, signal_length);

% 检查样本索引有效性
if sample_idx < 1 || sample_idx > num_samples
    error('样本索引 %d 超出范围 (有效范围: 1 - %d)', sample_idx, num_samples);
end

% 提取指定样本（已经是6秒数据）
x = double(raw_data(sample_idx, :));  % 取第 sample_idx 行
N = length(x);
t = (0:N-1) / fs;

fprintf('已选择样本 %d, 信号长度: %d 样本 (%.2f 秒)\n', sample_idx, N, N/fs);


%% ==================== 3. 计算伪影概率 ====================
fprintf('\n计算伪影概率...\n');
p_art = compute_artifact_prob_v2(x, fs, ARTIFACT_WIN_SIZE, LOWPASS_CUTOFF);
fprintf('  伪影概率范围: [%.4f, %.4f]\n', min(p_art), max(p_art));


%% ==================== 4. 计算掩蔽概率并生成掩蔽 ====================
fprintf('\n生成掩蔽...\n');
p_mask = MASK_BASE + BOOST_SCALE * p_art;
p_mask = min(max(p_mask, 0.0), 1.0);

% 使用固定随机种子
rng(sample_idx + 42);
random_vals = rand(size(p_mask));
mask = double(random_vals < p_mask);
fprintf('  实际掩蔽点数: %d / %d (%.1f%%)\n', sum(mask), N, 100*sum(mask)/N);

% 生成掩蔽后的信号
x_masked = generate_masked_signal(x, mask, MASK_NEIGHBORHOOD);


%% ==================== 5. 绘制三张图 ====================
fprintf('\n正在生成图像...\n');

% 图1: 原始信号
figure('Position', [100, 100, 1000, 600], 'Color', 'none');
plot(t, x, 'b', 'LineWidth', 2.5);
xlim([0, max(t)]);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (\muV)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
fprintf('  图1: 原始信号 - 完成\n');

% 图2: 原始信号叠加伪影概率阴影
figure('Position', [150, 150, 1000, 600], 'Color', 'none');
hold on;

% 绘制伪影概率阴影（使用归一化到信号幅度范围）
y_min = min(x);
y_max = max(x);
y_range = y_max - y_min;

% 将概率映射到信号幅度范围作为阴影高度
for i = 1:length(t)
    if p_art(i) > 0.01  % 只绘制有明显概率的区域
        % 阴影从 y_min 到 y_min + p_art(i) * y_range
        patch([t(i)-0.002 t(i)+0.002 t(i)+0.002 t(i)-0.002], ...
              [y_min y_min y_min+p_art(i)*y_range y_min+p_art(i)*y_range], ...
              [1 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
    end
end

% 绘制原始信号
plot(t, x, 'b', 'LineWidth', 2.5);

xlim([0, max(t)]);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (\muV)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
hold off;
fprintf('  图2: 原始信号+伪影概率阴影 - 完成\n');

% 图3: 原始信号执行掩蔽后的图
figure('Position', [200, 200, 1000, 600], 'Color', 'none');
hold on;

% 先绘制掩蔽后的信号（红色）
plot(t, x_masked, 'Color', [0.8 0.2 0.2], 'LineWidth', 2.5);

% 后绘制原始信号（浅灰色），覆盖在上面
plot(t, x, 'Color', [0.6 0.6 0.6], 'LineWidth', 1.8);

% 添加图例：相邻域替换的信号 与 原始信号
legend({'相邻域替换信号', '原始信号'}, 'Location', 'best', 'FontSize', 20);

xlim([0, max(t)]);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (\muV)', 'FontSize', 28, 'FontWeight', 'bold');
grid on;
hold off;
fprintf('  图3: 掩蔽后的信号 - 完成\n');

% 图4: 掩蔽概率时序图（p_mask）及实际掩蔽点
figure('Position', [250, 250, 1000, 400], 'Color', 'none');
hold on;

% 绘制掩蔽概率曲线
plot(t, p_mask, 'k-', 'LineWidth', 2.5);



ylim([-0.05, 1.05]);
xlim([0, max(t)]);
set(gca, 'Color', 'none', 'FontSize', 24, 'LineWidth', 1.2);
xlabel('Time (s)', 'FontSize', 24, 'FontWeight', 'bold');
% 使用 LaTeX 解释器显示数学公式 P_{art}^{(t)}
ylabel('$P_{art}^{(t)}$', 'Interpreter', 'latex', 'FontSize', 24, 'FontWeight', 'bold');
grid on;
hold off;
fprintf('  图4: 掩蔽概率时序图 - 完成\n');

fprintf('\n所有图像已生成完成！\n\n');


%% ==================== 辅助函数定义 ====================

function p_art = compute_artifact_prob_v2(x, fs, win_size, lowpass_cutoff)
    % 复现Python的 compute_artifact_prob_v2 函数
    % 输入:
    %   x: (1, L) 原始单通道 EEG
    %   fs: 采样率
    %   win_size: 滑动窗口大小
    %   lowpass_cutoff: 低频能量计算的截止频率
    % 输出:
    %   p_art: (1, L) 每个时间点的伪影概率，范围 [0, 1]
    
    eps = 1e-8;
    
    % 1) 局部幅度: 局部平均绝对值
    amp = moving_average_func(abs(x), win_size);
    
    % 2) 局部变化速度: |x(t+1)-x(t)| 的窗口平均
    diff_sig = [abs(diff(x)), 0];  % 补零恢复长度
    diff_sig = moving_average_func(diff_sig, win_size);
    
    % 3) 低频能量占比 r(t)
    x_low = fft_lowpass_func(x, fs, lowpass_cutoff);
    power_low = moving_average_func(x_low .^ 2, win_size);
    power_total = moving_average_func(x .^ 2, win_size);
    r = power_low ./ (power_total + eps);
    r = min(r, 1.0);  % 限制在[0,1]
    
    % 4) MAD归一化
    amp_n = mad_normalize_func(amp);
    diff_n = mad_normalize_func(diff_sig);
    r_n = mad_normalize_func(r);
    
    % 5) 线性加权得到分数 s(t)
    s = amp_n + diff_n + r_n;
    
    % 6) 非线性映射：减去 70% 分位数阈值，再 sigmoid
    tau = quantile(s, 0.7);
    alpha = 10.0;
    p_art = 1 ./ (1 + exp(-alpha * (s - tau)));
    p_art = min(max(p_art, 0), 1);  % 限制在[0,1]
end


function x_masked = generate_masked_signal(x, mask, neighborhood)
    % 生成掩蔽后的信号（相邻域替换）
    % 输入:
    %   x: (1, L) 原始信号
    %   mask: (1, L) 0/1掩码，1表示该点被掩蔽
    %   neighborhood: 邻域半径
    % 输出:
    %   x_masked: (1, L) 掩蔽后的信号
    
    L = length(x);
    x_masked = x;  % 复制原信号
    
    if neighborhood <= 0
        % 如果邻域为0，直接置为0
        x_masked(mask > 0) = 0;
        return;
    end
    
    % 找到所有被掩蔽的位置
    masked_indices = find(mask > 0);
    
    for idx = masked_indices
        % 生成随机偏移量 [-neighborhood, neighborhood]，排除0
        offset = randi([-neighborhood, neighborhood]);
        while offset == 0
            offset = randi([-neighborhood, neighborhood]);
        end
        
        % 计算替换位置，并确保在有效范围内
        replace_idx = idx + offset;
        replace_idx = max(1, min(L, replace_idx));
        
        % 用邻域值替换
        x_masked(idx) = x(replace_idx);
    end
end


function y = moving_average_func(x, win_size)
    % 滑动窗口平均
    if win_size <= 1
        y = x;
        return;
    end
    kernel = ones(1, win_size) / win_size;
    y = conv(x, kernel, 'same');
end


function x_low = fft_lowpass_func(x, fs, cutoff)
    % FFT低通滤波
    L = length(x);
    
    % FFT
    X = fft(x);
    freqs = (0:L-1) * fs / L;
    
    % 低通滤波（双边谱）
    mask = freqs <= cutoff | freqs >= (fs - cutoff);
    X_low = X .* mask;
    
    % IFFT
    x_low = real(ifft(X_low));
end


function x_n = mad_normalize_func(x)
    % MAD归一化（中位数绝对偏差）
    eps = 1e-8;
    
    med = median(x);
    mad_val = median(abs(x - med));
    mad_val = max(mad_val, eps);
    
    x_n = (x - med) / mad_val;
end

