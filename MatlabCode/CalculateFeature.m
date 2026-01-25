%% 批量特征对比分析脚本 - 多子目录特征对比
% 功能：对指定目录下的所有子文件夹分别进行特征提取和对比分析
% 适用场景：
%   - 不同窗口大小的比较 (2s, 4s, 6s, 8s)
%   - 不同受试者组别的比较 (ADHD, Control)
%   - 不同条件的比较 (任意子目录结构)
clc;
close all;
clear all;
perm_wt_val_w = 4;
inv_alpha_val_w = 0.6;
%% 设置图形不显示（避免在无显示环境中报错）
set(0, 'DefaultFigureVisible', 'off');

%% ========== 用户配置区 ==========
% 方式1: 直接指定根目录
% root_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat';

% 方式2: 用户选择文件夹（推荐）
root_folder = uigetdir('D:\Pycharm_Projects\ADHD-master\data', '选择包含多个子文件夹的根目录');
if root_folder == 0
    error('用户取消了文件夹选择');
end

Fs = 250; % 采样率 (Hz)

% 特征计算参数
theta_band = [4, 8];
beta_band = [14, 25];

%% 自动扫描所有子文件夹
if ~exist(root_folder, 'dir')
    error('输入文件夹不存在: %s', root_folder);
end

fprintf('========== 多子目录批量特征对比分析 ==========\n');
fprintf('根目录: %s\n', root_folder);
fprintf('正在扫描子文件夹...\n');

% 获取所有子文件夹
dir_info = dir(root_folder);
subfolder_names = {};
for i = 1:length(dir_info)
    if dir_info(i).isdir && ~strcmp(dir_info(i).name, '.') && ~strcmp(dir_info(i).name, '..')
        % 检查子文件夹中是否有.mat文件
        subfolder_path = fullfile(root_folder, dir_info(i).name);
        mat_files = dir(fullfile(subfolder_path, '*.mat'));
        if ~isempty(mat_files)
            subfolder_names{end+1} = dir_info(i).name;
        end
    end
end

if isempty(subfolder_names)
    error('未找到包含.mat文件的子文件夹！');
end

n_subfolders = length(subfolder_names);
fprintf('找到 %d 个有效子文件夹: %s\n\n', n_subfolders, strjoin(subfolder_names, ', '));

%% 添加feature目录到路径
addpath(fullfile(fileparts(mfilename('fullpath')), 'feature'));

%% 定义要测试的特征
% 线性频谱特征 + 非线性动力学特征
% feature_names = {'SampEn', 'FuzzEn', 'XSampEn', 'SampEn2D', 'MvSampEn', ...  % 样本熵系列
%                  'MSEn_CI', 'MvMSE', 'cMSEn', 'cXMSE', 'cMvMSE', ...  % 多尺度熵系列
%                  'PermEn', 'PermEn_FineGrain', 'PermEn_Modified', 'PermEn_AmpAware', ...  % 排列熵系列
%                  'PermEn_Weighted', 'PermEn_Edge', 'PermEn_Uniquant', 'XPermEn', ...  % 排列熵变体
%                  'LZC', ...  % 其他复杂度特征
%                  'HFD', 'FDD_Mean', 'FDD_Std', ...  % 分形特征
%                  'TBR', 'Pope_Index', 'Inverse_Alpha', 'Beta_Alpha_Ratio', 'Spectral_Slope', ...  % 频谱特征
%                  'WPE_IA_Product', 'WPE_IA_Weighted', 'WPE_IA_Ratio', 'WPE_IA_Composite', ...  % 组合特征
%                  'Complexity_Activity', 'Complexity_Mobility', 'Complexity_Complexity'};  % Hjorth参数

feature_names = {'SampEn','FuzzEn','XSampEn','PermEn','LZC','HFD','TBR'};
n_features = length(feature_names);

% 初始化多子目录存储结构: subfolder_features{子目录索引}.特征名.{rest/attention}
subfolder_features = cell(n_subfolders, 1);
for s = 1:n_subfolders
    subfolder_features{s} = struct();
    for f = 1:n_features
        subfolder_features{s}.(feature_names{f}).rest = [];
        subfolder_features{s}.(feature_names{f}).attention = [];
    end
end

% 初始化存储每个受试者所有样本特征值的结构（用于生成箱型图）
subject_features = struct();
for f = 1:n_features
    subject_features.(feature_names{f}) = struct();
    subject_features.(feature_names{f}).data = {};  % 细胞数组，每个元素是一个受试者的所有样本值
    subject_features.(feature_names{f}).subject_names = {};  % 受试者名称
    subject_features.(feature_names{f}).subfolder_names = {};  % 所属子目录
end

