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

    n_samples = size(samples, 1);
    
    % 初始化特征数组
    SampEn_vals = zeros(n_samples, 1);
    FuzzEn_vals = zeros(n_samples, 1);
    MSEn_CI_vals = zeros(n_samples, 1);
    PermEn_vals = zeros(n_samples, 1);
    PermEn_FineGrain_vals = zeros(n_samples, 1);
    PermEn_Modified_vals = zeros(n_samples, 1);
    PermEn_AmpAware_vals = zeros(n_samples, 1);
    PermEn_Weighted_vals = zeros(n_samples, 1);
    PermEn_Edge_vals = zeros(n_samples, 1);
    PermEn_Uniquant_vals = zeros(n_samples, 1);
    XPermEn_vals = zeros(n_samples, 1);
    LZC_vals = zeros(n_samples, 1);
    HFD_vals = zeros(n_samples, 1);
    FDD_Mean_vals = zeros(n_samples, 1);
    FDD_Std_vals = zeros(n_samples, 1);
    TBR_vals = zeros(n_samples, 1);
    Pope_Index_vals = zeros(n_samples, 1);
    Inverse_Alpha_vals = zeros(n_samples, 1);
    Beta_Alpha_Ratio_vals = zeros(n_samples, 1);
    Spectral_Slope_vals = zeros(n_samples, 1);
    Complexity_Activity_vals = zeros(n_samples, 1);
    Complexity_Mobility_vals = zeros(n_samples, 1);
    Complexity_Complexity_vals = zeros(n_samples, 1);
    
    % 对每个样本计算特征
    for i = 1:n_samples
        segment = samples(i, :);
        
        % === 熵特征 ===
        try
            Samp = SampEn(segment);
            SampEn_vals(i) = Samp(3);
        catch
            SampEn_vals(i) = NaN;
        end
        
        try
            Fuzz = FuzzEn(segment);
            FuzzEn_vals(i) = Fuzz(1);
        catch
            FuzzEn_vals(i) = NaN;
        end
        
        try
            Mobj = struct('Func', @SampEn);
            [~, CI] = MSEn(segment, Mobj, 'Scales', 5);
            MSEn_CI_vals(i) = CI;
        catch
            MSEn_CI_vals(i) = NaN;
        end
        
        % === 排列熵系列 ===
        try
            [perm_val, ~, ~] = PermEn(segment, 'm', 4);
            PermEn_vals(i) = perm_val(end);
        catch
            PermEn_vals(i) = NaN;
        end
        
        try
            perm_fg = getPermEn(segment, 'variant', 'finegrain');
            PermEn_FineGrain_vals(i) = perm_fg;
        catch
            PermEn_FineGrain_vals(i) = NaN;
        end
        
        try
            perm_mod = getPermEn(segment, 'variant', 'modified');
            PermEn_Modified_vals(i) = perm_mod;
        catch
            PermEn_Modified_vals(i) = NaN;
        end
        
        try
            perm_amp = getPermEn(segment, 'variant', 'ampaware');
            PermEn_AmpAware_vals(i) = perm_amp;
        catch
            PermEn_AmpAware_vals(i) = NaN;
        end
        
        try
            perm_wt = getPermEn(segment, 'variant', 'weighted');
            PermEn_Weighted_vals(i) = perm_wt;
        catch
            PermEn_Weighted_vals(i) = NaN;
        end
        
        try
            perm_edge = getPermEn(segment, 'variant', 'edge');
            PermEn_Edge_vals(i) = perm_edge;
        catch
            PermEn_Edge_vals(i) = NaN;
        end
        
        try
            perm_uniq = getPermEn(segment, 'variant', 'uniquant', 'alpha', 4);
            PermEn_Uniquant_vals(i) = perm_uniq;
        catch
            PermEn_Uniquant_vals(i) = NaN;
        end
        
        try
            mid_point = floor(length(segment) / 2);
            if mid_point > 10
                sig1 = segment(1:mid_point);
                sig2 = segment(mid_point+1:end);
                xperm_val = XPermEn(sig1, sig2);
                XPermEn_vals(i) = xperm_val;
            else
                XPermEn_vals(i) = NaN;
            end
        catch
            XPermEn_vals(i) = NaN;
        end
        
        % === 其他复杂度特征 ===
        try
            lzc_val = calculateLZC(segment);
            LZC_vals(i) = lzc_val;
        catch
            LZC_vals(i) = NaN;
        end
        
        % === 分形特征 ===
        try
            hfd_val = HigFracDim(segment, 10);
            HFD_vals(i) = hfd_val;
        catch
            HFD_vals(i) = NaN;
        end
        
        try
            [fdd_m, fdd_s] = calculateFDD(segment);
            FDD_Mean_vals(i) = fdd_m;
            FDD_Std_vals(i) = fdd_s;
        catch
            FDD_Mean_vals(i) = NaN;
            FDD_Std_vals(i) = NaN;
        end
        
        % === 频谱特征 ===
        try
            tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
            TBR_vals(i) = tbr_val;
        catch
            TBR_vals(i) = NaN;
        end
        
        try
            pope_val = calculatePopeIndex(segment, Fs);
            Pope_Index_vals(i) = pope_val;
        catch
            Pope_Index_vals(i) = NaN;
        end
        
        try
            inv_alpha = calculateInverseAlpha(segment, Fs);
            Inverse_Alpha_vals(i) = inv_alpha;
        catch
            Inverse_Alpha_vals(i) = NaN;
        end
        
        try
            ba_ratio = calculateBetaAlphaRatio(segment, Fs);
            Beta_Alpha_Ratio_vals(i) = ba_ratio;
        catch
            Beta_Alpha_Ratio_vals(i) = NaN;
        end
        
        try
            slope_val = calculateSpectralSlope(segment, Fs);
            Spectral_Slope_vals(i) = slope_val;
        catch
            Spectral_Slope_vals(i) = NaN;
        end
        
        % === Hjorth参数 ===
        try
            [activity, mobility, complexity] = calculateComplexity(segment, Fs);
            Complexity_Activity_vals(i) = activity;
            Complexity_Mobility_vals(i) = mobility;
            Complexity_Complexity_vals(i) = complexity;
        catch
            Complexity_Activity_vals(i) = NaN;
            Complexity_Mobility_vals(i) = NaN;
            Complexity_Complexity_vals(i) = NaN;
        end
    end
    
    % 返回所有特征的平均值（忽略NaN值）
    features.SampEn = mean(SampEn_vals, 'omitnan');
    features.FuzzEn = mean(FuzzEn_vals, 'omitnan');
    features.MSEn_CI = mean(MSEn_CI_vals, 'omitnan');
    features.PermEn = mean(PermEn_vals, 'omitnan');
    features.PermEn_FineGrain = mean(PermEn_FineGrain_vals, 'omitnan');
    features.PermEn_Modified = mean(PermEn_Modified_vals, 'omitnan');
    features.PermEn_AmpAware = mean(PermEn_AmpAware_vals, 'omitnan');
    features.PermEn_Weighted = mean(PermEn_Weighted_vals, 'omitnan');
    features.PermEn_Edge = mean(PermEn_Edge_vals, 'omitnan');
    features.PermEn_Uniquant = mean(PermEn_Uniquant_vals, 'omitnan');
    features.XPermEn = mean(XPermEn_vals, 'omitnan');
    features.LZC = mean(LZC_vals, 'omitnan');
    features.HFD = mean(HFD_vals, 'omitnan');
    features.FDD_Mean = mean(FDD_Mean_vals, 'omitnan');
    features.FDD_Std = mean(FDD_Std_vals, 'omitnan');
    features.TBR = mean(TBR_vals, 'omitnan');
    features.Pope_Index = mean(Pope_Index_vals, 'omitnan');
    features.Inverse_Alpha = mean(Inverse_Alpha_vals, 'omitnan');
    features.Beta_Alpha_Ratio = mean(Beta_Alpha_Ratio_vals, 'omitnan');
    features.Spectral_Slope = mean(Spectral_Slope_vals, 'omitnan');
    features.Complexity_Activity = mean(Complexity_Activity_vals, 'omitnan');
    features.Complexity_Mobility = mean(Complexity_Mobility_vals, 'omitnan');
    features.Complexity_Complexity = mean(Complexity_Complexity_vals, 'omitnan');
end
