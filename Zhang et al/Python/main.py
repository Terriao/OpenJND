"""
Xiaohui Zhang, Weisi Lin and Ping Xue, "Improved Estimation for Just-noticeable Visual Distortion",
Signal Processing, Vol. 85(4), pp.795-808, April 2005.。
"""
import numpy as np
from scipy.fftpack import dct, idct
import imageio.v2 as imageio
import matplotlib.pyplot as plt
from matplotlib import font_manager


def dctmtx(n):
    """
    生成 n x n 的 DCT-II 变换矩阵
    """
    C = np.zeros((n, n))
    for i in range(n):
        for j in range(n):
            if i == 0:
                C[i, j] = 1 / np.sqrt(n)
            else:
                C[i, j] = np.sqrt(2 / n) * np.cos(np.pi * i * (2 * j + 1) / (2 * n))
    return C


def JND_dct(distImg):

    # 将输入图像转换为浮点型
    Lum = distImg.astype(np.float64)
    M = 256  # 假设8位图像
    row, col = Lum.shape
    # 裁剪图像尺寸为8的倍数
    Lum = Lum[:row // 8 * 8, :col // 8 * 8]
    row, col = Lum.shape
    tfac = 0.3  # JND调整因子

    # 假设最大和最小亮度值
    Lmax = 130
    Lmin = 0

    # DCT变换（8x8块）
    Tr = dctmtx(8)  # 8x8 DCT矩阵
    C = np.zeros_like(Lum)
    for i in range(0, row, 8):
        for j in range(0, col, 8):
            C[i:i + 8, j:j + 8] = Tr @ Lum[i:i + 8, j:j + 8] @ Tr.T

    # 亮度-DCT系数转换
    L = np.zeros_like(C)
    for i in range(0, row, 8):
        for j in range(0, col, 8):
            L[i:i + 8, j:j + 8] = Lmin + (Lmax - Lmin) / M * (C[i:i + 8, j:j + 8][0, 0] / 8)

    # 8x8块的数量
    row1, col1 = row // 8, col // 8

    # CSF计算参数
    wx = 0.0298  # 水平像素宽度
    wy = 0.0298  # 垂直像素宽度
    r = 0.6
    LT = 13.45
    S0 = 94.7
    aT = 0.649
    aL = 0.500
    f0 = 6.78
    af = 0.182
    Lf = 300
    K0 = 3.125
    aK = 0.0706
    LK = 300
    L0 = 65
    s = 0.25
    LB = 65  # 假设灰度值128对应65 cd/m^2
    C00 = 1024

    # Ahumada-Peterson CSF方程
    if LB <= LK:
        K = K0 * ((LB / LK) ** aK)
    else:
        K = K0
    if LB <= Lf:
        fmin = f0 * ((LB / Lf) ** af)
    else:
        fmin = f0
    if LB <= LT:
        Tmin = LT / S0 * ((LB / LT) ** aT)
    else:
        Tmin = LB / S0

    # 频率和角度计算
    freq = np.zeros((8, 8))
    sinang = np.zeros((8, 8))
    for i in range(8):
        for j in range(8):
            freq[i, j] = np.sqrt(((i) ** 2 / wx ** 2 + (j) ** 2 / wy ** 2)) / 16
            if freq[i, j] == 0:
                sinang[0, 0] = 0
            elif i == j:
                sinang[i, j] = 1.0
            else:
                sinang[i, j] = 2 * freq[i, 0] * freq[0, j] / (freq[i, j] ** 2)

    ang = np.zeros((8, 8))
    g = np.zeros((8, 8))
    T = np.zeros((8, 8))
    for i in range(8):
        for j in range(8):
            f = freq.copy()
            f[0, 0] = freq[0, 1]
            ang[i, j] = np.arcsin(sinang[i, j])
            f1 = (np.log10(f[i, j]) - np.log10(fmin)) ** 2
            g[i, j] = np.log10(s * Tmin / (r + (1 - r) * (np.cos(ang[i, j]) ** 2))) + K * f1
            T[i, j] = 10 ** g[i, j]

    tij = np.zeros((8, 8))
    for i in range(8):
        for j in range(8):
            ai = np.sqrt(1 / 8) if i == 0 else np.sqrt(2 / 8)
            aj = np.sqrt(1 / 8) if j == 0 else np.sqrt(2 / 8)
            tij[i, j] = M * T[i, j] / (Lmax - Lmin) / ai / aj

    # 调整DC的JND
    tij[0, 0] = min(tij[0, 1], tij[1, 0])

    # 将DCT系数重新组织为块
    C1 = np.zeros((row1, col1, 8, 8))
    for i in range(row):
        for j in range(col):
            n1, n2 = i // 8, j // 8
            C1[n1, n2, i % 8, j % 8] = C[i, j]

    # 亮度适配：准抛物线函数
    aT, kT, aM, kQ, aQ = 3, 2, 0.649, 0.8, 2
    tDCT = np.zeros((row1, col1, 8, 8))
    aLum = np.zeros((row1, col1))
    for n1 in range(row1):
        for n2 in range(col1):
            for i in range(8):
                for j in range(8):
                    if C1[n1, n2, 0, 0] > C00:
                        tDCT[n1, n2, i, j] = tij[i, j] * (kQ * (C1[n1, n2, 0, 0] / C00 - 1) ** aQ + 1)
                        aLum[n1, n2] = kQ * (C1[n1, n2, 0, 0] / C00 - 1) ** aQ + 1
                    else:
                        tDCT[n1, n2, i, j] = tij[i, j] * (kT * (1 - C1[n1, n2, 0, 0] / C00) ** aT + 1)
                        aLum[n1, n2] = kT * (1 - C1[n1, n2, 0, 0] / C00) ** aT + 1

    # 块分类
    block = np.zeros((row1, col1), dtype=str)
    edg = np.zeros((row1, col1))
    lowf = np.zeros((row1, col1))
    highf = np.zeros((row1, col1))
    TexMask = np.zeros((row1, col1))
    for n1 in range(row1):
        for n2 in range(col1):
            # 纹理掩蔽模型参数
            u1, u2 = 125, 900
            a1, b1 = 2.3 * 3, 1.6 * 3
            a2, b2 = 1, 1.6
            y1, y = 2.0, 4 * 4
            k1 = 290

            # 边缘、低频、高频能量
            edg[n1, n2] = (np.sum(np.abs(C1[n1, n2, 3:7, 0])) +
                           np.sum(np.abs(C1[n1, n2, 0, 3:7])) +
                           np.sum(np.abs(C1[n1, n2, 2, 1:3])) +
                           np.abs(C1[n1, n2, 1, 2]) +
                           np.abs(C1[n1, n2, 3, 3]))
            lowf[n1, n2] = (np.sum(np.abs(C1[n1, n2, 1:3, 0])) +
                            np.sum(np.abs(C1[n1, n2, 0, 1:3])) +
                            np.abs(C1[n1, n2, 1, 1]))
            highf[n1, n2] = np.sum(np.abs(C1[n1, n2, :, :])) - edg[n1, n2] - lowf[n1, n2] - C1[n1, n2, 0, 0]

            edgn = edg[n1, n2] / 12
            lowfn = lowf[n1, n2] / 5
            highfn = highf[n1, n2] / 46

            # 块分类
            if edg[n1, n2] + highf[n1, n2] < u1:
                block[n1, n2] = 'p'
            elif edg[n1, n2] + highf[n1, n2] > u2:
                if ((lowfn / edgn >= a2) and ((lowfn + edgn) / highfn >= b2)) or \
                        ((lowfn / edgn >= b2) and ((lowfn + edgn) / highfn >= a2)) or \
                        ((lowfn + edgn) / highfn >= y1):
                    block[n1, n2] = 'e'
                else:
                    block[n1, n2] = 't'
            elif ((lowfn / edgn >= a1) and ((lowfn + edgn) / highfn >= b1)) or \
                    ((lowfn / edgn >= b1) and ((lowfn + edgn) / highfn >= a1)) or \
                    ((lowfn + edgn) / highfn >= y):
                block[n1, n2] = 'e'
            elif edg[n1, n2] + highf[n1, n2] > k1:
                block[n1, n2] = 't'
            else:
                block[n1, n2] = 'p'

            # 纹理掩蔽
            max1, min1 = 1800, 290
            if block[n1, n2] == 't':  # 纹理块
                TexE = edg[n1, n2] + highf[n1, n2]
                FmaxT = 2.5
                TexMask[n1, n2] = (FmaxT - 1) * (TexE - min1) / (max1 - min1) + 1
            elif block[n1, n2] == 'e':  # 边缘块
                EdgE = edg[n1, n2] + lowf[n1, n2]
                TexMask[n1, n2] = 1.125 if EdgE <= 400 else 1.25
            elif block[n1, n2] == 'p':  # 平坦块
                TexMask[n1, n2] = 1

    # 纹理掩蔽提升
    aCM = np.zeros((row1, col1, 8, 8))
    tJND = np.zeros((row1, col1, 8, 8))
    for n1 in range(row1):
        for n2 in range(col1):
            for i in range(8):
                for j in range(8):
                    if i + j == 0:
                        aCM[n1, n2, 0, 0] = 1  # DC的掩蔽提升因子
                    else:
                        aCM[n1, n2, i, j] = max(1, (np.abs(C1[n1, n2, i, j] / tDCT[n1, n2, i, j])) ** 0.36) * TexMask[
                            n1, n2]
                    if block[n1, n2] == 'e':
                        aCM[n1, n2, 1:7, 0] = TexMask[n1, n2]
                        aCM[n1, n2, 0, 1:7] = TexMask[n1, n2]
                        aCM[n1, n2, 1, 1:3] = TexMask[n1, n2]
                        aCM[n1, n2, 2, 1:3] = TexMask[n1, n2]
                        aCM[n1, n2, 3, 3] = TexMask[n1, n2]
                    tJND[n1, n2, i, j] = tDCT[n1, n2, i, j] * aCM[n1, n2, i, j]

    # 最终JND映射
    JND = np.zeros((row, col))
    for i in range(row):
        for j in range(col):
            n1, n2 = i // 8, j // 8
            JND[i, j] = tJND[n1, n2, i % 8, j % 8] * tfac

    return JND


if __name__ == "__main__":
    try:
        distImg = imageio.imread('lena.bmp', mode='L')
        JND = JND_dct(distImg)
        print("JND Matrix Shape：", JND.shape)

        # 可视化 JND 矩阵
        plt.figure(figsize=(8, 6))
        plt.imshow(JND, cmap='gray')
        plt.colorbar(label='JND Value')
        plt.title('JND Visualization')
        plt.savefig('jnd_output.png', bbox_inches='tight')
        plt.show()

    except FileNotFoundError:
        print("Error: the input image is not found.")
    except Exception as e:
        print(f"Error：{e}")