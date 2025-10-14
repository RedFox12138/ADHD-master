all_data = load('Preprocessed\0819\0819 XY实验1_preprocessed.mat').eeg_data;
data = all_data(1,:);
Fs=250;
plot(data);
[~,d1_denoised] = EEGPreprocess(data, Fs, 'none');
hold on;
plot(d1_denoised);