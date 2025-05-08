%% EEG_EEMD_cca
clc
close all;
clear all;
% addpath(strcat(pwd,'\functions\')) % add path where you saved to memd function 
% save_path = strcat(pwd,'\figs\'); % path where you want to save your figures

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
signal_Null_ch1 = [];
signal_Null_ch2 = [];
%% 空气05

% ch1 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\上午\鼠1\1\08-22-15-27-20_ch1.txt');
% ch1=ch1./12;
% ch2 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\上午\鼠1\1\08-22-15-27-20_ch2.txt');
% ch2=ch2./12;
% 
% % 预处理
% L(1)=length(ch1);
% L(2)=length(ch2);
% Fs = 250;%采样率
% 
% Min=min(L);
% ch1=ch1(1:Min);
% ch2=ch2(1:Min);
% d1=ch1(Fs*40:Fs*100);
% d2=ch2(Fs*40:Fs*100);
% 
% % preprocess
% % [filter_ex01_d1,ex01_d1_output] = EEG_preprocess(d1,Fs);
% % [filter_ex01_d2,ex01_d2_output] = EEG_preprocess(d2,Fs);
% [filter_ex01_d1,ex01_d1_output] = EEGPreprocess(d1, Fs, "vmd_cca");
% [filter_ex01_d2,ex01_d2_output] = EEGPreprocess(d2, Fs, "vmd_cca");
% % csvwrite('filter-rat02-ex01-ch1.csv',filter_ex01_d1');
% % csvwrite('filter-rat02-ex01-ch2.csv',filter_ex01_d2');
% % csvwrite('denoise-rat02-ex01-ch1.csv',ex01_d1_output');
% % csvwrite('denoise-rat02-ex01-ch2.csv',ex01_d2_output');
% % % 小波包分解
% [rex_ch1] = waveletpackdec(ex01_d1_output);
% [rex_ch2] = waveletpackdec(ex01_d2_output);
% % csvwrite('wpd-rat02-ex01-ch1.csv',rex_ch1(:,2:5));
% % csvwrite('wpd-rat02-ex01-ch2.csv',rex_ch2(:,2:5));
% 
% signal_air_ch1 = [signal_air_ch1;rex_ch1(:,index)];
% signal_air_ch2 = [signal_air_ch2;rex_ch2(:,index)];

% % 特征提取
% win_length = 0.5;
% 
% ES_AIR_CH1 = [];
% ES_AIR_CH2 = [];
% DE_AIR_CH1 = [];
% DE_AIR_CH2 = [];
% [ES,DE]  = LFP_featureExtract(rex_ch1(:,index),win_length,Fs,f1,f2);
% ES_AIR_CH1 = [ES_AIR_CH1;ES];
% DE_AIR_CH1 = [DE_AIR_CH1;DE];
% 
% [ES,DE]  = LFP_featureExtract(rex_ch2(:,index),win_length,Fs,f1,f2);
% ES_AIR_CH2 = [ES_AIR_CH2;ES];
% DE_AIR_CH2 = [DE_AIR_CH2;DE];

%% 空气06
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
d1=ch1(Fs*40:Fs*100);
d2=ch2(Fs*40:Fs*100);


% preprocess
% [filter_ex02_d1,ex02_d1_output] = EEG_preprocess(d1,Fs);
% [filter_ex02_d2,ex02_d2_output] = EEG_preprocess(d2,Fs);
[filter_ex02_d1,ex02_d1_output]= EEGPreprocess(d1, Fs, "vmd_cca");
[filter_ex02_d2,ex02_d2_output] = EEGPreprocess(d2, Fs, "vmd_cca");

% csvwrite('filter-rat02-ex02-ch1.csv',filter_ex02_d1');
% csvwrite('filter-rat02-ex02-ch2.csv',filter_ex02_d2');
% csvwrite('denoise-rat02-ex02-ch1.csv',ex02_d1_output');
% csvwrite('denoise-rat02-ex02-ch2.csv',ex02_d2_output');
% 
% 小波包分解
[rex_ch1] = waveletpackdec(ex02_d1_output);
[rex_ch2] = waveletpackdec(ex02_d2_output);
% csvwrite('wpd-rat02-ex02-ch1.csv',rex_ch1(:,2:5));
% csvwrite('wpd-rat02-ex02-ch2.csv',rex_ch2(:,2:5));

signal_air_ch1 = [signal_air_ch1;rex_ch1(:,index)];
signal_air_ch2 = [signal_air_ch2;rex_ch2(:,index)];
% 
% % 特征提取
% win_length = 0.5;
% 
% [ES,DE]  = LFP_featureExtract(rex_ch1(:,index),win_length,Fs,f1,f2);
% ES_AIR_CH1 = [ES_AIR_CH1;ES];
% DE_AIR_CH1 = [DE_AIR_CH1;DE];
% 
% [ES,DE]  = LFP_featureExtract(rex_ch2(:,index),win_length,Fs,f1,f2);
% ES_AIR_CH2 = [ES_AIR_CH2;ES];
% DE_AIR_CH2 = [DE_AIR_CH2;DE];



%%%%% 氨气
%% %%氨气07
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
d1=ch1(Fs*40:Fs*100);
d2=ch2(Fs*40:Fs*100);


%% preprocess
% [filter_ex03_d1,ex03_d1_output] = EEG_preprocess(d1,Fs);
% [filter_ex03_d2,ex03_d2_output] = EEG_preprocess(d2,Fs);

[filter_ex03_d1,ex03_d1_output]= EEGPreprocess(d1, Fs, "vmd_cca");
[filter_ex03_d2,ex03_d2_output] = EEGPreprocess(d2, Fs, "vmd_cca");

% csvwrite('filter-rat02-ex03-ch1.csv',filter_ex03_d1');
% csvwrite('filter-rat02-ex03-ch2.csv',filter_ex03_d2');
% csvwrite('denoise-rat02-ex03-ch1.csv',ex03_d1_output');
% csvwrite('denoise-rat02-ex03-ch2.csv',ex03_d2_output');
%% 小波包分解
[rex_ch1] = waveletpackdec(ex03_d1_output);
[rex_ch2] = waveletpackdec(ex03_d2_output);
% csvwrite('wpd-rat02-ex03-ch1.csv',rex_ch1(:,2:5));
% csvwrite('wpd-rat02-ex03-ch2.csv',rex_ch2(:,2:5));
signal_nh3_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
signal_nh3_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];

% %% 特征提取
% win_length = 0.5;
% 
% ES_NH3_CH1 = [];
% ES_NH3_CH2 = [];
% DE_NH3_CH1 = [];
% DE_NH3_CH2 = [];
% [ES,DE]  = LFP_featureExtract(rex_ch1(:,index),win_length,Fs,f1,f2);
% ES_NH3_CH1 = [ES_NH3_CH1;ES];
% DE_NH3_CH1 = [DE_NH3_CH1;DE];
% 
% [ES,DE]  = LFP_featureExtract(rex_ch2(:,index),win_length,Fs,f1,f2);
% ES_NH3_CH2 = [ES_NH3_CH2;ES];
% DE_NH3_CH2 = [DE_NH3_CH2;DE];

%% %% 氨气08
% ch1 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\下午\鼠1\4\08-22-16-15-53_ch1.txt');
% ch1=ch1./12;
% ch2 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-08-22\下午\鼠1\4\08-22-16-15-53_ch2.txt');
% ch2=ch2./12;
% 
% % 预处理
% L(1)=length(ch1);
% L(2)=length(ch2);
% Fs = 250;%采样率
% %%
% Min=min(L);
% ch1=ch1(1:Min);
% ch2=ch2(1:Min);
% d1=ch1(Fs*40:Fs*100);
% d2=ch2(Fs*40:Fs*100);
% % 
% % 
% % %% preprocess
% % [filter_ex04_d1,ex04_d1_output] = EEG_preprocess(d1,Fs);
% % [filter_ex04_d2,ex04_d2_output] = EEG_preprocess(d2,Fs);
% 
% [filter_ex04_d1,ex04_d1_output]= EEGPreprocess(d1, Fs, "vmd_cca");
% [filter_ex04_d2,ex04_d2_output] = EEGPreprocess(d2, Fs, "vmd_cca");
% % % csvwrite('filter-rat02-ex04-ch1.csv',filter_ex04_d1');
% % % csvwrite('filter-rat02-ex04-ch2.csv',filter_ex04_d2');
% % % csvwrite('denoise-rat02-ex04-ch1.csv',ex04_d1_output');
% % % csvwrite('denoise-rat02-ex04-ch2.csv',ex04_d2_output');
% % %% 小波包分解
% [rex_ch1] = waveletpackdec(ex04_d1_output);
% [rex_ch2] = waveletpackdec(ex04_d2_output);
% % % csvwrite('wpd-rat02-ex04-ch1.csv',rex_ch1(:,2:5));
% % % csvwrite('wpd-rat02-ex04-ch2.csv',rex_ch2(:,2:5));
% signal_nh3_ch1 = [signal_nh3_ch1;rex_ch1(:,index)];
% signal_nh3_ch2 = [signal_nh3_ch2;rex_ch2(:,index)];
% % % ch1 theta1 3.9 – 7.8 Hz
% % % [p_theta1_nh3_ch1,f_theta1]  = LFP_pspectrum(signal_nh3_ch1,win_length,Fs);
% % % [p_theta1_air_ch1,f_theta1]  = LFP_pspectrum(signal_air_ch1,win_length,Fs);
% % % 
% % % [p_theta1_nh3_ch2,f_theta1]  = LFP_pspectrum(signal_nh3_ch2,win_length,Fs);
% % % [p_theta1_air_ch2,f_theta1]  = LFP_pspectrum(signal_air_ch2,win_length,Fs);

%% 空采集分析
% ch1 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-07-14\空采\07-14-11-49-18_ch1.txt');
% ch1=ch1./12;
% ch2 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-07-14\空采\07-14-11-49-18_ch2.txt');
% ch2=ch2./12;
% 
% % 预处理
% L(1)=length(ch1);
% L(2)=length(ch2);
% Fs = 250;%采样率
% Min=min(L);
% ch1=ch1(1:Min);
% ch2=ch2(1:Min);
% d1=ch1(Fs*1:Fs*50);
% d2=ch2(Fs*1:Fs*50);


%% preprocess
% [filter_ex04_d1,ex04_d1_output] = EEG_preprocess(d1,Fs);
% [filter_ex04_d2,ex04_d2_output] = EEG_preprocess(d2,Fs);
% % csvwrite('filter-rat02-ex04-ch1.csv',filter_ex04_d1');
% % csvwrite('filter-rat02-ex04-ch2.csv',filter_ex04_d2');
% % csvwrite('denoise-rat02-ex04-ch1.csv',ex04_d1_output');
% % csvwrite('denoise-rat02-ex04-ch2.csv',ex04_d2_output');
% % 小波包分解
% [rex_ch1] = waveletpackdec(ex04_d1_output);
% [rex_ch2] = waveletpackdec(ex04_d2_output);
% % csvwrite('wpd-rat02-ex04-ch1.csv',rex_ch1(:,2:5));
% % csvwrite('wpd-rat02-ex04-ch2.csv',rex_ch2(:,2:5));
% 
% signal_Null_ch1 = rex_ch1(:,index);
% signal_Null_ch2 = rex_ch2(:,index);

%% ch1 theta1 3.9 – 7.8 Hz
win_length = 0.5;
% signal_nh3_ch1 = ex03_d1_output;
% signal_air_ch1 = ex02_d1_output;

[p_theta1_nh3_ch1,f_theta1,energy_r_nh3_ch1]  = LFP_pspectrum(signal_nh3_ch1,win_length,Fs,f1,f2);
[p_theta1_air_ch1,f_theta1,energy_r_air_ch1]  = LFP_pspectrum(signal_air_ch1,win_length,Fs,f1,f2);
% [p_theta1_Null_ch1,f_theta1]  = LFP_pspectrum(signal_Null_ch1,win_length,Fs);
% 
% signal_nh3_ch2 = ex03_d2_output;
% signal_air_ch2 = ex02_d2_output;
[p_theta1_nh3_ch2,f_theta1,energy_r_nh3_ch2]  = LFP_pspectrum(signal_nh3_ch2,win_length,Fs,f1,f2);
[p_theta1_air_ch2,f_theta1,energy_r_air_ch2]  = LFP_pspectrum(signal_air_ch2,win_length,Fs,f1,f2);
% [p_theta1_Null_ch2,f_theta1]  = LFP_pspectrum(signal_Null_ch2,win_length,Fs);

figure
boxplot([energy_r_nh3_ch1',energy_r_air_ch1'],'Labels',{'NH3','AIR'})
ylabel('bandpower percent(%)','FontName','Times New Roman','FontSize',12)
title('ch1: {\theta}1:3.9-7.8 Hz','FontName','Times New Roman','FontSize',12)


figure
boxplot([energy_r_nh3_ch2',energy_r_air_ch2'],'Labels',{'NH3','AIR'})
ylabel('bandpower percent(%)','FontName','Times New Roman','FontSize',12)
title('ch2: {\theta}1:3.9-7.8 Hz','FontName','Times New Roman','FontSize',12)

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