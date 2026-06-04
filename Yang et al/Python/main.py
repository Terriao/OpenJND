import numpy as np
import cv2
from scipy.ndimage import convolve
import matplotlib.pyplot as plt
import os

def jnd_pixel(I, type_='Yang'):
    """
    Pixel-based JND (Just-Noticeable Difference) model.
    """
    I = I.astype(np.float64)
    H, W = I.shape

    JNDl = np.zeros((H, W))  # Luminance component
    JNDt = np.zeros((H, W))  # Texture component
    T = np.zeros((H, W, 2))  # Temp matrix
    bg = func_bg(I)  # Average background luminance
    Gm = func_Gm(I, type_)  # Maximal weighted average of gradients

    # Calculating JNDl
    T0 = 17
    GAMMA = 3 / 128
    for i in range(H):
        for j in range(W):
            if bg[i, j] <= 127:
                JNDl[i, j] = T0 * (1 - np.sqrt(bg[i, j] / 127)) + 3
            else:
                JNDl[i, j] = GAMMA * (bg[i, j] - 127) + 3

    # Calculating JNDt
    LANDA = 1 / 2
    alpha = 0.0001 * bg + 0.115
    belta = LANDA - 0.01 * bg
    JNDt = Gm * alpha + belta

    # Calculating final JND
    T[:, :, 0] = JNDl
    T[:, :, 1] = JNDt
    C_TG = 0.3
    JND = np.sum(T, axis=2) - C_TG * np.min(T, axis=2)

    return JND

def func_bg(input):
    """
    Compute average background luminance.
    """
    Mask = np.array([
        [1, 1, 1, 1, 1],
        [1, 2, 2, 2, 1],
        [1, 2, 0, 2, 1],
        [1, 2, 2, 2, 1],
        [1, 1, 1, 1, 1]
    ])
    output = convolve(input, Mask / 32, mode='mirror')
    return output

def func_Gm(input, type_):
    """
    Compute maximal weighted average of gradients.
    """
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

    edge_threshold = 0.3  # 降低阈值以增强边缘
    # Canny 边缘检测
    img_edge = cv2.Canny(input.astype(np.uint8), edge_threshold * 255 / 3, edge_threshold * 255)
    img_edge = img_edge / 255.0  # 归一化到 [0, 1]
    # 形态学膨胀
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (6, 6))
    img_edge = cv2.dilate(img_edge, kernel)
    img_supedge = 1 - 0.95 * img_edge
    # 高斯滤波
    gaussian_kernel = cv2.getGaussianKernel(7, 0.5)  
    gaussian_kernel = gaussian_kernel @ gaussian_kernel.T
    img_supedge = convolve(img_supedge, gaussian_kernel, mode='mirror')

    if type_ == 'Chou':
        output = Gm
    else:  # Yang
        output = Gm * img_supedge

    return output

# 主程序
try:
    # 读取灰度图像
    distImg = cv2.imread('D:\\OpenJND\\lena.bmp', cv2.IMREAD_GRAYSCALE)

    # 调试：打印输入图像尺寸
    print(f"Input size: [{distImg.shape[0]}, {distImg.shape[1]}]")

    # 计算 JND
    JND = jnd_pixel(distImg, 'Yang')
    print(f"JND Matrix Shape: [{JND.shape[0]}, {JND.shape[1]}]")

    # 使用 Matplotlib 显示 JND 图像
    plt.figure()
    plt.imshow(JND, cmap='gray')
    plt.axis('off')
    plt.show()

except Exception as e:
    print(f"Error: {str(e)}")