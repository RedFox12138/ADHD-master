%% 单通道 LFP analysis
clc
close all;
clear all;

%% load data
%0-10s准备，10-70s静息，70-80s准备，80-140s注意力
data = importdata('E:\brainData\在线测试数据\T-code\新宇data\0418 SF头顶风景画移动+心算2.txt');

data = data(:,1);
data=data./12;

Fs = 250;
% 选择时间点 每组信号是在第2min给氨气刺激
ref_index = [10*Fs:1:70*Fs]; % 参照组
sti_index = [80*Fs:1:140*Fs]; % 刺激1

ref_d1 = data(ref_index);
sti_d1 = data(sti_index);


f1 = 10 ;
f2 = 11.7 ;
index = 3;

winlenth = 6

[p_theta1_nh3_ch1,f_theta1] =  LFP_Win_Process(sti_d1,Fs,index,winlenth,"vmd_cca");%%显示0-50Hz
[p_theta1_air_ch1,f_theta1] =  LFP_Win_Process(ref_d1,Fs,index,winlenth,"vmd_cca");

%% preprocess
% [filter_air_d1,air_d1_output] = EEGPreprocess(air_d1_250hz, 250, "vmd_cca");% 选择降噪算法 "none" ,"wpt_cca","ssa_cca","eemd_cca","vmd_cca"
% [filter_nh3_d1,nh3_d1_output] = EEGPreprocess(nh3_d1_250hz, 250, "vmd_cca");
% 
% %小波包分解
% [rex_air] = waveletpackdec(air_d1_output);
% [rex_nh3] = waveletpackdec(nh3_d1_output);
% 
% signal_air_denoised  = rex_air(:,index);
% signal_nh3_denoised = rex_nh3(:,index);
% 
% %% 频谱分析
% win_length = 0.5; % 以0.5秒为一个信号样本
% [p_theta1_nh3_ch1,f_theta1,energy_r_nh3_ch1,energy_m_nh3_ch1]  = LFP_pspectrum(signal_nh3_denoised,win_length,Fs,f1,f2,1);
% [p_theta1_air_ch1,f_theta1,energy_r_air_ch1,energy_m_air_ch1]  = LFP_pspectrum(signal_air_denoised,win_length,Fs,f1,f2,1);

figure
% plot ch1 theta1 3.9 – 7.8 Hz
index1 = find(f_theta1>=0);
index2 = find(f_theta1<=50);
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
% title('{\theta}2:7.8-11.7 Hz','FontName','Times New Roman','FontSize',12)
title('ch4','FontName','Times New Roman','FontSize',12)
% ylim([-50 -30])


