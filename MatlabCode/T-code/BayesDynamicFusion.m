
function [output] = BayesDynamicFusion(p_H,ratNum)
% 贝叶斯动态融合
% 输入： p_H：当前时刻的阳性率，计算方式为Test区间，阳性数量/总解码次数
%        ratNum：用于检测的老鼠的编号，目前仅支持1,3
% 输出：
%     output：0:阴性，1：阳性
%%

switch ratNum
    case 1
        FNR = 0; % rat01的假阳性概率
        SPC = 0.074; % rat01的特异性概率
        p_b = 0.3468; % RAT01 阳性率
    case 3
        FNR = 0; % rat03的假阳性概率
        SPC = 0.741; % rat03的特异性概率
        p_b = 0.155  ;% RAT03 阳性率
    case 4
        FNR = 0.056; % rat03的假阳性概率
        SPC = 0.5; % rat03的特异性概率
        p_b = 0.155  ;% RAT03 阳性率
    case 5
        FNR = 0.1111; % rat03的假阳性概率
        SPC = 0.7778; % rat03的特异性概率
        p_b = 0.155  ;% RAT03 阳性率
    otherwise
        disp('other value')
end

% 计算后验概率
Poster_H0_B = FNR * (1 - p_H*0.5) / p_b; % 在条件B下为空气诱导的后验概率
Poster_H1_B = SPC * p_H * 0.5 / p_b; % 在条件B下为氨气诱导的后验概率

% 最大后验判决
if Poster_H1_B > Poster_H0_B
    output = 1;
else
    output = 0;
end

end