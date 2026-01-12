function features = calculate_all_features(samples, Fs, theta_band, beta_band)
% calculate_all_features - 计算所有样本的所有特征
%
% 输入:
%   samples - 样本矩阵 (n_samples x n_points)
%   Fs - 采样率
%   theta_band - Theta频带范围 [low, high]
%   beta_band - Beta频带范围 [low, high]
%
% 输出:
%   features - 结构体，包含所有特征的平均值

    % WPE_IA_Composite 权重配置（与CalculateFeature.m一致）
    perm_wt_val_w = 4;
    inv_alpha_val_w = 0.6;

    n_samples = size(samples, 1);
    
    % 初始化特征数组（仅保留3个特征）
    SampEn_vals = zeros(n_samples, 1);
    PermEn_Weighted_vals = zeros(n_samples, 1);
    WPE_IA_Composite_vals = zeros(n_samples, 1);
    
    % 对每个样本计算特征
    for i = 1:n_samples
        segment = samples(i, :);
        
        % === SampEn 特征 ===
        try
            Samp = SampEn(segment);
            SampEn_vals(i) = Samp(3);
        catch
            SampEn_vals(i) = NaN;
        end
        
        % === PermEn_Weighted 特征 ===
        try
            perm_wt = getPermEn(segment, 'variant', 'weighted');
            PermEn_Weighted_vals(i) = perm_wt;
        catch
            PermEn_Weighted_vals(i) = NaN;
        end
        
        % === WPE_IA_Composite 特征 ===
        try
            % 获取加权排列熵值
            perm_wt_val = getPermEn(segment, 'variant', 'weighted');
            % 获取Alpha倒数值
            inv_alpha_val = calculateInverseAlpha(segment, Fs, theta_band, beta_band);
            % 计算复合特征
            wpe_ia_composite = (perm_wt_val^perm_wt_val_w) * (inv_alpha_val^inv_alpha_val_w);
            WPE_IA_Composite_vals(i) = wpe_ia_composite;
        catch
            WPE_IA_Composite_vals(i) = NaN;
        end
    end
    
    % 返回所有特征的平均值（忽略NaN值）
    features.SampEn = mean(SampEn_vals, 'omitnan');
    features.PermEn_Weighted = mean(PermEn_Weighted_vals, 'omitnan');
    features.WPE_IA_Composite = mean(WPE_IA_Composite_vals, 'omitnan');
end
