function attention_score = get_attention_score(features)
    % 获得当前帧的瞬时专注度
    % :param features: 包含各频段特征的结构体
    % :return: 当前专注度得分
    
    weight = [2, 1, 1];
    % attn_score = w_1 * avg_beta / w_2 * avg_alpha + w_3 * avg_theta
    disp(features);
    
    avg_beta = (features.low_beta + features.high_beta) / 2;
    avg_alpha = (features.low_alpha + features.high_alpha) / 2;
    
    numerator = weight(1) * avg_beta;
    denominator = weight(2) * avg_alpha + weight(3) * features.theta;
    
    attention_score = numerator / denominator;
end