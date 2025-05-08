function [out]  = LFP_featureExtract(data,win_length,Fs,F1,F2)
% 有量纲特征值8个——最大值、最小值、峰峰值、均值、方差、标准差、均方值、均方根值（RMS）
% 无量纲特征值6个——峭度、偏度、波形因子、峰值因子、脉冲因子、裕度因子
% 频域特征值5个——重心频率、均方频率、均方根频率、频率方差、频率标准差 （熵相关特征若干——这个后续补充。还会有其他常用、不常用的特征指标）



DS = [];
AVG = [];
RG = [];
SD = [];
KT = [];

for  t = 1:size(data,2)
     d1 = data(:,t) ;
     f1 = F1(t);
     f2 = F2(t);
     k = 0;
   
    start_index = 0;
    
    %     end_index = 1;
    end_index = (start_index+win_length)*Fs;
    while (end_index)<=length(d1)
        d2 = d1(start_index*Fs+1:end_index);

        [pxx,f] = pspectrum(d2,Fs,'power');


        index1 = find(f>=f1);
        index2 = find(f<=f2);
        index = [index1(1):index2(end)];

        % norm spectrum
        pxx_norm = pow2db(pxx(index))./max(pow2db(pxx(index)));
%        pxx_norm = pxx;
        % feature extraction

        %DS:
        Var = var(d2);
        ds = 0.5*log(2*pi*exp(1)* Var);
        DS(k+1,t) = ds;

        % mean
        AVG(k+1,t) = mean(pxx_norm);

        % range

        RG(k+1,t) =  max(pxx_norm);

        % std
        SD(k+1,t) = std(pxx_norm);

        %
        KT(k+1,t) = kurtosis(pxx_norm);

        k = k + 1;
        start_index = start_index + 0.5;
        end_index = (start_index+win_length)*Fs;
    end
end

out = [ DS, AVG,RG, SD,KT];

end