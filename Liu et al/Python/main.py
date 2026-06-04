import numpy as np
import cv2
from scipy.ndimage import convolve
import matplotlib.pyplot as plt
import os

def jnd_id(I, lambda_=0.8):
    """
    JND model with image decomposition using Gaussian blur.
    """
    I = I.astype(np.float64)
    H, W = I.shape

    # Calculating background luminance
    bg = func_bg(I)
    print("Background luminance calculated")

    # Calculating JNDl: luminance adaptation
    T0 = 17
    GAMMA = 3 / 128
    JNDl = GAMMA * (bg - 127) + 3
    JNDl[bg <= 127] = T0 * (1 - np.sqrt(bg[bg <= 127] / 127)) + 3
    print("JNDl calculated")

    # Image decomposition using Gaussian blur
    sigma = lambda_  # Adjust sigma based on lambda
    I_s = cv2.GaussianBlur(I, (7, 7), sigma)
    I_t = I - I_s
    print("Image decomposition completed")

    # Calculating contrast
    Gm_e = func_Gm(I_s)  # contrast for edge
    Gm_t = func_Gm(I_t)  # contrast for texture
    print("Contrast calculated")

    # Calculating JNDt: texture/edge masking
    LANDA = 1 / 2
    alpha = 0.0001 * bg + 0.115
    belta = LANDA - 0.01 * bg
    JNDt_e = np.minimum(np.maximum(Gm_e * alpha + belta, 0), 10)
    JNDt_t = np.minimum(np.maximum(Gm_t * alpha + belta, 0), 10)
    We, Wt = 0.7, 1.4
    JNDt = We * JNDt_e + Wt * JNDt_t
    print("JNDt calculated")

    # Overall JND value
    C_TG = 0.3
    JND = JNDl + JNDt - C_TG * np.minimum(JNDl, JNDt)
    print("JND map calculated")

    return JND

def func_bg(input):
    Mask = np.array([
        [1, 1, 1, 1, 1],
        [1, 2, 2, 2, 1],
        [1, 2, 0, 2, 1],
        [1, 2, 2, 2, 1],
        [1, 1, 1, 1, 1]
    ])
    output = convolve(input, Mask / 32, mode='mirror')
    return output

def func_Gm(input):
    G1 = np.array([
        [0, 0, 0, 0, 0],
        [1, 3, 8, 3, 1],
        [0, 0, 0, 0, 0],
        [-1, -3, -8, -3, -1],
        [0, 0, 0, 0, 0]
    ])
    G2 = np.array([
        [0, 0, 1, 0, 0],
        [0, 8, 3, 0, 0],
        [1, 3, 0, -3, -1],
        [0, 0, -3, -8, 0],
        [0, 0, -1, 0, 0]
    ])
    G3 = np.array([
        [0, 0, 1, 0, 0],
        [0, 0, 3, 8, 0],
        [-1, -3, 0, 3, 1],
        [0, -8, -3, 0, 0],
        [0, 0, -1, 0, 0]
    ])
    G4 = np.array([
        [0, 1, 0, -1, 0],
        [0, 3, 0, -3, 0],
        [0, 8, 0, -8, 0],
        [0, 3, 0, -3, 0],
        [0, 1, 0, -1, 0]
    ])

    H, W = input.shape
    grad = np.zeros((H, W, 4))
    grad[:, :, 0] = convolve(input, G1 / 16, mode='mirror')
    grad[:, :, 1] = convolve(input, G2 / 16, mode='mirror')
    grad[:, :, 2] = convolve(input, G3 / 16, mode='mirror')
    grad[:, :, 3] = convolve(input, G4 / 16, mode='mirror')
    Gm = np.max(np.abs(grad), axis=2)
    return Gm

# 主程序
try:
    # 读取灰度图像
    distImg = cv2.imread('D:\\OpenJND\\lena.bmp', cv2.IMREAD_GRAYSCALE)
    if distImg is None:
        raise RuntimeError("无法加载 'F:\\OpenJND\\lena.bmp'，请确认文件存在")

    # 调试：打印输入图像尺寸
    print(f"Input size: [{distImg.shape[0]}, {distImg.shape[1]}]")

    # 计算 JND
    JND = jnd_id(distImg, lambda_=0.8)
    print(f"JND Matrix Shape: [{JND.shape[0]}, {JND.shape[1]}]")
    jnd_img = JND

    # 使用 Matplotlib 显示 JND 图像
    plt.figure()
    plt.imshow(jnd_img, cmap='gray')
    plt.axis('off')
    plt.show()

except Exception as e:
    print(f"发生错误: {str(e)}")