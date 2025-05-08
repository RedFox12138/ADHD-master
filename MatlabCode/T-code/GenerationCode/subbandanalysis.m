
%% 
clc
close all;
clear all;


% theta1 3.9 – 7.8 Hz  2
% theta2 7.8 – 11.7 Hz  3
% alpha  11.7 - 15.625 4
% beta 15.625-31.25 5
f1 = 3.9;
f2 = 7.8;
index = 2;
Fs = 250;
win_length = 0.5;

signal_air_ch1 = [];
signal_nh3_ch1 = [];
signal_air_ch2 = [];
signal_nh3_ch2 = [];
signal_Null_ch1 = [];
signal_Null_ch2 = [];
% loaddata
air01  = importdata('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\DANN数据集生成\denoise_data_vmd_cca\rat03\rat03-air01-0823a.csv');
[rex_ch1] = waveletpackdec(air01(:,1));
[rex_ch2] = waveletpackdec(air01(:,2));
signal_air_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
signal_air_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];

air02  = importdata('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\DANN数据集生成\denoise_data_vmd_cca\rat03\rat03-air02-0823a.csv');
[rex_ch1] = waveletpackdec(air02(:,1));
[rex_ch2] = waveletpackdec(air02(:,2));
signal_air_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
signal_air_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];


nh303  = importdata('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\DANN数据集生成\denoise_data_vmd_cca\rat03\rat03-nh303-0823a.csv');
[rex_ch1] = waveletpackdec(nh303(:,1));
[rex_ch2] = waveletpackdec(nh303(:,2));
signal_nh3_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
signal_nh3_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];

nh304  = importdata('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\DANN数据集生成\denoise_data_vmd_cca\rat03\rat03-nh304-0823a.csv');
[rex_ch1] = waveletpackdec(nh304(:,1));
[rex_ch2] = waveletpackdec(nh304(:,2));
signal_nh3_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
signal_nh3_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];

%% 小波包分解





[p_theta1_nh3_ch1,f_theta1]  = LFP_pspectrum(signal_nh3_ch1,win_length,Fs);
[p_theta1_air_ch1,f_theta1]  = LFP_pspectrum(signal_air_ch1,win_length,Fs);
[p_theta1_nh3_ch2,f_theta1]  = LFP_pspectrum(signal_nh3_ch2,win_length,Fs);
[p_theta1_air_ch2,f_theta1]  = LFP_pspectrum(signal_air_ch2,win_length,Fs);
% [p_theta1_Null_ch2,f_theta1]  = LFP_pspectrum(signal_Null_ch2,win_length,Fs);

figure
% plot ch1 theta1 3.9 – 7.8 Hz
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
legend('NH3','AIR','FontName','Times New Roman','FontSize',12)
title('ch1: {\theta}1:3.9-7.8 Hz','FontName','Times New Roman','FontSize',12)

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
legend('NH3','AIR','FontName','Times New Roman','FontSize',12)
title('ch2: {\theta}1:3.9-7.8 Hz','FontName','Times New Roman','FontSize',12)
