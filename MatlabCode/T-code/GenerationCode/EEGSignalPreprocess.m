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

function [out] = EEGSignalPreprocess(signal, fs)

if ~isrow(signal)
    d1 = signal';
else
    d1 = signal;
end

out = [];
%% filter
[b,a] = butter(6,0.5/(fs/2),'high'); % 0.5Hz高通巴特沃斯 
% freqz(b,a,[],250)
d1 = filter(b, a, d1);

[b,a] = butter(6,[49 51]/(fs/2),'stop'); % 50Hz 工频陷波
d1 = filter(b, a, d1);

[b,a] = butter(6,100/(fs/2),'low'); % 100Hz低通
d1 = filter(b, a, d1);

%% remove
rm = 0;
Bad_points = sum( abs(d1) > 50);
if Bad_points/length(d1) > 0.2
    rm = nan;
end

%% eemd-cca
if ~isnan(rm)
    goal=7; % 模态数 输出是5+1
    ens=10; %%  次数
    win_N = 100;
    d2 = zeros(1,length(d1));
    for j = 1:length(d1)/win_N
        index = [1+(j-1)*win_N:j*win_N];
        win_d1 = d1(index);
        % eemd
        nos=std(win_d1)*0.2; % 噪声
        [imfs_1] = eemd(win_d1, goal, ens, nos);
        % cca
        X = [imfs_1';zeros(1,size(imfs_1,1))];
        [A,B,r,U,V] = canoncorr(X(1:end-1,:),X(2:end,:));
        %U 置零 U = XA
        zeroEigIndex = find(r<0.92);         
        U(:,zeroEigIndex) = zeros(size(U,1),length(zeroEigIndex));
        X_de = U * inv(A);

        % denoise
        out_d1 = sum(X_de,2);
        d2(index) = out_d1';
    end
    out = d2;
end
end

