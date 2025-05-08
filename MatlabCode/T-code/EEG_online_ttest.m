clc
close all;
clear all;
% load testdata
data = importdata("D:\pycharm Project\ADHD-master\data\oksQL7aHWZ0qkXkFP-oC05eZugE8\0418\0418 SF头顶风景画移动+心算1.txt");
ch2 = data(:,2);
% ch2 = data./12;
Fs = 250;
% % 3 7 11
ref = ch2(1:Fs*30);
test = ch2(Fs*30:Fs*60);

%% preprocess
[ref_d1] = EEGPreprocess(ref, Fs, "vmd_cca");
[test_d2] = EEGPreprocess(test, Fs, "vmd_cca");

% 小波包分解
[rex_ref] = waveletpackdec(ref_d1);
[rex_test] = waveletpackdec(test_d2);

%% 波段
% theta1 3.9 – 7.8 Hz  2
% theta2 7.8 – 11.7 Hz  3
% alpha  11.7 - 15.625 4
% beta 15.625-31.25 5
f1 =  7.8 ;
f2 = 11.7;
index = 3;
win_length = 0.5;

%% ref
[pxx_ref,f,energy_r_ref,energy_m_ref]  = LFP_pspectrum(rex_ref,win_length,Fs,f1,f2,index);
[pxx_test,f,energy_r_test,energy_m_test]  = LFP_pspectrum(rex_test,win_length,Fs,f1,f2,index);

%% test
win = 20; % 20个样本最好,10秒
aoutput = [];
output_rt = [];
output_tt = [];
p_value_rt = [];
p_value_tt = [];
output_bayes= [];
alpha = 0.05;
for i = 1:length(energy_m_test)-win
    x = energy_m_test(i:i+win);


%     [h,p,ci,stats] = ttest2(energy_m_ref(end-win:end),x,"Alpha",alpha,'Tail','right');
    [h,p,ci,stats] = ttest2(energy_m_ref(end-win:end),x,"Alpha",alpha,'Tail','right'); % 配对双样本校验
    output_tt(i) = h;
    p_value_tt(i) = p;


    [p,h,stats] = ranksum(energy_m_ref(end-win:end),x,'alpha',alpha);
%     [p,h,stats] = ranksum(energy_m_ref,x);
    output_rt(i) = h;
    p_value_rt(i) = p;

    out = BayesDynamicFusion(sum(output_tt)/i,1);
    output_bayes(i) = out;


end
% u_tt = mean(p_value_tt)
% std_tt = std(p_value_tt)
% p_n_tt = sum(output_tt)/length(output_tt)
% u_rt = mean(p_value_rt)
% std_rt = std(p_value_rt)
% p_n_rt = sum(output_rt)/length(output_rt)


% figure;
% time= [1:length(output_tt)] * 0.5+30;
% subplot(4,1,1)
% 
% e = [energy_m_ref(end-win:end),energy_m_test];
% plot([1:length(e)] * 0.5+win*0.5,e);
% title('rat05: 1013空气测试ex5,{\theta}2平均功率谱,第30s通气')
% xlabel('time/s')
% subplot(4,1,2)
% plot(time,p_value_tt)
% xlabel('time/s')
% title('信号时长10s')
% ylabel('P_VALUE')
% % ylim([0 0.1])
% hold on
% plot(time,p_value_rt)
% xlabel('time/s')
% legend('双样本T检验','秩和校验')
% subplot(4,1,3)
% plot(time,output_tt)
% % ylim([0 1])
% title(['双样本T检验,阳性率',num2str(sum(output_tt)/length(output_tt))])
% subplot(4,1,4)
% plot(time,output_rt)
% ylim([0 1])
% title(['秩和校验,阳性率',num2str(sum(output_rt)/length(output_rt))])

figure;
time= [0:length(output_tt)-1] * 0.5+30;
subplot(3,1,1)

e = [energy_m_ref(end-win:end),energy_m_test];
plot([1:length(e)] * 0.5+win*0.5,e);
title('rat05: 1013氨气测试ex7,{\theta}2平均功率谱,第30s通气')
xlabel('time/s')

subplot(3,1,2)
plot(time,output_tt)
% ylim([0 1])
title(['双样本T检验,阳性率',num2str(sum(output_tt)/length(output_tt))])
subplot(3,1,3)
plot(time,output_bayes)
ylim([0 1])
title(['贝叶斯判决'])


% output = [output_u, output_t];
% figure
% time= [1:length(output)] * 0.5+30;
% plot(time,output)
% xlabel('time/s')
% title('rat01: 0822上午空气测试ex02')
% ylim([0,1])
% sum(output)/length(output)




