%% code for training dataset generation
% written by Wei Nannan
% v1   2023/8/24
% steps:
%     1. filter: 100Hz LPF-> 50Hz notch filter -> 0.5Hz HPF
%     2. remove bad signal： >50uV
%     3. denoise: EEMD-CCA
%
%
%Function
%  input:
%      d1: raw_signal，1XN
%      fs: sample rate
%  output:
%      out: 如果输出是[]，表示该信号应该已经被剔除，否则输出为1XN序列

%% load data

ch1 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\DANN数据集生成\raw_data\dataset_8\rat03\0823下午\4\08-23-15-06-34_ch1.txt');
ch1=ch1./12;
ch2 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\DANN数据集生成\raw_data\dataset_8\rat03\0823下午\4\08-23-15-06-34_ch2.txt');
ch2=ch2./12;

% 预处理
L(1)=length(ch1);
L(2)=length(ch2);

% outputaddress
filename = '/rat03-nh304-0823p.csv';
ratnum = '/rat03';
addr1 = ['./filter_data' , ratnum , filename];
addr2 = ['./denoise_data_wpt_cca' , ratnum , filename];
addr3 = ['./denoise_data_vmd_cca' , ratnum , filename];
addr4 = ['./denoise_data_eemd_cca' , ratnum , filename];
Fs = 250;%采样率

Min=min(L);
ch1=ch1(1:Min);
ch2=ch2(1:Min);
% d1=ch1(Fs*30:Fs*210); % 3分钟  180+30 50s后通3min空气 总时长3.8409min
% d2=ch2(Fs*30:Fs*210);

d1=[ ch1(Fs*30:Fs*120); ch1(Fs*210:Fs*299-1)] ; % 90+40 180
d2=[ ch2(Fs*30:Fs*120); ch2(Fs*210:Fs*299-1)] ;  %3、3、30s后通氨气，2min06s时给奖赏,4min结束奖赏 总时长5.79min
% preprocess
method = "none"
[d1_filter] = EEGPreprocess(d1,Fs,"none");
length(d1_filter)
[d2_filter] = EEGPreprocess(d2,Fs,"none");
csvwrite(addr1,[d1_filter' d2_filter']);


% denoise wpt_cca
method = "wpt_cca"
[d1_denoise] = EEGPreprocess(d1,Fs,"wpt_cca");
length(d1_denoise)
[d2_denoise] = EEGPreprocess(d2,Fs,"wpt_cca");
csvwrite(addr2,[d1_denoise' d2_denoise']);

%denoise vmd_cca
method ="vmd_cca"
[d1_denoise] = EEGPreprocess(d1,Fs,"vmd_cca");
length(d1_denoise)
[d2_denoise] = EEGPreprocess(d2,Fs,"vmd_cca");
csvwrite(addr3,[d1_denoise' d2_denoise']);

%denoise eemd_cca
method ="eemd_cca"
[d1_denoise] = EEGPreprocess(d1,Fs,"eemd_cca");
length(d1_denoise)
[d2_denoise] = EEGPreprocess(d2,Fs,"eemd_cca");
csvwrite(addr4,[d1_denoise' d2_denoise']);


