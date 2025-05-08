% 1-D EEG sinal preprocessing
% written by Wei Nannan
% v1   2023/7/26
% v1.1 2023/7/28 修改滤波器
% steps:
%     1. filter: 100Hz LPF-> 50Hz notch filter -> 0.5Hz HPF
%     2. remove bad signal： >50uV
%     3. denoise: EEMD-CCA
%
%
%Function
%  input:
%      d1: 1-D eeg sinal，1XN
%      fs: sample rate
%  output:
%      out: 如果输出是[]，表示该信号应该已经被剔除，否则输出为1XN序列

% testdata

function [d1,out] = EEGPreprocess(signal, fs, DenoiseMethod)

if ~isrow(signal)
    d1 = signal';
else
    d1 = signal;
end

out = [];
%% filter
% [b,a] = butter(6,0.5/(fs/2),'high'); % 0.5Hz高通巴特沃斯 
% % freqz(b,a,[],250)
% d1 = filter(b, a, d1);
% 
% [b,a] = butter(4,[49 51]/(fs/2),'stop'); % 50Hz 工频陷波
% d1 = filter(b, a, d1);
% 
% [b,a] = butter(6,100/(fs/2),'low'); % 100Hz低通
% d1 = filter(b, a, d1);
% 
d1 = signal;
% 二阶50 Hz的陷波
[ d1 ] = IIR( d1,fs,50 );
[ d1 ] = IIR( d1,fs,100 );
base = medfilt1(d1,125);  
d1 = d1-base;
d1 = HPF( d1,fs,0.5 );
d1 = LPF(d1,fs,50);


%% 
switch DenoiseMethod
    case "none"
        out = d1;
    case "wpt_cca"
        out = EEG_wpt_cca(d1);
    case "ssa_cca"
        out = SSA_CCA(d1,10);
    case "eemd_cca"
        out = EEG_eemd_cca(d1);
    case "vmd_cca"
        out = EEG_vmd_cca(d1);

end



end

