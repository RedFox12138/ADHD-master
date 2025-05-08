%% EEG_EEMD_cca
clc
close all;
clear all;
% addpath(strcat(pwd,'\functions\')) % add path where you saved to memd function 
% save_path = strcat(pwd,'\figs\'); % path where you want to save your figures

% f1 f2 index
% theta1 3.9 – 7.8 Hz  2
% theta2 7.8 – 11.7 Hz  3
% alpha  11.7 - 15.625 4
% beta 15.625-31.25 5
f1 = 15.625 ;
f2 =  31.25 ;
index = 5;
signal_air_ch1 = [];
signal_nh3_ch1 = [];
signal_air_ch2 = [];
signal_nh3_ch2 = [];


%% 空气
ch1 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\上午\鼠1\2\08-22-10-40-50_ch1.txt');
ch1=ch1./12;
ch2 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\上午\鼠1\2\08-22-10-40-50_ch2.txt');
ch2=ch2./12;
% 预处理
L(1)=length(ch1);
L(2)=length(ch2);
Fs = 250;%采样率
%%
Min=min(L);
ch1=ch1(1:Min);
ch2=ch2(1:Min);
d1=ch1(Fs*40:Fs*100);  %% 截取信号时间
d2=ch2(Fs*40:Fs*100);  %% 截取信号时间

% preprocess
[filter_ex02_d1,ex02_d1_output]= EEGPreprocess(d1, Fs, "none");% 选择降噪算法 "none" ,"wpt_cca","ssa_cca","eemd_cca","vmd_cca"
[filter_ex02_d2,ex02_d2_output] = EEGPreprocess(d2, Fs, "none");

% 小波包分解
[rex_ch1] = waveletpackdec(ex02_d1_output);
[rex_ch2] = waveletpackdec(ex02_d2_output);

signal_air_ch1 = [signal_air_ch1;rex_ch1(:,index)];
signal_air_ch2 = [signal_air_ch2;rex_ch2(:,index)];


%% %%氨气
ch1 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\上午\鼠1\3\08-22-10-53-25_ch1.txt');
ch1=ch1./12;
ch2 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\上午\鼠1\3\08-22-10-53-25_ch2.txt');
ch2=ch2./12;


% 预处理
L(1)=length(ch1);
L(2)=length(ch2);
Fs = 250;%采样率
%%
Min=min(L);
ch1=ch1(1:Min);
ch2=ch2(1:Min);
d1=ch1(Fs*40:Fs*100); %% 截取信号时间
d2=ch2(Fs*40:Fs*100);%% 截取信号时间


%% preprocess
[filter_ex03_d1,ex03_d1_output]= EEGPreprocess(d1, Fs, "none");
[filter_ex03_d2,ex03_d2_output] = EEGPreprocess(d2, Fs, "none");


%% 小波包分解
[rex_ch1] = waveletpackdec(ex03_d1_output);
[rex_ch2] = waveletpackdec(ex03_d2_output);
signal_nh3_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
signal_nh3_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];

%% ch1
win_length = 0.5; % 以0.5秒为一个信号样本
[p_theta1_nh3_ch1,f_theta1,energy_r_nh3_ch1]  = LFP_pspectrum(signal_nh3_ch1,win_length,Fs,f1,f2);
[p_theta1_air_ch1,f_theta1,energy_r_air_ch1]  = LFP_pspectrum(signal_air_ch1,win_length,Fs,f1,f2);

% signal_nh3_ch2 = ex03_d2_output;
% signal_air_ch2 = ex02_d2_output;
[p_theta1_nh3_ch2,f_theta1,energy_r_nh3_ch2]  = LFP_pspectrum(signal_nh3_ch2,win_length,Fs,f1,f2);
[p_theta1_air_ch2,f_theta1,energy_r_air_ch2]  = LFP_pspectrum(signal_air_ch2,win_length,Fs,f1,f2);

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
% title('ch1: filtered','FontName','Times New Roman','FontSize',12)
title('ch1: {\beta}:15.625-31.25 Hz','FontName','Times New Roman','FontSize',12)
 ylim([-50 -30])
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
title('ch2: {\beta}:15.625-31.25 Hz','FontName','Times New Roman','FontSize',12)
% title('ch2: vmd-cca denoised','FontName','Times New Roman','FontSize',12)
 ylim([-50 -30])