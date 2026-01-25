import scipy.io
import os

folder = r'd:\Pycharm_Projects\ADHD-master\毕设画图\绘制真实的眼动伪影'
files = ['Brain_1.mat', 'EyeMove_1.mat', 'Wink_1.mat']

for f in files:
    path = os.path.join(folder, f)
    try:
        mat = scipy.io.loadmat(path)
        print(f"File: {f}")
        for k, v in mat.items():
            if not k.startswith('__'):
                print(f"  Key: {k}, Shape: {v.shape}")
    except Exception as e:
        print(f"Error loading {f}: {e}")
