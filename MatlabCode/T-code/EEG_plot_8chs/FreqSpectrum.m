function [ log_P,P_avg,f_otdb,ot_avg ] = FreqSpectrum( dn,He_cont,Fs)
% 频域计算
%% INPUT
%  xn - reference signal
%  dn - desired signal
%  L  - window length
%  mu - feedforward step
% miu - feedback step
%  Sw - secondary path
%% OUTPUT
%  log_P - frequency spectrum array
%  P_avg - mean frequency spectrum 
% f_otdb - 1/3 frequency spectrum array
% ot_avg - mean 1/3 frequency spectrum
%% Spectrum
% 使用Welch法估计功率谱
T = length(dn);
n_fft = 2 ^ (floor(log2(T)) + 1);                   % 傅里叶变换点数
t = 0:(n_fft/2);
len_win = n_fft / 8;          % 窗长
overlap = len_win / 2;        % 重叠率为50%，一般取33%~50%

win = rectwin(len_win);       % 矩形窗

% 计算稳定后的功率谱密度
[P1, ~] = pwelch(dn, win, overlap, len_win, Fs);
[P2, f] = pwelch(He_cont, win, overlap, len_win, Fs);
P1 = abs(P1);
P2 = abs(P2);
% [locs1, pks1] = findpeaks(10 * log10(P1), 'MinPeakHeight', 0);
% [locs2, pks2] = findpeaks(10 * log10(P2), 'MinPeakHeight', 0);
% for k = 1: length(locs)
%     locs(k) = f(locs(k));
% end

% 绘图
figure;
plot(f, 10 * log10(P1), 'k');
hold on;
plot(f, 10 * log10(P2), 'r');
ylabel('Amplitude /dB');
xlabel('Frequency /Hz');
title('去噪前后功率谱密度对比');
legend('Noise', 'Noise residue');
grid on;
P = P1 ./ P2;
log_P = 10 * log10(P);

figure;
plot(f, log_P,'k');
title('降噪效果');
ylabel('NR /dB');
xlabel('Frequency /Hz');
grid on;
P_avg = mean( 10 * log10( P( round( length( P ) * 63 / Fs ):round( length( P ) * 1000 / Fs)) ) );     % 63Hz-1kHz

%% 1/3倍频程

% 三分之一倍频程
fb = [56,71,90,112,140,180,224,280,355,450,560,710,900,1120];       % 边界
fc = [63,80,100,125,160,200,250,315,400,500,630,800,1000];          % 中心频率
n = length(P);
f_ot = zeros(1, length(fc));
for i = 1:length(fc)
    f_ot(i) = mean(P(round(fb(i)/Fs*2*n): round(fb(i+1)/Fs*2*n)));
end

f_otdb = 10*log10(f_ot);

figure;
bar(fc, f_otdb,'k');
title('三分之一倍频程');
xlabel('Center Frequency/Hz');
ylabel('NR /dB');
axis tight;
grid on;

ot_avg = mean(10*log10(f_ot));

%% 如需多降噪量对比
% figure;
% plot(f, log_P, 'k');
% hold on;
% plot(f, FeedbackP, 'b');
% ylabel('Amplitude /dB');
% xlabel('Frequency /Hz');
% title('去噪前后功率谱密度对比');
% legend('Hybrid', 'Feedforward','Feedback');
% grid on;
end

