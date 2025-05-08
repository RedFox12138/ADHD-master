function [pxx,f,energy_r,energy_m]  = LFP_pspectrum(data,win_length,Fs,f1,f2,f_index)

% sample_num = length(data);
k = 0;
PWR = zeros(4096,1);
energy_r = [];
energy_m = [];
f = 0;
% d1 = data;
start_index = 0;

end_index = (start_index+win_length)*Fs;
while (end_index+1)<=size(data,1)

    d1 = data(start_index*Fs+1:end_index+1,:);
    %
    [pxx,f] = pspectrum(d1(:,f_index),Fs,'power');
    PWR = PWR + pow2db(pxx);

    % 相对功率谱比值计算
    index1 = find(f>=f1);
    index2 = find(f<=f2);
    index = [index1(1):index2(end)];
    %     r = sum(pow2db(pxx(index)))/sum(pow2db(pxx));
    pband = bandpower(pxx,f,[f1 f2],'psd');
    ptot = bandpower(pxx,f,'psd');
    per_power = 100*(pband/ptot);


    %     e_total = 0;
    %     for j = 1:6
    %         e_total = e_total + norm(d1(:,j))^2;
    %     end
    %
    %     % 相对功率谱比值计算
    %
    %     per_power = norm(d1(:,index))^2/e_total*100;

    k = k + 1;
    start_index = start_index + win_length;
    end_index = (start_index+win_length)*Fs;
    energy_r(k) = per_power;
    energy_m(k) = mean(pow2db(pxx(index)));

end
% end
pxx = PWR./k;
end