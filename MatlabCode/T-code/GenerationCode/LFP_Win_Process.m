function [PWR,f] =  LFP_Win_Process(data,Fs,index,win_length,DenoiseMethod)

k = 0;
PWR = [];
f = 0;
% d1 = data;
start_index = 0;
end_index = (start_index+win_length)*Fs;
while (end_index+1)<=size(data,1)
%     start_index
    d1 = data(start_index*Fs+1:end_index+1,:);
    %%
    % 第一步：信号预处理
    
    [~,d1_denoised] = EEGPreprocess(d1, Fs, DenoiseMethod);
%     d1_denoised = d1;
 
    rms(d1_denoised)
    
%     % 第二步：幅值判断
%     if rms(d1_denoised) > 1500
%         disp('signal discard')
%         start_index = start_index + 0.5;
%         end_index = (start_index+win_length)*Fs;
% 
%         continue; % 超过幅值，丢弃
%     end
%     rms(d1_denoised)
    
%     % 第三步：幅值以内，小波包psd分解
%     [rex_ch1] = waveletpackdec(d1_denoised);

    % 第四步：频谱处理
    [pxx,f] = pspectrum(d1_denoised,Fs,'power','FrequencyResolution',Fs/250);
%     [pxx,f] = pspectrum(d1_denoised,Fs,'power');
%     [pxx,f] = pspectrum(rex_ch1(:,index),Fs,'power','FrequencyResolution',Fs/250);
    if isempty(PWR)
        PWR = pow2db(pxx);
    else
        PWR = PWR + pow2db(pxx);
    end

    k = k + 1;

    start_index = start_index + 0.5;
    end_index = (start_index+win_length)*Fs;
end

PWR = PWR./k;
%
end