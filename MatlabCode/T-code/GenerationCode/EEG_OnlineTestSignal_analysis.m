%% EEG EEG_OnlineTestSignal_analysis
clc
close all;
clear all;

%% load data
data = importdata('E:\brainData\在线测试数据\2023年10月27日测试数据\data_rat2_air_ex26.txt');
Fs = 250;%采样率
ch1 = data(:,1)./12;
ch2 = data(:,2)./12;
% ch1 = data'./12;
% ch2 = data'./12;
L(1)=length(ch1);
L(2)=length(ch2); 
Min = min(L);
ch1 = ch1(1:Min);
ch2 = ch2(1:Min);
% ch1 = d1_250hz;
% ch2 = d1_250hz;
% Min=min(L);
%% 波段
% theta1 3.9 – 7.8 Hz  2
% theta2 7.8 – 11.7 Hz  3
% alpha  11.7 - 15.625 4
% beta 15.625-31.25 5
f1 = 15.625 ;
f2 = 31.25;
index = 5;
title_NAME_CH1 = 'ch1: {\beta}:15.625-31.25 Hz';
title_NAME_CH2 = 'ch2: {\beta}:15.625-31.25 Hz';
%%
signal_air_ch1 = [];
signal_nh3_ch1 = [];
signal_air_ch2 = [];
signal_nh3_ch2 = [];
%% 空白区 选择第1~29秒

d1=ch1(Fs*30:Fs*90);
d2=ch2(Fs*30:Fs*90);
[ex01_d1_output] = EEGPreprocess(d1, Fs, "vmd_cca");
[ex01_d2_output] = EEGPreprocess(d2, Fs, "vmd_cca");

% 小波包分解
[rex_ch1] = waveletpackdec(ex01_d1_output);
[rex_ch2] = waveletpackdec(ex01_d2_output);

signal_air_ch1 = [signal_air_ch1;rex_ch1(:,index)];
signal_air_ch2 = [signal_air_ch2;rex_ch2(:,index)];

%%  通气区 选择第30~60秒
data = importdata('E:\brainData\在线测试数据\2023年10月27日测试数据\data_rat2_nh3_ex25.txt');
Fs = 250;%采样率
ch1 = data(:,1)./12;
ch2 = data(:,2)./12;
% 
d1=ch1(Fs*30:Fs*90); 
d2=ch2(Fs*30:Fs*90);
[ex03_d1_output] = EEGPreprocess(d1, Fs, "vmd_cca");
[ex03_d2_output] = EEGPreprocess(d2, Fs, "vmd_cca");

% 小波包分解
[rex_ch1] = waveletpackdec(ex03_d1_output);
[rex_ch2] = waveletpackdec(ex03_d2_output);

signal_nh3_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
signal_nh3_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];


%% plot
win_length = 0.5;
% f1 = 7.8;
% f2 = 15.625;
[p_theta1_nh3_ch1,f_theta1,r1]  = LFP_pspectrum(signal_nh3_ch1,win_length,Fs,f1,f2,1);
[p_theta1_air_ch1,f_theta1,r2]  = LFP_pspectrum(signal_air_ch1,win_length,Fs,f1,f2,1);

[p_theta1_nh3_ch2,f_theta1,r3]  = LFP_pspectrum(signal_nh3_ch2,win_length,Fs,f1,f2,1);
[p_theta1_air_ch2,f_theta1,r4]  = LFP_pspectrum(signal_air_ch2,win_length,Fs,f1,f2,1);
% [p_theta1_Null_ch2,f_theta1]  = LFP_pspectrum(signal_Null_ch2,win_length,Fs);

figure
index1 = find(f_theta1>=f1);
index2 = find(f_theta1<=f2);
index = [index1(1):index2(end)];
plot(f_theta1(index),p_theta1_nh3_ch1(index),'LineWidth',2)
hold on
plot(f_theta1(index),p_theta1_air_ch1(index),'LineWidth',2)
% hold on
% plot(f_theta1(index),p_theta1_Null_ch1(index),'LineWidth',2)
xlabel('Frequency (Hz)','FontName','Times New Roman','FontSize',12)
ylabel('Power spectrum (dB)','FontName','Times New Roman','FontSize',12)
legend('NH3-TEST(60s)','AIR-TEST(60s)','FontName','Times New Roman','FontSize',12)
title(title_NAME_CH1,'FontName','Times New Roman','FontSize',12)

figure
% plot ch1 theta1 3.9 – 7.8 Hz
index1 = find(f_theta1>=f1);
index2 = find(f_theta1<=f2);
index = [index1(1):index2(end)];
plot(f_theta1(index),p_theta1_nh3_ch2(index),'LineWidth',2)
hold on
plot(f_theta1(index),p_theta1_air_ch2(index),'LineWidth',2)
% hold on
% plot(f_theta1(index),p_theta1_Null_ch2(index),'LineWidth',2)
xlabel('Frequency (Hz)','FontName','Times New Roman','FontSize',12)
ylabel('Power spectrum (dB)','FontName','Times New Roman','FontSize',12)
legend('NH3-TEST(60s)','AIR-TEST(60s)','FontName','Times New Roman','FontSize',12)
title(title_NAME_CH2,'FontName','Times New Roman','FontSize',12)


%%
%% 子波段时域信号
% figure;
% subplot(4,1,1);
% x =[0:1/250:(length(theta1)-1)/250] + 28;
% plot(x,theta1,'Color',"k",'LineWidth',0.5);
% ylabel('{\theta}1','FontName','Times New Roman','FontSize',12)
% % xlabel('time/s','FontName','Times New Roman','FontSize',12)
% % xlim([25 40])
% 
% subplot(4,1,2);
% plot(x,theta2,'Color',"k",'LineWidth',0.5);
% ylabel('{\theta}2','FontName','Times New Roman','FontSize',12)
% % xlabel('time/s','FontName','Times New Roman','FontSize',12)
% % xlim([25 40])
% subplot(4,1,3);
% plot(x,alpha,'Color',"k",'LineWidth',0.5);
% ylabel('{\alpha}','FontName','Times New Roman','FontSize',12)
% % xlabel('time/s','FontName','Times New Roman','FontSize',12)
% 
% subplot(4,1,4);
% plot(x,beta,'Color',"k",'LineWidth',0.5);
% ylabel('{\beta}','FontName','Times New Roman','FontSize',12)
% xlabel('time/s','FontName','Times New Roman','FontSize',12)
% % xlim([25 40])
