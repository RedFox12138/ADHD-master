import numpy as np
import time
from scipy.spatial.distance import cdist


# =============================================================================
# 1. 原始的 SampEn 函数 (Original SampEn Function)
# =============================================================================
def SampEn(Sig, m=2, tau=1, r=None, Logx=np.exp(1), Vcp=False):
    """ Original Sample Entropy function provided by the user."""
    Sig = np.squeeze(Sig)
    N = Sig.shape[0]
    if r is None:
        r = 0.2 * np.std(Sig)

    assert N > 10 and Sig.ndim == 1, "Sig:   must be a numpy vector"
    assert isinstance(m, int) and (m > 0), "m:     must be an integer > 0"
    assert isinstance(tau, int) and (tau > 0), "tau:   must be an integer > 0"
    assert isinstance(r, (int, float)) and (r >= 0), "r:     must be a positive value"
    assert isinstance(Logx, (int, float)) and (Logx > 0), "Logx:     must be a positive value"
    assert isinstance(Vcp, bool), "Vcp:     must be a Boolean"

    Counter = (abs(np.expand_dims(Sig, axis=1) - np.expand_dims(Sig, axis=0)) <= r) * np.triu(np.ones((N, N)), 1)
    M = np.hstack((m * np.ones(N - m * tau), np.repeat(np.arange(m - 1, 0, -1), tau)))
    A = np.zeros(m + 1)
    B = np.zeros(m + 1)
    A[0] = np.sum(Counter)
    B[0] = N * (N - 1) / 2

    for n in range(M.shape[0]):
        ix = np.where(Counter[n, :] == 1)[0]

        for k in range(1, int(M[n] + 1)):
            ix = ix[ix + (k * tau) < N]
            p1 = np.tile(Sig[n: n + 1 + (tau * k):tau], (ix.shape[0], 1))
            p2 = Sig[np.expand_dims(ix, axis=1) + np.arange(0, (k * tau) + 1, tau)]
            ix = ix[np.amax(abs(p1 - p2), axis=1) <= r]
            if ix.shape[0]:
                Counter[n, ix] += 1
            else:
                break

    for k in range(1, m + 1):
        A[k] = np.sum(Counter > k)
        B[k] = np.sum(Counter[:, :-(k * tau)] >= k)

    with np.errstate(divide='ignore', invalid='ignore'):
        Samp = -np.log(A / B) / np.log(Logx)

    return Samp, A, B


# =============================================================================
# 2. 优化后的 SampEn 函数 (Optimized SampEn Function)
# =============================================================================
def SampEn_optimized(Sig, m=2, tau=1, r=None, Logx=np.exp(1), Vcp=False):
    """ Vectorized, computationally efficient version of the SampEn function."""
    if Vcp:
        raise NotImplementedError("The Vcp calculation is not implemented in this optimized version.")

    Sig = np.squeeze(Sig)
    N = Sig.shape[0]

    if r is None:
        r = 0.2 * np.std(Sig)

    assert N > 10 and Sig.ndim == 1, "Sig:   must be a numpy vector"
    assert isinstance(m, int) and (m > 0), "m:     must be an integer > 0"
    assert isinstance(tau, int) and (tau > 0), "tau:   must be an integer > 0"
    assert isinstance(r, (int, float)) and (r >= 0), "r:     must be a positive value"
    assert isinstance(Logx, (int, float)) and (Logx > 0), "Logx:     must be a positive value"

    Samp = np.zeros(m + 1)
    A = np.zeros(m + 1)
    B = np.zeros(m + 1)

    n_templates = N - m * tau
    indices = np.arange(m + 1) * tau + np.arange(n_templates)[:, np.newaxis]
    templates = Sig[indices]

    B[0] = (N * (N - 1)) / 2
    scalar_dists = cdist(Sig.reshape(-1, 1), Sig.reshape(-1, 1), 'chebyshev')
    A[0] = (np.sum(scalar_dists <= r) - N) / 2

    for k in range(1, m + 1):
        templates_k = templates[:, :k]
        dist_k = cdist(templates_k, templates_k, 'chebyshev')
        B[k] = (np.sum(dist_k <= r) - n_templates) / 2

        templates_k1 = templates[:, :k + 1]
        dist_k1 = cdist(templates_k1, templates_k1, 'chebyshev')
        A[k] = (np.sum(dist_k1 <= r) - n_templates) / 2

    with np.errstate(divide='ignore', invalid='ignore'):
        Samp = -np.log(A / B) / np.log(Logx)

    return Samp, A, B


# =============================================================================
# 3. 临时 Main 函数用于对比 (Main function for comparison)
# =============================================================================
def main():
    """
    Main function to compare the original and optimized SampEn implementations.
    """
    print("正在设置测试参数...")
    # --- 测试参数 ---
    N = 1500  # 信号长度 (较大以突显性能差异)
    m = 2  # 嵌入维度
    tau = 1  # 时间延迟

    # 生成随机信号
    np.random.seed(42)  # 使用固定的随机种子以保证每次结果可复现
    signal = np.random.rand(N) * 10

    # 预先计算半径 r，确保两个函数使用完全相同的值
    r = 0.2 * np.std(signal)

    print(f"测试信号长度 N = {N}, 嵌入维度 m = {m}, 半径 r = {r:.4f}\n")

    # --- 运行并计时原始函数 ---
    print("--- 1. 测试原始 SampEn 函数 ---")
    start_time_orig = time.time()
    samp_orig, A_orig, B_orig = SampEn(signal, m=m, tau=tau, r=r)
    end_time_orig = time.time()
    duration_orig = end_time_orig - start_time_orig

    print(f"耗时: {duration_orig:.4f} 秒")
    print("计算结果:")
    print(f"  Samp = {np.round(samp_orig, 6)}")
    print(f"  A = {A_orig}")
    print(f"  B = {B_orig}")
    print("-" * 30)

    # --- 运行并计时优化函数 ---
    print("\n--- 2. 测试优化后的 SampEn_optimized 函数 ---")
    start_time_opt = time.time()
    samp_opt, A_opt, B_opt = SampEn_optimized(signal, m=m, tau=tau, r=r)
    end_time_opt = time.time()
    duration_opt = end_time_opt - start_time_opt

    print(f"耗时: {duration_opt:.4f} 秒")
    print("计算结果:")
    print(f"  Samp = {np.round(samp_opt, 6)}")
    print(f"  A = {A_opt}")
    print(f"  B = {B_opt}")
    print("-" * 30)

    # --- 结果总结与对比 ---
    print("\n--- 3. 对比总结 ---")
    if duration_opt > 0:
        speedup = duration_orig / duration_opt
        print(f"✅ 性能: 优化后的版本比原始版本快了 {speedup:.2f} 倍。")
    else:
        print("✅ 性能: 优化后的版本计算速度极快。")

    # 检查结果是否一致 (使用 np.allclose 处理浮点数精度问题)
    samp_consistent = np.allclose(samp_orig, samp_opt, equal_nan=True)
    A_consistent = np.array_equal(A_orig, A_opt)
    B_consistent = np.array_equal(B_orig, B_opt)

    if samp_consistent and A_consistent and B_consistent:
        print("✅ 结果一致性: Samp, A, B 的计算结果完全一致。")
    else:
        print("⚠️ 结果一致性: 计算结果存在差异，请检查。")
        print(f"   - Samp 一致: {samp_consistent}")
        print(f"   - A 一致: {A_consistent}")
        print(f"   - B 一致: {B_consistent}")


if __name__ == "__main__":
    main()