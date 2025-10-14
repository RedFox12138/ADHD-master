function denoised_signal = remove_eog(signal, fs, varargin)
% 去除EEG信号中的偶发眼电尖峰
% 输入：
%   signal - 原始EEG信号（1 x N）
%   fs     - 采样频率（Hz）
% 可选参数：
%   'Wavelet' - 小波类型（默认：'db4'）
%   'Level'   - 小波分解层数（默认：5）
%   'ThresholdFactor' - 阈值乘数（默认：4，增大可增强去噪强度）
% 输出：
%   denoised_signal - 去噪后的信号

% 解析可选参数
p = inputParser;
addParameter(p, 'Wavelet', 'db4', @ischar);
addParameter(p, 'Level', 5, @isnumeric);
addParameter(p, 'ThresholdFactor', 4, @isnumeric);
parse(p, varargin{:});

wavelet = p.Results.Wavelet;
level = p.Results.Level;
k = p.Results.ThresholdFactor;

% 1. 小波分解
[c, l] = wavedec(signal, level, wavelet);

% 2. 构建阈值（基于中位数绝对偏差的鲁棒估计）
denoised_c = c; % 复制系数
for i = 1:level
    % 获取当前层细节系数
    det_coef = detcoef(c, l, i);
    
    % 计算鲁棒阈值（基于MAD）
    median_val = median(det_coef);
    mad_val = median(abs(det_coef - median_val));
    sigma = mad_val / 0.6745; % 估计标准差
    threshold = k * sigma * sqrt(2*log(length(signal)));
    
    % 3. 应用硬阈值处理（保留相位信息）
    idx = abs(det_coef) > threshold;
    denoised_coef = det_coef;
    denoised_coef(idx) = 0; % 将尖峰系数置零
    
    % 更新系数向量
    denoised_c = replace_coef(denoised_c, l, denoised_coef, i);
end

% 4. 小波重构
denoised_signal = waverec(denoised_c, l, wavelet);

% 辅助函数：替换特定层的细节系数
    function c_new = replace_coef(c, l, new_coef, level)
        start_idx = sum(l(1:level)) + 1;
        end_idx = start_idx + l(level+1) - 1;
        c_new = c;
        c_new(start_idx:end_idx) = new_coef;
    end
end