%% 对每个子文件夹进行特征提取
for subfolder_idx = 1:n_subfolders
    subfolder_name = subfolder_names{subfolder_idx};
    input_folder = fullfile(root_folder, subfolder_name);
    
    fprintf('\n========================================\n');
    fprintf('处理子目录: %s\n', subfolder_name);
    fprintf('========================================\n');
    
    % 获取当前子文件夹下的所有mat文件
    mat_files = dir(fullfile(input_folder, '*.mat'));
    n_files = length(mat_files);
    fprintf('找到 %d 个mat文件\n', n_files);
    
    if n_files == 0
        warning('子目录 %s 文件夹为空，跳过', subfolder_name);
        continue;
    end
    
    % 批量计算特征
    fprintf('--- 开始提取特征 ---\n');
    count_processed = 0;
    count_failed = 0;
    
    for file_idx = 1:n_files
        filename = mat_files(file_idx).name;
        filepath = fullfile(input_folder, filename);
        
        fprintf('[%d/%d] %s\n', file_idx, n_files, filename);
        
        try
            % 加载数据
            data = load(filepath);
            
            if ~isfield(data, 'rest_samples') || ~isfield(data, 'attention_samples')
                fprintf('  警告: 缺少必需字段,跳过\n');
                count_failed = count_failed + 1;
                continue;
            end
            
            rest_samples = data.rest_samples;
            attention_samples = data.attention_samples;
            
            if isempty(rest_samples) || isempty(attention_samples)
                fprintf('  警告: 样本为空,跳过\n');
                count_failed = count_failed + 1;
                continue;
            end
            
            % 计算静息阶段特征
            n_rest = size(rest_samples, 1);
            for i = 1:n_rest
                segment = rest_samples(i, :);
                
                % === 熵特征 ===
                % SampEn: 样本熵，反映信号的复杂度和不可预测性
                if ismember('SampEn', feature_names)
                    Samp = SampEn(segment);
                    subfolder_features{subfolder_idx}.SampEn.rest = [subfolder_features{subfolder_idx}.SampEn.rest; Samp(3)];
                end
                
                % FuzzEn: 模糊熵，对噪声更鲁棒的熵度量
                if ismember('FuzzEn', feature_names)
                    Fuzz = FuzzEn(segment);
                    subfolder_features{subfolder_idx}.FuzzEn.rest = [subfolder_features{subfolder_idx}.FuzzEn.rest; Fuzz(1)];
                end
                
                % XSampEn: 交叉样本熵，分析前后两部分信号的交叉复杂度
                if ismember('XSampEn', feature_names)
                    try
                        mid_point = floor(length(segment) / 2);
                        if mid_point > 10
                            sig1 = segment(1:mid_point);
                            sig2 = segment(mid_point+1:end);
                            XSamp = XSampEn(sig1, sig2);
                            subfolder_features{subfolder_idx}.XSampEn.rest = [subfolder_features{subfolder_idx}.XSampEn.rest; XSamp(3)];
                        else
                            subfolder_features{subfolder_idx}.XSampEn.rest = [subfolder_features{subfolder_idx}.XSampEn.rest; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.XSampEn.rest = [subfolder_features{subfolder_idx}.XSampEn.rest; NaN];
                    end
                end
                
                % SampEn2D: 二维样本熵，用于分析信号的二维模式复杂度
                if ismember('SampEn2D', feature_names)
                    try
                        % 将一维信号转换为二维矩阵进行分析
                        % 使用延迟嵌入将信号重构为矩阵
                        embed_dim = 10;
                        if length(segment) >= embed_dim * embed_dim
                            mat_len = floor(length(segment) / embed_dim);
                            sig_mat = reshape(segment(1:mat_len*embed_dim), embed_dim, mat_len);
                            [SE2D, ~, ~] = SampEn2D(sig_mat);
                            subfolder_features{subfolder_idx}.SampEn2D.rest = [subfolder_features{subfolder_idx}.SampEn2D.rest; SE2D];
                        else
                            subfolder_features{subfolder_idx}.SampEn2D.rest = [subfolder_features{subfolder_idx}.SampEn2D.rest; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.SampEn2D.rest = [subfolder_features{subfolder_idx}.SampEn2D.rest; NaN];
                    end
                end
                
                % MvSampEn: 多变量样本熵，分析多通道信号的联合复杂度
                if ismember('MvSampEn', feature_names)
                    try
                        % 将单通道信号分段作为多变量数据
                        n_channels = 3;
                        seg_len = floor(length(segment) / n_channels);
                        if seg_len > 10
                            mv_data = zeros(seg_len, n_channels);
                            for ch = 1:n_channels
                                mv_data(:, ch) = segment((ch-1)*seg_len+1:ch*seg_len);
                            end
                            [MSamp, ~, ~, ~] = MvSampEn(mv_data);
                            subfolder_features{subfolder_idx}.MvSampEn.rest = [subfolder_features{subfolder_idx}.MvSampEn.rest; MSamp];
                        else
                            subfolder_features{subfolder_idx}.MvSampEn.rest = [subfolder_features{subfolder_idx}.MvSampEn.rest; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.MvSampEn.rest = [subfolder_features{subfolder_idx}.MvSampEn.rest; NaN];
                    end
                end
                
                % MvMSE: 多变量多尺度熵，综合多通道多尺度的复杂度分析
                if ismember('MvMSE', feature_names)
                    try
                        n_channels = 3;
                        seg_len = floor(length(segment) / n_channels);
                        if seg_len > 30
                            mv_data = zeros(seg_len, n_channels);
                            for ch = 1:n_channels
                                mv_data(:, ch) = segment((ch-1)*seg_len+1:ch*seg_len);
                            end
                            Mobj = struct('Func', @MvSampEn);
                            [~, CI] = MvMSEn(mv_data, Mobj, 'Scales', 3);
                            subfolder_features{subfolder_idx}.MvMSE.rest = [subfolder_features{subfolder_idx}.MvMSE.rest; CI];
                        else
                            subfolder_features{subfolder_idx}.MvMSE.rest = [subfolder_features{subfolder_idx}.MvMSE.rest; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.MvMSE.rest = [subfolder_features{subfolder_idx}.MvMSE.rest; NaN];
                    end
                end
                
                % MSEn: 多尺度熵，反映多时间尺度的复杂度
                if ismember('MSEn_CI', feature_names)
                    try
                        Mobj = struct('Func', @SampEn);
                        [~, CI] = MSEn(segment, Mobj, 'Scales', 5);
                        subfolder_features{subfolder_idx}.MSEn_CI.rest = [subfolder_features{subfolder_idx}.MSEn_CI.rest; CI];
                    catch
                        subfolder_features{subfolder_idx}.MSEn_CI.rest = [subfolder_features{subfolder_idx}.MSEn_CI.rest; NaN];
                    end
                end
                
                % cMSEn: 复合多尺度熵，改进的多尺度复杂度分析方法
                if ismember('cMSEn', feature_names)
                    try
                        Mobj = struct('Func', @SampEn);
                        [~, CI] = cMSEn(segment, Mobj, 'Scales', 5);
                        subfolder_features{subfolder_idx}.cMSEn.rest = [subfolder_features{subfolder_idx}.cMSEn.rest; CI];
                    catch
                        subfolder_features{subfolder_idx}.cMSEn.rest = [subfolder_features{subfolder_idx}.cMSEn.rest; NaN];
                    end
                end
                
                % cXMSE: 复合多尺度交叉熵，分析两段信号的交叉多尺度复杂度
                if ismember('cXMSE', feature_names)
                    try
                        mid_point = floor(length(segment) / 2);
                        if mid_point > 30
                            sig1 = segment(1:mid_point);
                            sig2 = segment(mid_point+1:end);
                            Mobj = struct('Func', @XSampEn);
                            [~, CI] = cXMSEn(sig1, sig2, Mobj, 'Scales', 3);
                            subfolder_features{subfolder_idx}.cXMSE.rest = [subfolder_features{subfolder_idx}.cXMSE.rest; CI];
                        else
                            subfolder_features{subfolder_idx}.cXMSE.rest = [subfolder_features{subfolder_idx}.cXMSE.rest; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.cXMSE.rest = [subfolder_features{subfolder_idx}.cXMSE.rest; NaN];
                    end
                end
                
                % cMvMSE: 复合多变量多尺度熵，改进的多通道多尺度复杂度分析
                if ismember('cMvMSE', feature_names)
                    try
                        n_channels = 3;
                        seg_len = floor(length(segment) / n_channels);
                        if seg_len > 30
                            mv_data = zeros(seg_len, n_channels);
                            for ch = 1:n_channels
                                mv_data(:, ch) = segment((ch-1)*seg_len+1:ch*seg_len);
                            end
                            Mobj = struct('Func', @MvSampEn);
                            [~, CI] = cMvMSEn(mv_data, Mobj, 'Scales', 3);
                            subfolder_features{subfolder_idx}.cMvMSE.rest = [subfolder_features{subfolder_idx}.cMvMSE.rest; CI];
                        else
                            subfolder_features{subfolder_idx}.cMvMSE.rest = [subfolder_features{subfolder_idx}.cMvMSE.rest; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.cMvMSE.rest = [subfolder_features{subfolder_idx}.cMvMSE.rest; NaN];
                    end
                end
                
                % === 排列熵系列 ===
                % PermEn: 标准排列熵（使用真实值，不用归一化）
                if ismember('PermEn', feature_names)
                    try
                        [perm_val, ~, ~] = PermEn(segment, 'm', 4);
                        subfolder_features{subfolder_idx}.PermEn.rest = [subfolder_features{subfolder_idx}.PermEn.rest; perm_val(end)];
                    catch
                        subfolder_features{subfolder_idx}.PermEn.rest = [subfolder_features{subfolder_idx}.PermEn.rest; NaN];
                    end
                end
                
                % PermEn_FineGrain: 细粒度排列熵，对时间序列的自然复杂性度量更精细
                if ismember('PermEn_FineGrain', feature_names)
                    try
                        perm_fg = getPermEn(segment, 'variant', 'finegrain');
                        subfolder_features{subfolder_idx}.PermEn_FineGrain.rest = [subfolder_features{subfolder_idx}.PermEn_FineGrain.rest; perm_fg];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_FineGrain.rest = [subfolder_features{subfolder_idx}.PermEn_FineGrain.rest; NaN];
                    end
                end
                
                % PermEn_Modified: 修正排列熵，改进的序数模式分析
                if ismember('PermEn_Modified', feature_names)
                    try
                        perm_mod = getPermEn(segment, 'variant', 'modified');
                        subfolder_features{subfolder_idx}.PermEn_Modified.rest = [subfolder_features{subfolder_idx}.PermEn_Modified.rest; perm_mod];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Modified.rest = [subfolder_features{subfolder_idx}.PermEn_Modified.rest; NaN];
                    end
                end
                
                % PermEn_AmpAware: 幅度感知排列熵，结合幅度信息的排列熵
                if ismember('PermEn_AmpAware', feature_names)
                    try
                        perm_amp = getPermEn(segment, 'variant', 'ampaware');
                        subfolder_features{subfolder_idx}.PermEn_AmpAware.rest = [subfolder_features{subfolder_idx}.PermEn_AmpAware.rest; perm_amp];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_AmpAware.rest = [subfolder_features{subfolder_idx}.PermEn_AmpAware.rest; NaN];
                    end
                end
                
                % PermEn_Weighted: 加权排列熵，整合幅度信息的复杂度度量
                if ismember('PermEn_Weighted', feature_names)
                    try
                        perm_wt = getPermEn(segment, 'variant', 'weighted');
                        subfolder_features{subfolder_idx}.PermEn_Weighted.rest = [subfolder_features{subfolder_idx}.PermEn_Weighted.rest; perm_wt];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Weighted.rest = [subfolder_features{subfolder_idx}.PermEn_Weighted.rest; NaN];
                    end
                end
                
                % PermEn_Edge: 边缘排列熵，改进的时序分析方法
                if ismember('PermEn_Edge', feature_names)
                    try
                        perm_edge = getPermEn(segment, 'variant', 'edge');
                        subfolder_features{subfolder_idx}.PermEn_Edge.rest = [subfolder_features{subfolder_idx}.PermEn_Edge.rest; perm_edge];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Edge.rest = [subfolder_features{subfolder_idx}.PermEn_Edge.rest; NaN];
                    end
                end
                
                % PermEn_Uniquant: 改进排列熵，在噪声条件下测量复杂性
                if ismember('PermEn_Uniquant', feature_names)
                    try
                        perm_uniq = getPermEn(segment, 'variant', 'uniquant', 'alpha', 4);
                        subfolder_features{subfolder_idx}.PermEn_Uniquant.rest = [subfolder_features{subfolder_idx}.PermEn_Uniquant.rest; perm_uniq];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Uniquant.rest = [subfolder_features{subfolder_idx}.PermEn_Uniquant.rest; NaN];
                    end
                end
                
                % XPermEn: 交叉排列熵，将信号分为前后两部分计算交叉熵
                if ismember('XPermEn', feature_names)
                    try
                        mid_point = floor(length(segment) / 2);
                        if mid_point > 10
                            sig1 = segment(1:mid_point);
                            sig2 = segment(mid_point+1:end);
                            xperm_val = XPermEn(sig1, sig2);
                            subfolder_features{subfolder_idx}.XPermEn.rest = [subfolder_features{subfolder_idx}.XPermEn.rest; xperm_val];
                        else
                            subfolder_features{subfolder_idx}.XPermEn.rest = [subfolder_features{subfolder_idx}.XPermEn.rest; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.XPermEn.rest = [subfolder_features{subfolder_idx}.XPermEn.rest; NaN];
                    end
                end
                
                % LZC: Lempel-Ziv复杂度，反映时间复杂性，注意态通常升高
                if ismember('LZC', feature_names)
                    try
                        lzc_val = calculateLZC(segment);
                        subfolder_features{subfolder_idx}.LZC.rest = [subfolder_features{subfolder_idx}.LZC.rest; lzc_val];
                    catch
                        subfolder_features{subfolder_idx}.LZC.rest = [subfolder_features{subfolder_idx}.LZC.rest; NaN];
                    end
                end
                
                % === 分形特征 ===
                % HFD: Higuchi分形维数，反映信号的分形复杂度
                if ismember('HFD', feature_names)
                    try
                        hfd_val = HigFracDim(segment, 10);
                        subfolder_features{subfolder_idx}.HFD.rest = [subfolder_features{subfolder_idx}.HFD.rest; hfd_val];
                    catch
                        subfolder_features{subfolder_idx}.HFD.rest = [subfolder_features{subfolder_idx}.HFD.rest; NaN];
                    end
                end
                
                % FDD: 分形维数分布，Mean反映整体复杂度，Std反映注意力波动
                if ismember('FDD_Mean', feature_names) || ismember('FDD_Std', feature_names)
                    try
                        [fdd_m, fdd_s] = calculateFDD(segment);
                        if ismember('FDD_Mean', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Mean.rest = [subfolder_features{subfolder_idx}.FDD_Mean.rest; fdd_m];
                        end
                        if ismember('FDD_Std', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Std.rest = [subfolder_features{subfolder_idx}.FDD_Std.rest; fdd_s];
                        end
                    catch
                        if ismember('FDD_Mean', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Mean.rest = [subfolder_features{subfolder_idx}.FDD_Mean.rest; NaN];
                        end
                        if ismember('FDD_Std', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Std.rest = [subfolder_features{subfolder_idx}.FDD_Std.rest; NaN];
                        end
                    end
                end
                
                % === 频谱特征 ===
                % TBR: Theta/Beta比率，ADHD的经典标记
                if ismember('TBR', feature_names)
                    tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
                    subfolder_features{subfolder_idx}.TBR.rest = [subfolder_features{subfolder_idx}.TBR.rest; tbr_val];
                end
                
                % Pope Index: β/(α+θ)，区分静息与注意的核心特征
                if ismember('Pope_Index', feature_names)
                    try
                        pope_val = calculatePopeIndex(segment, Fs);
                        subfolder_features{subfolder_idx}.Pope_Index.rest = [subfolder_features{subfolder_idx}.Pope_Index.rest; pope_val];
                    catch
                        subfolder_features{subfolder_idx}.Pope_Index.rest = [subfolder_features{subfolder_idx}.Pope_Index.rest; NaN];
                    end
                end
                
                % Inverse Alpha: 1/P_α，Alpha抑制指标
                if ismember('Inverse_Alpha', feature_names)
                    try
                        inv_alpha = calculateInverseAlpha(segment, Fs);
                        subfolder_features{subfolder_idx}.Inverse_Alpha.rest = [subfolder_features{subfolder_idx}.Inverse_Alpha.rest; inv_alpha];
                    catch
                        subfolder_features{subfolder_idx}.Inverse_Alpha.rest = [subfolder_features{subfolder_idx}.Inverse_Alpha.rest; NaN];
                    end
                end
                
                % Beta/Alpha Ratio: 注意力和警觉性指标
                if ismember('Beta_Alpha_Ratio', feature_names)
                    try
                        ba_ratio = calculateBetaAlphaRatio(segment, Fs);
                        subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.rest = [subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.rest; ba_ratio];
                    catch
                        subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.rest = [subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.rest; NaN];
                    end
                end
                
                % === 组合特征: 加权排列熵 + Alpha倒数 ===
                % 需要先计算或获取 PermEn_Weighted 和 Inverse_Alpha
                if ismember('WPE_IA_Product', feature_names) || ismember('WPE_IA_Weighted', feature_names) || ...
                   ismember('WPE_IA_Ratio', feature_names) || ismember('WPE_IA_Composite', feature_names)
                    try
                        % 获取加权排列熵值
                        perm_wt_val = getPermEn(segment, 'variant', 'weighted');
                        % 获取Alpha倒数值
                        inv_alpha_val = calculateInverseAlpha(segment, Fs);
                        
                        % 1. 乘积特征: WPE × IA (直接增强两者的共同效应)
                        if ismember('WPE_IA_Product', feature_names)
                            wpe_ia_prod = perm_wt_val * inv_alpha_val;
                            subfolder_features{subfolder_idx}.WPE_IA_Product.rest = [subfolder_features{subfolder_idx}.WPE_IA_Product.rest; wpe_ia_prod];
                        end
                        
                        % 2. 加权和特征: 0.5*WPE_norm + 0.5*IA_norm (标准化后的线性组合)
                        if ismember('WPE_IA_Weighted', feature_names)
                            % 使用z-score标准化（基于当前样本的简单缩放）
                            wpe_norm = perm_wt_val;
                            ia_norm = inv_alpha_val;
                            wpe_ia_weighted = 0.5 * wpe_norm + 0.5 * ia_norm;
                            subfolder_features{subfolder_idx}.WPE_IA_Weighted.rest = [subfolder_features{subfolder_idx}.WPE_IA_Weighted.rest; wpe_ia_weighted];
                        end
                        
                        % 3. 比值特征: WPE / (IA + epsilon) (相对强度指标)
                        if ismember('WPE_IA_Ratio', feature_names)
                            epsilon = 1e-6; % 避免除零
                            wpe_ia_ratio = perm_wt_val / (inv_alpha_val + epsilon);
                            subfolder_features{subfolder_idx}.WPE_IA_Ratio.rest = [subfolder_features{subfolder_idx}.WPE_IA_Ratio.rest; wpe_ia_ratio];
                        end
                        
                        % 4. 复合指数: WPE^0.6 × IA^0.4 (非线性加权组合)
                        if ismember('WPE_IA_Composite', feature_names)
                            % 使用幂律组合，可以调整指数来改变权重，原始是0.6和0.4
                            wpe_ia_composite = (perm_wt_val^perm_wt_val_w) * (inv_alpha_val^inv_alpha_val_w);
                            subfolder_features{subfolder_idx}.WPE_IA_Composite.rest = [subfolder_features{subfolder_idx}.WPE_IA_Composite.rest; wpe_ia_composite];
                        end
                    catch
                        if ismember('WPE_IA_Product', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Product.rest = [subfolder_features{subfolder_idx}.WPE_IA_Product.rest; NaN];
                        end
                        if ismember('WPE_IA_Weighted', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Weighted.rest = [subfolder_features{subfolder_idx}.WPE_IA_Weighted.rest; NaN];
                        end
                        if ismember('WPE_IA_Ratio', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Ratio.rest = [subfolder_features{subfolder_idx}.WPE_IA_Ratio.rest; NaN];
                        end
                        if ismember('WPE_IA_Composite', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Composite.rest = [subfolder_features{subfolder_idx}.WPE_IA_Composite.rest; NaN];
                        end
                    end
                end
                
                % Spectral Slope: 1/f斜率，反映E/I平衡
                if ismember('Spectral_Slope', feature_names)
                    try
                        slope_val = calculateSpectralSlope(segment, Fs);
                        subfolder_features{subfolder_idx}.Spectral_Slope.rest = [subfolder_features{subfolder_idx}.Spectral_Slope.rest; slope_val];
                    catch
                        subfolder_features{subfolder_idx}.Spectral_Slope.rest = [subfolder_features{subfolder_idx}.Spectral_Slope.rest; NaN];
                    end
                end
                
                % === Hjorth参数 ===
                % Complexity参数: Activity, Mobility, Complexity
                if ismember('Complexity_Activity', feature_names) || ismember('Complexity_Mobility', feature_names) || ismember('Complexity_Complexity', feature_names)
                    [activity, mobility, complexity] = calculateComplexity(segment, Fs);
                    if ismember('Complexity_Activity', feature_names)
                        subfolder_features{subfolder_idx}.Complexity_Activity.rest = [subfolder_features{subfolder_idx}.Complexity_Activity.rest; activity];
                    end
                    if ismember('Complexity_Mobility', feature_names)
                        subfolder_features{subfolder_idx}.Complexity_Mobility.rest = [subfolder_features{subfolder_idx}.Complexity_Mobility.rest; mobility];
                    end
                    if ismember('Complexity_Complexity', feature_names)
                        subfolder_features{subfolder_idx}.Complexity_Complexity.rest = [subfolder_features{subfolder_idx}.Complexity_Complexity.rest; complexity];
                    end
                end
            end
            
            % 计算注意力阶段特征
            n_attention = size(attention_samples, 1);
            for i = 1:n_attention
                segment = attention_samples(i, :);
                
                % === 熵特征 ===
                % SampEn: 样本熵
                if ismember('SampEn', feature_names)
                    Samp = SampEn(segment);
                    subfolder_features{subfolder_idx}.SampEn.attention = [subfolder_features{subfolder_idx}.SampEn.attention; Samp(3)];
                end
                
                % FuzzEn: 模糊熵
                if ismember('FuzzEn', feature_names)
                    Fuzz = FuzzEn(segment);
                    subfolder_features{subfolder_idx}.FuzzEn.attention = [subfolder_features{subfolder_idx}.FuzzEn.attention; Fuzz(1)];
                end
                
                % XSampEn: 交叉样本熵，分析前后两部分信号的交叉复杂度
                if ismember('XSampEn', feature_names)
                    try
                        mid_point = floor(length(segment) / 2);
                        if mid_point > 10
                            sig1 = segment(1:mid_point);
                            sig2 = segment(mid_point+1:end);
                            XSamp = XSampEn(sig1, sig2);
                            subfolder_features{subfolder_idx}.XSampEn.attention = [subfolder_features{subfolder_idx}.XSampEn.attention; XSamp(3)];
                        else
                            subfolder_features{subfolder_idx}.XSampEn.attention = [subfolder_features{subfolder_idx}.XSampEn.attention; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.XSampEn.attention = [subfolder_features{subfolder_idx}.XSampEn.attention; NaN];
                    end
                end
                
                % SampEn2D: 二维样本熵，用于分析信号的二维模式复杂度
                if ismember('SampEn2D', feature_names)
                    try
                        % 将一维信号转换为二维矩阵进行分析
                        % 使用延迟嵌入将信号重构为矩阵
                        % SampEn2D要求矩阵的行和列都>10，所以使用15以确保满足要求
                        embed_dim = 15;
                        min_cols = 12;  % 确保列数也>10
                        if length(segment) >= embed_dim * min_cols
                            mat_len = floor(length(segment) / embed_dim);
                            sig_mat = reshape(segment(1:mat_len*embed_dim), embed_dim, mat_len);
                            [SE2D, ~, ~] = SampEn2D(sig_mat);
                            subfolder_features{subfolder_idx}.SampEn2D.attention = [subfolder_features{subfolder_idx}.SampEn2D.attention; SE2D];
                        else
                            subfolder_features{subfolder_idx}.SampEn2D.attention = [subfolder_features{subfolder_idx}.SampEn2D.attention; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.SampEn2D.attention = [subfolder_features{subfolder_idx}.SampEn2D.attention; NaN];
                    end
                end
                
                % MvSampEn: 多变量样本熵，分析多通道信号的联合复杂度
                if ismember('MvSampEn', feature_names)
                    try
                        % 将单通道信号分段作为多变量数据
                        n_channels = 3;
                        seg_len = floor(length(segment) / n_channels);
                        if seg_len > 10
                            mv_data = zeros(seg_len, n_channels);
                            for ch = 1:n_channels
                                mv_data(:, ch) = segment((ch-1)*seg_len+1:ch*seg_len);
                            end
                            [MSamp, ~, ~, ~] = MvSampEn(mv_data);
                            subfolder_features{subfolder_idx}.MvSampEn.attention = [subfolder_features{subfolder_idx}.MvSampEn.attention; MSamp];
                        else
                            subfolder_features{subfolder_idx}.MvSampEn.attention = [subfolder_features{subfolder_idx}.MvSampEn.attention; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.MvSampEn.attention = [subfolder_features{subfolder_idx}.MvSampEn.attention; NaN];
                    end
                end
                
                % MvMSE: 多变量多尺度熵，综合多通道多尺度的复杂度分析
                if ismember('MvMSE', feature_names)
                    try
                        n_channels = 3;
                        seg_len = floor(length(segment) / n_channels);
                        if seg_len > 30
                            mv_data = zeros(seg_len, n_channels);
                            for ch = 1:n_channels
                                mv_data(:, ch) = segment((ch-1)*seg_len+1:ch*seg_len);
                            end
                            Mobj = struct('Func', @MvSampEn);
                            [~, CI] = MvMSEn(mv_data, Mobj, 'Scales', 3);
                            subfolder_features{subfolder_idx}.MvMSE.attention = [subfolder_features{subfolder_idx}.MvMSE.attention; CI];
                        else
                            subfolder_features{subfolder_idx}.MvMSE.attention = [subfolder_features{subfolder_idx}.MvMSE.attention; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.MvMSE.attention = [subfolder_features{subfolder_idx}.MvMSE.attention; NaN];
                    end
                end
                
                % MSEn: 多尺度熵
                if ismember('MSEn_CI', feature_names)
                    try
                        Mobj = struct('Func', @SampEn);
                        [~, CI] = MSEn(segment, Mobj, 'Scales', 5);
                        subfolder_features{subfolder_idx}.MSEn_CI.attention = [subfolder_features{subfolder_idx}.MSEn_CI.attention; CI];
                    catch
                        subfolder_features{subfolder_idx}.MSEn_CI.attention = [subfolder_features{subfolder_idx}.MSEn_CI.attention; NaN];
                    end
                end
                
                % cMSEn: 复合多尺度熵，改进的多尺度复杂度分析方法
                if ismember('cMSEn', feature_names)
                    try
                        Mobj = struct('Func', @SampEn);
                        [~, CI] = cMSEn(segment, Mobj, 'Scales', 5);
                        subfolder_features{subfolder_idx}.cMSEn.attention = [subfolder_features{subfolder_idx}.cMSEn.attention; CI];
                    catch
                        subfolder_features{subfolder_idx}.cMSEn.attention = [subfolder_features{subfolder_idx}.cMSEn.attention; NaN];
                    end
                end
                
                % cXMSE: 复合多尺度交叉熵，分析两段信号的交叉多尺度复杂度
                if ismember('cXMSE', feature_names)
                    try
                        mid_point = floor(length(segment) / 2);
                        if mid_point > 30
                            sig1 = segment(1:mid_point);
                            sig2 = segment(mid_point+1:end);
                            Mobj = struct('Func', @XSampEn);
                            [~, CI] = cXMSEn(sig1, sig2, Mobj, 'Scales', 3);
                            subfolder_features{subfolder_idx}.cXMSE.attention = [subfolder_features{subfolder_idx}.cXMSE.attention; CI];
                        else
                            subfolder_features{subfolder_idx}.cXMSE.attention = [subfolder_features{subfolder_idx}.cXMSE.attention; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.cXMSE.attention = [subfolder_features{subfolder_idx}.cXMSE.attention; NaN];
                    end
                end
                
                % cMvMSE: 复合多变量多尺度熵，改进的多通道多尺度复杂度分析
                if ismember('cMvMSE', feature_names)
                    try
                        n_channels = 3;
                        seg_len = floor(length(segment) / n_channels);
                        if seg_len > 30
                            mv_data = zeros(seg_len, n_channels);
                            for ch = 1:n_channels
                                mv_data(:, ch) = segment((ch-1)*seg_len+1:ch*seg_len);
                            end
                            Mobj = struct('Func', @MvSampEn);
                            [~, CI] = cMvMSEn(mv_data, Mobj, 'Scales', 3);
                            subfolder_features{subfolder_idx}.cMvMSE.attention = [subfolder_features{subfolder_idx}.cMvMSE.attention; CI];
                        else
                            subfolder_features{subfolder_idx}.cMvMSE.attention = [subfolder_features{subfolder_idx}.cMvMSE.attention; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.cMvMSE.attention = [subfolder_features{subfolder_idx}.cMvMSE.attention; NaN];
                    end
                end
                
                % === 排列熵系列 ===
                % PermEn: 标准排列熵
                if ismember('PermEn', feature_names)
                    try
                        [perm_val, ~, ~] = PermEn(segment, 'm', 4);
                        subfolder_features{subfolder_idx}.PermEn.attention = [subfolder_features{subfolder_idx}.PermEn.attention; perm_val(end)];
                    catch
                        subfolder_features{subfolder_idx}.PermEn.attention = [subfolder_features{subfolder_idx}.PermEn.attention; NaN];
                    end
                end
                
                % PermEn_FineGrain: 细粒度排列熵
                if ismember('PermEn_FineGrain', feature_names)
                    try
                        perm_fg = getPermEn(segment, 'variant', 'finegrain');
                        subfolder_features{subfolder_idx}.PermEn_FineGrain.attention = [subfolder_features{subfolder_idx}.PermEn_FineGrain.attention; perm_fg];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_FineGrain.attention = [subfolder_features{subfolder_idx}.PermEn_FineGrain.attention; NaN];
                    end
                end
                
                % PermEn_Modified: 修正排列熵
                if ismember('PermEn_Modified', feature_names)
                    try
                        perm_mod = getPermEn(segment, 'variant', 'modified');
                        subfolder_features{subfolder_idx}.PermEn_Modified.attention = [subfolder_features{subfolder_idx}.PermEn_Modified.attention; perm_mod];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Modified.attention = [subfolder_features{subfolder_idx}.PermEn_Modified.attention; NaN];
                    end
                end
                
                % PermEn_AmpAware: 幅度感知排列熵
                if ismember('PermEn_AmpAware', feature_names)
                    try
                        perm_amp = getPermEn(segment, 'variant', 'ampaware');
                        subfolder_features{subfolder_idx}.PermEn_AmpAware.attention = [subfolder_features{subfolder_idx}.PermEn_AmpAware.attention; perm_amp];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_AmpAware.attention = [subfolder_features{subfolder_idx}.PermEn_AmpAware.attention; NaN];
                    end
                end
                
                % PermEn_Weighted: 加权排列熵
                if ismember('PermEn_Weighted', feature_names)
                    try
                        perm_wt = getPermEn(segment, 'variant', 'weighted');
                        subfolder_features{subfolder_idx}.PermEn_Weighted.attention = [subfolder_features{subfolder_idx}.PermEn_Weighted.attention; perm_wt];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Weighted.attention = [subfolder_features{subfolder_idx}.PermEn_Weighted.attention; NaN];
                    end
                end
                
                % PermEn_Edge: 边缘排列熵
                if ismember('PermEn_Edge', feature_names)
                    try
                        perm_edge = getPermEn(segment, 'variant', 'edge');
                        subfolder_features{subfolder_idx}.PermEn_Edge.attention = [subfolder_features{subfolder_idx}.PermEn_Edge.attention; perm_edge];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Edge.attention = [subfolder_features{subfolder_idx}.PermEn_Edge.attention; NaN];
                    end
                end
                
                % PermEn_Uniquant: 改进排列熵
                if ismember('PermEn_Uniquant', feature_names)
                    try
                        perm_uniq = getPermEn(segment, 'variant', 'uniquant', 'alpha', 4);
                        subfolder_features{subfolder_idx}.PermEn_Uniquant.attention = [subfolder_features{subfolder_idx}.PermEn_Uniquant.attention; perm_uniq];
                    catch
                        subfolder_features{subfolder_idx}.PermEn_Uniquant.attention = [subfolder_features{subfolder_idx}.PermEn_Uniquant.attention; NaN];
                    end
                end
                
                % XPermEn: 交叉排列熵
                if ismember('XPermEn', feature_names)
                    try
                        mid_point = floor(length(segment) / 2);
                        if mid_point > 10
                            sig1 = segment(1:mid_point);
                            sig2 = segment(mid_point+1:end);
                            xperm_val = XPermEn(sig1, sig2);
                            subfolder_features{subfolder_idx}.XPermEn.attention = [subfolder_features{subfolder_idx}.XPermEn.attention; xperm_val];
                        else
                            subfolder_features{subfolder_idx}.XPermEn.attention = [subfolder_features{subfolder_idx}.XPermEn.attention; NaN];
                        end
                    catch
                        subfolder_features{subfolder_idx}.XPermEn.attention = [subfolder_features{subfolder_idx}.XPermEn.attention; NaN];
                    end
                end
                
                % LZC: Lempel-Ziv复杂度
                if ismember('LZC', feature_names)
                    try
                        lzc_val = calculateLZC(segment);
                        subfolder_features{subfolder_idx}.LZC.attention = [subfolder_features{subfolder_idx}.LZC.attention; lzc_val];
                    catch
                        subfolder_features{subfolder_idx}.LZC.attention = [subfolder_features{subfolder_idx}.LZC.attention; NaN];
                    end
                end
                
                % === 分形特征 ===
                % HFD: Higuchi分形维数
                if ismember('HFD', feature_names)
                    try
                        hfd_val = HigFracDim(segment, 10);
                        subfolder_features{subfolder_idx}.HFD.attention = [subfolder_features{subfolder_idx}.HFD.attention; hfd_val];
                    catch
                        subfolder_features{subfolder_idx}.HFD.attention = [subfolder_features{subfolder_idx}.HFD.attention; NaN];
                    end
                end
                
                % FDD: 分形维数分布
                if ismember('FDD_Mean', feature_names) || ismember('FDD_Std', feature_names)
                    try
                        [fdd_m, fdd_s] = calculateFDD(segment);
                        if ismember('FDD_Mean', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Mean.attention = [subfolder_features{subfolder_idx}.FDD_Mean.attention; fdd_m];
                        end
                        if ismember('FDD_Std', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Std.attention = [subfolder_features{subfolder_idx}.FDD_Std.attention; fdd_s];
                        end
                    catch
                        if ismember('FDD_Mean', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Mean.attention = [subfolder_features{subfolder_idx}.FDD_Mean.attention; NaN];
                        end
                        if ismember('FDD_Std', feature_names)
                            subfolder_features{subfolder_idx}.FDD_Std.attention = [subfolder_features{subfolder_idx}.FDD_Std.attention; NaN];
                        end
                    end
                end
                
                % === 频谱特征 ===
                % TBR: Theta/Beta比率
                if ismember('TBR', feature_names)
                    tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
                    subfolder_features{subfolder_idx}.TBR.attention = [subfolder_features{subfolder_idx}.TBR.attention; tbr_val];
                end
                
                % Pope Index: β/(α+θ)
                if ismember('Pope_Index', feature_names)
                    try
                        pope_val = calculatePopeIndex(segment, Fs);
                        subfolder_features{subfolder_idx}.Pope_Index.attention = [subfolder_features{subfolder_idx}.Pope_Index.attention; pope_val];
                    catch
                        subfolder_features{subfolder_idx}.Pope_Index.attention = [subfolder_features{subfolder_idx}.Pope_Index.attention; NaN];
                    end
                end
                
                % Inverse Alpha: 1/P_α
                if ismember('Inverse_Alpha', feature_names)
                    try
                        inv_alpha = calculateInverseAlpha(segment, Fs);
                        subfolder_features{subfolder_idx}.Inverse_Alpha.attention = [subfolder_features{subfolder_idx}.Inverse_Alpha.attention; inv_alpha];
                    catch
                        subfolder_features{subfolder_idx}.Inverse_Alpha.attention = [subfolder_features{subfolder_idx}.Inverse_Alpha.attention; NaN];
                    end
                end
                
                % Beta/Alpha Ratio
                if ismember('Beta_Alpha_Ratio', feature_names)
                    try
                        ba_ratio = calculateBetaAlphaRatio(segment, Fs);
                        subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.attention = [subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.attention; ba_ratio];
                    catch
                        subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.attention = [subfolder_features{subfolder_idx}.Beta_Alpha_Ratio.attention; NaN];
                    end
                end
                
                % === 组合特征: 加权排列熵 + Alpha倒数 ===
                % 需要先计算或获取 PermEn_Weighted 和 Inverse_Alpha
                if ismember('WPE_IA_Product', feature_names) || ismember('WPE_IA_Weighted', feature_names) || ...
                   ismember('WPE_IA_Ratio', feature_names) || ismember('WPE_IA_Composite', feature_names)
                    try
                        % 获取加权排列熵值
                        perm_wt_val = getPermEn(segment, 'variant', 'weighted');
                        % 获取Alpha倒数值
                        inv_alpha_val = calculateInverseAlpha(segment, Fs);
                        
                        % 1. 乘积特征: WPE × IA (直接增强两者的共同效应)
                        if ismember('WPE_IA_Product', feature_names)
                            wpe_ia_prod = perm_wt_val * inv_alpha_val;
                            subfolder_features{subfolder_idx}.WPE_IA_Product.attention = [subfolder_features{subfolder_idx}.WPE_IA_Product.attention; wpe_ia_prod];
                        end
                        
                        % 2. 加权和特征: 0.5*WPE_norm + 0.5*IA_norm (标准化后的线性组合)
                        if ismember('WPE_IA_Weighted', feature_names)
                            % 使用z-score标准化（基于当前样本的简单缩放）
                            wpe_norm = perm_wt_val;
                            ia_norm = inv_alpha_val;
                            wpe_ia_weighted = 0.5 * wpe_norm + 0.5 * ia_norm;
                            subfolder_features{subfolder_idx}.WPE_IA_Weighted.attention = [subfolder_features{subfolder_idx}.WPE_IA_Weighted.attention; wpe_ia_weighted];
                        end
                        
                        % 3. 比值特征: WPE / (IA + epsilon) (相对强度指标)
                        if ismember('WPE_IA_Ratio', feature_names)
                            epsilon = 1e-6; % 避免除零
                            wpe_ia_ratio = perm_wt_val / (inv_alpha_val + epsilon);
                            subfolder_features{subfolder_idx}.WPE_IA_Ratio.attention = [subfolder_features{subfolder_idx}.WPE_IA_Ratio.attention; wpe_ia_ratio];
                        end
                        
                        % 4. 复合指数: WPE^0.6 × IA^0.4 (非线性加权组合)
                        if ismember('WPE_IA_Composite', feature_names)
                            % 使用幂律组合，可以调整指数来改变权重
                            wpe_ia_composite = (perm_wt_val^perm_wt_val_w) * (inv_alpha_val^inv_alpha_val_w);
                            subfolder_features{subfolder_idx}.WPE_IA_Composite.attention = [subfolder_features{subfolder_idx}.WPE_IA_Composite.attention; wpe_ia_composite];
                        end
                    catch
                        if ismember('WPE_IA_Product', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Product.attention = [subfolder_features{subfolder_idx}.WPE_IA_Product.attention; NaN];
                        end
                        if ismember('WPE_IA_Weighted', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Weighted.attention = [subfolder_features{subfolder_idx}.WPE_IA_Weighted.attention; NaN];
                        end
                        if ismember('WPE_IA_Ratio', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Ratio.attention = [subfolder_features{subfolder_idx}.WPE_IA_Ratio.attention; NaN];
                        end
                        if ismember('WPE_IA_Composite', feature_names)
                            subfolder_features{subfolder_idx}.WPE_IA_Composite.attention = [subfolder_features{subfolder_idx}.WPE_IA_Composite.attention; NaN];
                        end
                    end
                end
                
                % Spectral Slope: 1/f斜率
                if ismember('Spectral_Slope', feature_names)
                    try
                        slope_val = calculateSpectralSlope(segment, Fs);
                        subfolder_features{subfolder_idx}.Spectral_Slope.attention = [subfolder_features{subfolder_idx}.Spectral_Slope.attention; slope_val];
                    catch
                        subfolder_features{subfolder_idx}.Spectral_Slope.attention = [subfolder_features{subfolder_idx}.Spectral_Slope.attention; NaN];
                    end
                end
                
                % === Hjorth参数 ===
                % Complexity参数
                if ismember('Complexity_Activity', feature_names) || ismember('Complexity_Mobility', feature_names) || ismember('Complexity_Complexity', feature_names)
                    [activity, mobility, complexity] = calculateComplexity(segment, Fs);
                    if ismember('Complexity_Activity', feature_names)
                        subfolder_features{subfolder_idx}.Complexity_Activity.attention = [subfolder_features{subfolder_idx}.Complexity_Activity.attention; activity];
                    end
                    if ismember('Complexity_Mobility', feature_names)
                        subfolder_features{subfolder_idx}.Complexity_Mobility.attention = [subfolder_features{subfolder_idx}.Complexity_Mobility.attention; mobility];
                    end
                    if ismember('Complexity_Complexity', feature_names)
                        subfolder_features{subfolder_idx}.Complexity_Complexity.attention = [subfolder_features{subfolder_idx}.Complexity_Complexity.attention; complexity];
                    end
                end
            end
            
            % === 保存该受试者的所有样本特征值（用于生成箱型图） ===
            % 保存该受试者所有样本的特征值（静息+注意力混合）
            n_rest_current = size(rest_samples, 1);
            n_attention_current = size(attention_samples, 1);
            
            for feat_idx = 1:n_features
                feat_name = feature_names{feat_idx};
                
                % 获取刚添加的数据（数组末尾）
                rest_feat_vals = subfolder_features{subfolder_idx}.(feat_name).rest(end-n_rest_current+1:end);
                attention_feat_vals = subfolder_features{subfolder_idx}.(feat_name).attention(end-n_attention_current+1:end);
                
                % 合并该受试者的所有样本值
                all_vals = [rest_feat_vals; attention_feat_vals];
                all_vals = all_vals(~isnan(all_vals) & ~isinf(all_vals));  % 移除NaN和Inf
                
                if ~isempty(all_vals)
                    % 保存所有样本值到细胞数组
                    subject_features.(feat_name).data{end+1} = all_vals;
                    subject_features.(feat_name).subject_names{end+1} = filename;
                    subject_features.(feat_name).subfolder_names{end+1} = subfolder_name;
                end
            end
            
            count_processed = count_processed + 1;
            
        catch ME
            fprintf('  错误: %s\n', ME.message);
            count_failed = count_failed + 1;
        end
    end
    
    fprintf('子目录 %s: 成功处理 %d 个文件, 失败 %d 个\n', subfolder_name, count_processed, count_failed);
end

%% 计算每个子目录的评估指标
fprintf('\n\n========== 各子目录的特征区分能力评估 ==========\n');

% 初始化结果存储：subfolder_results{子目录索引} = 结果表
subfolder_results = cell(n_subfolders, 1);
subfolder_best_features = cell(n_subfolders, 1);
subfolder_scores = zeros(n_subfolders, 1);

for subfolder_idx = 1:n_subfolders
    subfolder_name = subfolder_names{subfolder_idx};
    fprintf('\n========== 子目录: %s ==========\n', subfolder_name);
    
    % 初始化结果表
    results_table = cell(n_features + 1, 9);
    results_table(1, :) = {'特征名称', 'Cohen''s d', '分离度', 'p值', ...
                           '静息均值±std', '注意力均值±std', '重叠系数', '推荐度', '样本数'};
    
    for feat_idx = 1:n_features
        feat_name = feature_names{feat_idx};
        rest_data = subfolder_features{subfolder_idx}.(feat_name).rest;
        attention_data = subfolder_features{subfolder_idx}.(feat_name).attention;
        
        % 移除NaN和Inf
        rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
        attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
        
        if isempty(rest_data) || isempty(attention_data)
            fprintf('  %s: 数据不足,跳过\n', feat_name);
            continue;
        end
        
        % 1. Cohen's d (效应量)
        mean_rest = mean(rest_data);
        mean_attention = mean(attention_data);
        std_rest = std(rest_data);
        std_attention = std(attention_data);
        pooled_std = sqrt((std_rest^2 + std_attention^2) / 2);
        cohens_d = abs(mean_rest - mean_attention) / pooled_std;
        
        % 2. 分离度 (Separation Index)
        separation_index = abs(mean_rest - mean_attention) / (std_rest + std_attention);
        
        % 3. 统计显著性 (t-test)
        [~, p_value] = ttest2(rest_data, attention_data);
        
        % 4. 重叠系数
        overlap_coef = calculate_overlap(rest_data, attention_data);
        
        % 5. 综合推荐度评分 (0-100分)
        score_d = min(cohens_d / 2 * 100, 100);
        score_sep = min(separation_index * 50, 100);
        score_p = (p_value < 0.001) * 40 + (p_value < 0.01) * 30 + (p_value < 0.05) * 20;
        score_overlap = (1 - overlap_coef) * 100;
        recommend_score = (score_d * 0.3 + score_sep * 0.3 + score_p * 0.2 + score_overlap * 0.2);
        
        % 填充结果表
        results_table{feat_idx+1, 1} = feat_name;
        results_table{feat_idx+1, 2} = cohens_d;
        results_table{feat_idx+1, 3} = separation_index;
        results_table{feat_idx+1, 4} = p_value;
        results_table{feat_idx+1, 5} = sprintf('%.4f±%.4f', mean_rest, std_rest);
        results_table{feat_idx+1, 6} = sprintf('%.4f±%.4f', mean_attention, std_attention);
        results_table{feat_idx+1, 7} = overlap_coef;
        results_table{feat_idx+1, 8} = recommend_score;
        results_table{feat_idx+1, 9} = sprintf('%d/%d', length(rest_data), length(attention_data));
        
        % 打印详细结果
        fprintf('  %s: Cohen''s d=%.3f, 分离度=%.3f, p=%.6f, 推荐度=%.1f\n', ...
                feat_name, cohens_d, separation_index, p_value, recommend_score);
    end
    
    % 保存当前子目录的结果
    subfolder_results{subfolder_idx} = results_table;
    
    % 找到当前子目录的最佳特征
    % 安全地提取推荐度分数（跳过空单元格）
    scores = [];
    score_indices = [];
    for row = 2:size(results_table, 1)
        if ~isempty(results_table{row, 8}) && isnumeric(results_table{row, 8})
            scores(end+1) = results_table{row, 8};
            score_indices(end+1) = row;
        end
    end
    
    if ~isempty(scores)
        [max_score, max_idx] = max(scores);
        best_row = score_indices(max_idx);
        subfolder_best_features{subfolder_idx} = results_table{best_row, 1};
        subfolder_scores(subfolder_idx) = max_score;
        fprintf('  >> 最佳特征: %s (推荐度: %.1f)\n', subfolder_best_features{subfolder_idx}, max_score);
    end
end

%% 子目录综合比较
fprintf('\n\n========== 子目录综合比较 ==========\n');
fprintf('%-20s %-20s %15s %15s\n', '子目录名称', '最佳特征', '最高推荐度', '平均推荐度');
fprintf('%s\n', repmat('-', 1, 80));

% 计算每个子目录的平均推荐度
subfolder_avg_scores = zeros(n_subfolders, 1);
for s = 1:n_subfolders
    results_table = subfolder_results{s};
    if size(results_table, 1) > 1
        % 安全地提取所有推荐度分数
        all_scores = [];
        for row = 2:size(results_table, 1)
            if ~isempty(results_table{row, 8}) && isnumeric(results_table{row, 8})
                all_scores(end+1) = results_table{row, 8};
            end
        end
        if ~isempty(all_scores)
            subfolder_avg_scores(s) = mean(all_scores);
        end
    end
    
    fprintf('%-20s %-20s %15.2f %15.2f\n', ...
            subfolder_names{s}, subfolder_best_features{s}, subfolder_scores(s), subfolder_avg_scores(s));
end

% 找到最佳子目录（基于最高推荐度）
[best_max_score, best_subfolder_idx] = max(subfolder_scores);
best_subfolder_name = subfolder_names{best_subfolder_idx};

fprintf('\n推荐子目录: %s (最佳特征推荐度: %.2f, 平均推荐度: %.2f)\n', ...
        best_subfolder_name, best_max_score, subfolder_avg_scores(best_subfolder_idx));
fprintf('%s\n', repmat('=', 1, 80));
%% 创建保存目录
figure_folder = fullfile(fileparts(mfilename('fullpath')), 'figure');
if ~exist(figure_folder, 'dir')
    mkdir(figure_folder);
    fprintf('创建figure文件夹: %s\n', figure_folder);
end

%% 可视化对比
fprintf('\n生成可视化图表...\n');

% === 图1: 子目录比较条形图 ===
fig1 = figure('Position', [100, 100, 1200, 500], 'Visible', 'off');

% 子图1: 各子目录的最高推荐度
subplot(1, 2, 1);
bar(subfolder_scores);
set(gca, 'XTickLabel', subfolder_names, 'XTickLabelRotation', 45);
xlabel('子目录名称', 'FontSize', 12);
ylabel('最高推荐度', 'FontSize', 12);
title('各子目录最佳特征的推荐度', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
% 添加数值标注
for i = 1:n_subfolders
    text(i, subfolder_scores(i), sprintf('%.1f', subfolder_scores(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
end

% 子图2: 各子目录的平均推荐度
subplot(1, 2, 2);
bar(subfolder_avg_scores); 
set(gca, 'XTickLabel', subfolder_names, 'XTickLabelRotation', 45);
xlabel('子目录名称', 'FontSize', 12);
ylabel('平均推荐度', 'FontSize', 12);
title('各子目录所有特征的平均推荐度', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
% 添加数值标注
for i = 1:n_subfolders
    text(i, subfolder_avg_scores(i), sprintf('%.1f', subfolder_avg_scores(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
end

sgtitle('不同子目录的综合比较', 'FontSize', 15, 'FontWeight', 'bold');

% 保存图1
fig1_path = fullfile(figure_folder, '1_子目录综合比较.png');
saveas(fig1, fig1_path);
fprintf('已保存: %s\n', fig1_path);
close(fig1);

% === 图2: 每个特征在不同子目录下的表现 ===
fig2 = figure('Position', [150, 150, 1800, 1400], 'Visible', 'off');
for feat_idx = 1:n_features
    subplot(4, 6, feat_idx);
    feat_name = feature_names{feat_idx};
    
    % 收集该特征在各子目录的推荐度
    feat_scores = zeros(n_subfolders, 1);
    for s = 1:n_subfolders
        results_table = subfolder_results{s};
        % 查找特征行
        for row = 2:size(results_table, 1)
            if ~isempty(results_table{row, 1}) && strcmp(results_table{row, 1}, feat_name)
                if ~isempty(results_table{row, 8}) && isnumeric(results_table{row, 8})
                    feat_scores(s) = results_table{row, 8};
                end
                break;
            end
        end
    end
    
    bar(feat_scores);
    set(gca, 'XTickLabel', subfolder_names, 'XTickLabelRotation', 45);
    xlabel('子目录名称', 'FontSize', 10);
    ylabel('推荐度', 'FontSize', 10);
    title(feat_name, 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % 设置y轴范围（添加保护性检查）
    max_score = max(feat_scores);
    if isfinite(max_score) && max_score > 0
        ylim([0, max_score*1.2]);
    else
        ylim([0, 1]);  % 默认范围
    end
    
    % 添加数值标注
    for i = 1:n_subfolders
        if feat_scores(i) > 0
            text(i, feat_scores(i), sprintf('%.1f', feat_scores(i)), ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
        end
    end
end
sgtitle('各特征在不同子目录下的表现', 'FontSize', 15, 'FontWeight', 'bold');

% 保存图2
fig2_path = fullfile(figure_folder, '2_各特征在不同子目录的表现.png');
saveas(fig2, fig2_path);
fprintf('已保存: %s\n', fig2_path);
close(fig2);

% === 图3: 最佳子目录的详细箱线图 ===
best_features = subfolder_features{best_subfolder_idx};
fig3 = figure('Position', [200, 200, 1800, 1400], 'Visible', 'off');
for feat_idx = 1:n_features
    subplot(4, 6, feat_idx);
    feat_name = feature_names{feat_idx};
    
    rest_data = best_features.(feat_name).rest;
    attention_data = best_features.(feat_name).attention;
    
    rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
    attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
    
    if ~isempty(rest_data) && ~isempty(attention_data)
        data_combined = [rest_data; attention_data];
        group = [ones(length(rest_data), 1); 2*ones(length(attention_data), 1)];
        
        boxplot(data_combined, group, 'Labels', {'静息', '注意力'}, 'Colors', 'br');
        title(feat_name, 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('特征值', 'FontSize', 10);
        grid on;
        
        % 添加均值标记
        hold on;
        plot(1, mean(rest_data), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
        plot(2, mean(attention_data), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
        hold off;
    end
end
sgtitle(sprintf('最佳子目录 (%s) 的特征分布', best_subfolder_name), 'FontSize', 15, 'FontWeight', 'bold');

% 为最佳子目录创建子文件夹
best_subfolder_figure_path = fullfile(figure_folder, best_subfolder_name);
if ~exist(best_subfolder_figure_path, 'dir')
    mkdir(best_subfolder_figure_path);
end

% 保存图3到最佳子目录文件夹
fig3_path = fullfile(best_subfolder_figure_path, '3_特征箱线图分布.png');
saveas(fig3, fig3_path);
fprintf('已保存: %s\n', fig3_path);
close(fig3);

% === 图4: 最佳子目录的Top 3特征密度图 ===
best_results_table = subfolder_results{best_subfolder_idx};
if size(best_results_table, 1) > 1
    % 安全地提取推荐度分数
    scores = [];
    score_indices = [];
    for row = 2:size(best_results_table, 1)
        if ~isempty(best_results_table{row, 8}) && isnumeric(best_results_table{row, 8})
            scores(end+1) = best_results_table{row, 8};
            score_indices(end+1) = row;
        end
    end
    
    if ~isempty(scores)
        [~, sort_idx] = sort(scores, 'descend');
        top_3_indices = sort_idx(1:min(3, length(sort_idx)));
        
        fig4 = figure('Position', [250, 250, 1200, 400], 'Visible', 'off');
        for i = 1:length(top_3_indices)
            idx_in_scores = top_3_indices(i);
            feat_row = score_indices(idx_in_scores);
            feat_name = best_results_table{feat_row, 1};
            feat_score = best_results_table{feat_row, 8};
            
            subplot(1, 3, i);
            
            rest_data = best_features.(feat_name).rest;
        attention_data = best_features.(feat_name).attention;
        
        rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
        attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
        
        if ~isempty(rest_data) && ~isempty(attention_data)
            hold on;
            [f_rest, x_rest] = ksdensity(rest_data);
            [f_att, x_att] = ksdensity(attention_data);
            
            plot(x_rest, f_rest, 'b-', 'LineWidth', 2.5, 'DisplayName', '静息');
            plot(x_att, f_att, 'r-', 'LineWidth', 2.5, 'DisplayName', '注意力');
            
            xlabel('特征值', 'FontSize', 11);
            ylabel('概率密度', 'FontSize', 11);
            title(sprintf('%s (推荐度: %.1f)', feat_name, feat_score), ...
                  'FontSize', 12, 'FontWeight', 'bold');
            legend('Location', 'best', 'FontSize', 10);
            grid on;
            hold off;
        end
    end
        sgtitle(sprintf('最佳子目录 (%s) Top 3 特征的概率密度分布', best_subfolder_name), ...
                'FontSize', 15, 'FontWeight', 'bold');
        
        % 保存图4到最佳子目录文件夹
        fig4_path = fullfile(best_subfolder_figure_path, '4_Top3特征概率密度分布.png');
        saveas(fig4, fig4_path);
        fprintf('已保存: %s\n', fig4_path);
        close(fig4);
    end
end

%% 为每个子目录生成单独的详细图表
fprintf('\n为每个子目录生成详细图表...\n');
for subfolder_idx = 1:n_subfolders
    subfolder_name = subfolder_names{subfolder_idx};
    fprintf('生成子目录 %s 的图表...\n', subfolder_name);
    
    % 创建子目录的figure文件夹
    subfolder_figure_path = fullfile(figure_folder, subfolder_name);
    if ~exist(subfolder_figure_path, 'dir')
        mkdir(subfolder_figure_path);
    end
    
    % 获取该子目录的特征数据
    current_features = subfolder_features{subfolder_idx};
    
    % 图A: 该子目录的箱线图
    figA = figure('Position', [100, 100, 1800, 1400], 'Visible', 'off');
    for feat_idx = 1:n_features
        subplot(4, 6, feat_idx);
        feat_name = feature_names{feat_idx};
        
        rest_data = current_features.(feat_name).rest;
        attention_data = current_features.(feat_name).attention;
        
        rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
        attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
        
        if ~isempty(rest_data) && ~isempty(attention_data)
            data_combined = [rest_data; attention_data];
            group = [ones(length(rest_data), 1); 2*ones(length(attention_data), 1)];
            
            boxplot(data_combined, group, 'Labels', {'静息', '注意力'}, 'Colors', 'br');
            title(feat_name, 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('特征值', 'FontSize', 10);
            grid on;
            
            % 添加均值标记
            hold on;
            plot(1, mean(rest_data), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            plot(2, mean(attention_data), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            hold off;
        end
    end
    sgtitle(sprintf('子目录 %s - 特征箱线图分布', subfolder_name), 'FontSize', 15, 'FontWeight', 'bold');
    figA_path = fullfile(subfolder_figure_path, sprintf('%s_特征箱线图.png', subfolder_name));
    saveas(figA, figA_path);
    close(figA);
    
    % 图B: 该子目录的推荐度条形图
    results_table = subfolder_results{subfolder_idx};
    if size(results_table, 1) > 1
        figB = figure('Position', [100, 100, 800, 600], 'Visible', 'off');
        
        % 提取特征名称和推荐度
        feat_labels = {};
        feat_scores_plot = [];
        for row = 2:size(results_table, 1)
            if ~isempty(results_table{row, 1}) && ~isempty(results_table{row, 8}) && isnumeric(results_table{row, 8})
                feat_labels{end+1} = results_table{row, 1};
                feat_scores_plot(end+1) = results_table{row, 8};
            end
        end
        
        if ~isempty(feat_scores_plot)
            bar(feat_scores_plot);
            set(gca, 'XTickLabel', feat_labels, 'XTickLabelRotation', 45);
            xlabel('特征名称', 'FontSize', 12);
            ylabel('推荐度', 'FontSize', 12);
            title(sprintf('子目录 %s - 特征推荐度对比', subfolder_name), 'FontSize', 13, 'FontWeight', 'bold');
            grid on;
            
            % 添加数值标注
            for i = 1:length(feat_scores_plot)
                text(i, feat_scores_plot(i), sprintf('%.1f', feat_scores_plot(i)), ...
                     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
            end
        end
        
        figB_path = fullfile(subfolder_figure_path, sprintf('%s_推荐度对比.png', subfolder_name));
        saveas(figB, figB_path);
        close(figB);
    end
    
    fprintf('  已保存子目录 %s 的图表\n', subfolder_name);
end

fprintf('\n所有图表已保存到: %s\n', figure_folder);

%% 生成每个特征在不同受试者下的对比箱型图
fprintf('\n生成受试者对比箱型图...\n');

% 创建受试者对比文件夹
subject_comparison_folder = fullfile(figure_folder, '受试者对比');
if ~exist(subject_comparison_folder, 'dir')
    mkdir(subject_comparison_folder);
end

% === 新增：为每个特征生成受试者（子目录）均值和方差的柱状图 ===
fprintf('\n生成各特征的受试者均值方差柱状图...\n');

for feat_idx = 1:n_features
    feat_name = feature_names{feat_idx};
    
    fprintf('  生成特征 %s 的受试者均值方差柱状图...\n', feat_name);
    
    % 计算每个子目录（受试者）的均值和标准差
    subfolder_means_rest = zeros(1, n_subfolders);
    subfolder_stds_rest = zeros(1, n_subfolders);
    subfolder_means_attention = zeros(1, n_subfolders);
    subfolder_stds_attention = zeros(1, n_subfolders);
    subfolder_means_combined = zeros(1, n_subfolders);
    subfolder_stds_combined = zeros(1, n_subfolders);
    
    for s = 1:n_subfolders
        % 静息态数据
        rest_data = subfolder_features{s}.(feat_name).rest;
        rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
        if ~isempty(rest_data)
            subfolder_means_rest(s) = mean(rest_data);
            subfolder_stds_rest(s) = std(rest_data);
        else
            subfolder_means_rest(s) = NaN;
            subfolder_stds_rest(s) = NaN;
        end
        
        % 注意力态数据
        attention_data = subfolder_features{s}.(feat_name).attention;
        attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
        if ~isempty(attention_data)
            subfolder_means_attention(s) = mean(attention_data);
            subfolder_stds_attention(s) = std(attention_data);
        else
            subfolder_means_attention(s) = NaN;
            subfolder_stds_attention(s) = NaN;
        end
        
        % 合并数据（静息+注意力）
        combined_data = [rest_data; attention_data];
        if ~isempty(combined_data)
            subfolder_means_combined(s) = mean(combined_data);
            subfolder_stds_combined(s) = std(combined_data);
        else
            subfolder_means_combined(s) = NaN;
            subfolder_stds_combined(s) = NaN;
        end
    end
    
    % === 图1：静息态 vs 注意力态分组柱状图 ===
    fig_grouped = figure('Position', [100, 100, max(1200, n_subfolders*120), 700], 'Visible', 'off');
    
    % 准备分组柱状图数据
    bar_data = [subfolder_means_rest; subfolder_means_attention]';
    
    % 绘制分组柱状图
    hold on;
    b = bar(1:n_subfolders, bar_data, 'grouped');
    b(1).FaceColor = [0.2 0.6 0.8];  % 蓝色 - 静息态
    b(2).FaceColor = [0.8 0.4 0.2];  % 橙色 - 注意力态
    
    % 添加误差棒
    x1 = b(1).XEndPoints;
    x2 = b(2).XEndPoints;
    errorbar(x1, subfolder_means_rest, subfolder_stds_rest, 'k.', 'LineWidth', 1.5, 'CapSize', 8);
    errorbar(x2, subfolder_means_attention, subfolder_stds_attention, 'k.', 'LineWidth', 1.5, 'CapSize', 8);
    
    % 设置图表属性
    grid on;
    xlabel('受试者（子目录）', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(sprintf('%s 特征值（均值 ± 标准差）', feat_name), 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('特征 %s - 各受试者静息态vs注意力态对比', feat_name), ...
          'FontSize', 14, 'FontWeight', 'bold');
    
    % 设置x轴标签
    set(gca, 'XTick', 1:n_subfolders, 'XTickLabel', subfolder_names, 'XTickLabelRotation', 45);
    xlim([0.5, n_subfolders+0.5]);
    
    % 智能调整y轴范围，让差异更明显
    % 计算所有数据的范围（包括误差棒）
    all_data_with_error = [subfolder_means_rest - subfolder_stds_rest, ...
                           subfolder_means_rest + subfolder_stds_rest, ...
                           subfolder_means_attention - subfolder_stds_attention, ...
                           subfolder_means_attention + subfolder_stds_attention];
    valid_data = all_data_with_error(~isnan(all_data_with_error) & ~isinf(all_data_with_error));
    
    if ~isempty(valid_data)
        data_min = min(valid_data);
        data_max = max(valid_data);
        data_range = data_max - data_min;
        
        % 如果数据范围很小（相对于均值），使用紧凑的y轴范围
        data_mean = mean(valid_data);
        if data_range / abs(data_mean) < 0.1 && data_range > 0
            % 数据变化小于均值的10%，使用紧凑视图
            y_margin = data_range * 0.15;  % 上下各留15%余量
            ylim([data_min - y_margin, data_max + y_margin]);
        elseif data_min > 0 && data_min / data_max > 0.5
            % 所有数据都是正数且最小值不接近0，不从0开始
            y_margin = data_range * 0.1;  % 上下各留10%余量
            ylim([data_min - y_margin, data_max + y_margin]);
        else
            % 使用默认的从0开始，但留10%上边距
            ylim([0, data_max * 1.1]);
        end
    end
    
    % 添加图例
    legend({'静息态', '注意力态'}, 'Location', 'best', 'FontSize', 11);
    
    % 添加统计信息
    overall_mean_rest = nanmean(subfolder_means_rest);
    overall_mean_attention = nanmean(subfolder_means_attention);
    text(0.02, 0.98, sprintf('受试者数=%d | 静息均值=%.4f | 注意力均值=%.4f | 差异=%.4f', ...
         n_subfolders, overall_mean_rest, overall_mean_attention, overall_mean_attention - overall_mean_rest), ...
         'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 10, ...
         'BackgroundColor', 'white', 'EdgeColor', 'black');
    
    hold off;
    
    % 保存分组柱状图
    fig_grouped_path = fullfile(subject_comparison_folder, sprintf('%s_受试者均值对比_分组.png', feat_name));
    saveas(fig_grouped, fig_grouped_path);
    close(fig_grouped);
    
    % === 图2：合并数据的柱状图（所有样本） ===
    fig_combined = figure('Position', [100, 100, max(1200, n_subfolders*100), 600], 'Visible', 'off');
    
    hold on;
    b = bar(1:n_subfolders, subfolder_means_combined, 'FaceColor', [0.3 0.7 0.3], 'EdgeColor', 'k', 'LineWidth', 1);
    
    % 添加误差棒
    errorbar(1:n_subfolders, subfolder_means_combined, subfolder_stds_combined, ...
             'k.', 'LineWidth', 1.5, 'CapSize', 10);
    
    % 设置图表属性
    grid on;
    xlabel('受试者（子目录）', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(sprintf('%s 特征值（均值 ± 标准差）', feat_name), 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('特征 %s - 各受试者整体均值对比', feat_name), ...
          'FontSize', 14, 'FontWeight', 'bold');
    
    % 设置x轴标签
    set(gca, 'XTick', 1:n_subfolders, 'XTickLabel', subfolder_names, 'XTickLabelRotation', 45);
    xlim([0.5, n_subfolders+0.5]);
    
    % 智能调整y轴范围
    all_data_with_error = [subfolder_means_combined - subfolder_stds_combined, ...
                           subfolder_means_combined + subfolder_stds_combined];
    valid_data = all_data_with_error(~isnan(all_data_with_error) & ~isinf(all_data_with_error));
    
    if ~isempty(valid_data)
        data_min = min(valid_data);
        data_max = max(valid_data);
        data_range = data_max - data_min;
        data_mean = mean(valid_data);
        
        % 根据数据特性调整y轴
        if data_range / abs(data_mean) < 0.1 && data_range > 0
            % 数据变化小，使用紧凑视图
            y_margin = data_range * 0.15;
            ylim([data_min - y_margin, data_max + y_margin]);
        elseif data_min > 0 && data_min / data_max > 0.5
            % 不从0开始
            y_margin = data_range * 0.1;
            ylim([data_min - y_margin, data_max + y_margin]);
        else
            % 从0开始
            ylim([0, data_max * 1.1]);
        end
    end
    
    % 在每个柱子上方显示均值
    for s = 1:n_subfolders
        if ~isnan(subfolder_means_combined(s))
            text(s, subfolder_means_combined(s) + subfolder_stds_combined(s), ...
                 sprintf('%.3f', subfolder_means_combined(s)), ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                 'FontSize', 9, 'Color', 'r', 'FontWeight', 'bold');
        end
    end
    
    % 添加统计信息
    overall_mean = nanmean(subfolder_means_combined);
    overall_std = nanstd(subfolder_means_combined);
    cv = (overall_std / overall_mean) * 100;  % 变异系数
    text(0.02, 0.98, sprintf('受试者数=%d | 整体均值=%.4f | 受试者间标准差=%.4f | 变异系数=%.2f%%', ...
         n_subfolders, overall_mean, overall_std, cv), ...
         'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 10, ...
         'BackgroundColor', 'white', 'EdgeColor', 'black');
    
    hold off;
    
    % 保存合并柱状图
    fig_combined_path = fullfile(subject_comparison_folder, sprintf('%s_受试者均值对比_整体.png', feat_name));
    saveas(fig_combined, fig_combined_path);
    close(fig_combined);
end

fprintf('受试者均值方差柱状图已保存到: %s\n', subject_comparison_folder);
fprintf('  - 为每个特征（共%d个）生成了分组柱状图（静息态vs注意力态）\n', n_features);
fprintf('  - 为每个特征（共%d个）生成了整体柱状图（合并所有样本）\n', n_features);

% === 原有的箱型图代码保留（使用subject_features） ===
% 为每个特征生成箱型图
for feat_idx = 1:n_features
    feat_name = feature_names{feat_idx};
    
    if isempty(subject_features.(feat_name).data)
        fprintf('  特征 %s 没有数据，跳过箱型图\n', feat_name);
        continue;
    end
    
    fprintf('  生成特征 %s 的受试者对比箱型图...\n', feat_name);
    
    % 获取该特征的所有受试者数据
    subject_data = subject_features.(feat_name).data;
    subject_names = subject_features.(feat_name).subject_names;
    subfolder_tags = subject_features.(feat_name).subfolder_names;
    n_subjects = length(subject_data);
    
    % 准备boxplot数据：将所有数据合并，并创建分组标签
    all_values = [];
    group_labels = [];
    for i = 1:n_subjects
        all_values = [all_values; subject_data{i}(:)];
        group_labels = [group_labels; i * ones(length(subject_data{i}), 1)];
    end
    
    % 创建图形 - 简化版（显示受试者编号）
    fig_subject = figure('Position', [100, 100, max(1200, n_subjects*60), 600], 'Visible', 'off');
    
    % 绘制箱型图
    boxplot(all_values, group_labels, 'Colors', 'b', 'Symbol', 'r+');
    
    % 设置标题和标签
    title(sprintf('特征 %s 在不同受试者的分布（箱型图）', feat_name), 'FontSize', 14, 'FontWeight', 'bold');
    xlabel('受试者编号', 'FontSize', 12);
    ylabel(sprintf('%s 特征值', feat_name), 'FontSize', 12);
    grid on;
    
    % 添加统计信息文本
    mean_val = mean(all_values);
    std_val = std(all_values);
    text(0.02, 0.98, sprintf('总样本数=%d | 受试者数=%d | 均值=%.4f | 标准差=%.4f', ...
         length(all_values), n_subjects, mean_val, std_val), ...
         'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 10, ...
         'BackgroundColor', 'white', 'EdgeColor', 'black');
    
    % 保存图形
    fig_path = fullfile(subject_comparison_folder, sprintf('%s_受试者箱型图.png', feat_name));
    saveas(fig_subject, fig_path);
    close(fig_subject);
    
    % 同时保存一个详细的带受试者名称的版本（如果受试者数量不太多）
    if n_subjects <= 50
        fig_subject_detail = figure('Position', [100, 100, max(1400, n_subjects*80), 700], 'Visible', 'off');
        
        % 创建简化的受试者标签（只保留文件名前部分）
        simplified_labels = cell(1, n_subjects);
        for i = 1:n_subjects
            [~, name_only, ~] = fileparts(subject_names{i});
            if length(name_only) > 15
                simplified_labels{i} = [name_only(1:12) '...'];
            else
                simplified_labels{i} = name_only;
            end
        end
        
        % 绘制带标签的箱型图
        boxplot(all_values, group_labels, 'Labels', simplified_labels, 'Colors', 'b', ...
                'Symbol', 'r+', 'LabelOrientation', 'inline');
        
        title(sprintf('特征 %s 在不同受试者的分布（详细箱型图）', feat_name), 'FontSize', 14, 'FontWeight', 'bold');
        xlabel('受试者', 'FontSize', 12);
        ylabel(sprintf('%s 特征值', feat_name), 'FontSize', 12);
        set(gca, 'XTickLabelRotation', 45);
        grid on;
        
        text(0.02, 0.98, sprintf('总样本数=%d | 受试者数=%d | 均值=%.4f | 标准差=%.4f', ...
             length(all_values), n_subjects, mean_val, std_val), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 10, ...
             'BackgroundColor', 'white', 'EdgeColor', 'black');
        
        fig_detail_path = fullfile(subject_comparison_folder, sprintf('%s_受试者箱型图_详细.png', feat_name));
        saveas(fig_subject_detail, fig_detail_path);
        close(fig_subject_detail);
    end
end

% 生成一个综合对比图：所有特征的受试者间变异系数
fprintf('  生成特征变异系数对比图...\n');
fig_cv = figure('Position', [100, 100, 1000, 600], 'Visible', 'off');
cv_values = zeros(1, n_features);
feat_labels_plot = {};

for feat_idx = 1:n_features
    feat_name = feature_names{feat_idx};
    if ~isempty(subject_features.(feat_name).data)
        % 计算所有受试者的均值
        subject_means = cellfun(@mean, subject_features.(feat_name).data);
        cv_values(feat_idx) = std(subject_means) / mean(subject_means) * 100;  % 变异系数(%)
        feat_labels_plot{feat_idx} = feat_name;
    else
        cv_values(feat_idx) = 0;
        feat_labels_plot{feat_idx} = feat_name;
    end
end

bar(cv_values);
set(gca, 'XTickLabel', feat_labels_plot, 'XTickLabelRotation', 45);
xlabel('特征名称', 'FontSize', 12);
ylabel('变异系数 (%)', 'FontSize', 12);
title('各特征在受试者间的变异程度', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

% 添加数值标注
for i = 1:n_features
    if cv_values(i) > 0
        text(i, cv_values(i), sprintf('%.1f%%', cv_values(i)), ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    end
end

fig_cv_path = fullfile(subject_comparison_folder, '特征变异系数对比.png');
saveas(fig_cv, fig_cv_path);
close(fig_cv);

fprintf('\n所有受试者对比图表已完成:\n');
fprintf('  - 受试者均值柱状图（分组）: %d张\n', n_features);
fprintf('  - 受试者均值柱状图（整体）: %d张\n', n_features);
fprintf('  - 受试者对比箱型图: 根据数据可用性生成\n');
fprintf('  - 特征变异系数对比图: 1张\n');


%% 保存结果
fprintf('\n保存结果...\n');
try
    % 保存到Excel (多个sheet)
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    results_file = fullfile(root_folder, sprintf('多子目录特征对比结果_%s.xlsx', timestamp));
    
    % Sheet1: 子目录综合比较
    summary_table = cell(n_subfolders + 1, 4);
    summary_table(1, :) = {'子目录名称', '最佳特征', '最高推荐度', '平均推荐度'};
    for s = 1:n_subfolders
        summary_table{s+1, 1} = subfolder_names{s};
        summary_table{s+1, 2} = subfolder_best_features{s};
        summary_table{s+1, 3} = subfolder_scores(s);
        summary_table{s+1, 4} = subfolder_avg_scores(s);
    end
    T_summary = cell2table(summary_table(2:end, :), 'VariableNames', summary_table(1, :));
    writetable(T_summary, results_file, 'Sheet', '子目录综合比较');
    
    % Sheet2-N: 各子目录的详细结果
    for s = 1:n_subfolders
        sheet_name = sprintf('子目录_%s', subfolder_names{s});
        % 防止sheet名称过长或包含非法字符
        sheet_name = strrep(sheet_name, '/', '_');
        sheet_name = strrep(sheet_name, '\', '_');
        if length(sheet_name) > 31
            sheet_name = sheet_name(1:31);
        end
        
        results_table = subfolder_results{s};
        if size(results_table, 1) > 1
            T = cell2table(results_table(2:end, :), 'VariableNames', results_table(1, :));
            writetable(T, results_file, 'Sheet', sheet_name);
        end
    end
    
    fprintf('结果已保存到: %s\n', results_file);
catch ME
    % 如果Excel保存失败，保存到MAT文件
    warning('Excel保存失败: %s', ME.message);
    results_file = fullfile(root_folder, sprintf('多子目录特征对比结果_%s.mat', timestamp));
    save(results_file, 'subfolder_results', 'subfolder_features', 'subfolder_names', ...
         'subfolder_best_features', 'subfolder_scores', 'subfolder_avg_scores', ...
         'best_subfolder_name', 'best_subfolder_idx');
    fprintf('结果已保存到MAT文件: %s\n', results_file);
end

fprintf('\n========== 分析完成 ==========\n');
fprintf('推荐配置:\n');
fprintf('  - 最佳子目录: %s\n', best_subfolder_name);
fprintf('  - 最佳特征: %s\n', subfolder_best_features{best_subfolder_idx});
fprintf('  - 推荐度得分: %.2f/100\n', best_max_score);
fprintf('  - 子目录平均得分: %.2f/100\n', subfolder_avg_scores(best_subfolder_idx));
fprintf('\n生成的图表总结:\n');
fprintf('  - 综合对比图: 2张 (子目录综合比较, 各特征在不同子目录的表现)\n');
fprintf('  - 最佳子目录图: 2张 (特征箱线图, Top3特征密度图)\n');
fprintf('  - 各子目录详细图: %d张 (每个子目录2张)\n', n_subfolders * 2);
fprintf('  - 受试者均值柱状图: %d张 (每个特征2张: 分组+整体)\n', n_features * 2);
fprintf('  - 受试者对比箱型图: 根据数据可用性生成\n');
fprintf('  - 受试者变异系数图: 1张\n');
fprintf('  总计约: %d 张主要图表\n', 5 + n_subfolders*2 + n_features*2);
fprintf('  - 特征变异系数图: 1张\n');
fprintf('  总计约 %d 张图表\n', 4 + n_subfolders * 2 + n_features + 1);
fprintf('\n所有图表均保存在: %s\n', figure_folder);
fprintf('========================================\n');

%% 恢复图形显示设置
set(0, 'DefaultFigureVisible', 'on');

%% 辅助函数

function overlap = calculate_overlap(data1, data2)
    % 计算两个分布的重叠系数
    [f1, x1] = ksdensity(data1);
    [f2, x2] = ksdensity(data2);
    
    % 统一x轴范围
    x_min = min([x1, x2]);
    x_max = max([x1, x2]);
    x_common = linspace(x_min, x_max, 200);
    
    % 插值到相同的x轴
    f1_interp = interp1(x1, f1, x_common, 'linear', 0);
    f2_interp = interp1(x2, f2, x_common, 'linear', 0);
    
    % 计算重叠面积
    overlap = trapz(x_common, min(f1_interp, f2_interp));
end

function interpretation = interpret_cohens_d(d)
    % 解释Cohen's d的大小
    d = abs(d);
    if d < 0.2
        interpretation = '极小效应';
    elseif d < 0.5
        interpretation = '小效应';
    elseif d < 0.8
        interpretation = '中等效应';
    else
        interpretation = '大效应';
    end
end

function star = get_significance_star(p)
    % 根据p值返回显著性星号
    if p < 0.001
        star = '***';
    elseif p < 0.01
        star = '**';
    elseif p < 0.05
        star = '*';
    else
        star = 'n.s.';
    end
end