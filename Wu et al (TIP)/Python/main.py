import numpy as np
import cv2
from scipy.ndimage import convolve, gaussian_filter
import matplotlib.pyplot as plt

def mat2gray(img):
    """Normalize image to [0, 1] ."""
    img = np.array(img, dtype=np.float64)
    min_val = np.min(img)
    max_val = np.max(img)
    if max_val == min_val:
        return np.zeros_like(img)
    return (img - min_val) / (max_val - min_val)

def func_randnum(rows, cols):
    """Create a matrix with values 1 or -1."""
    mask = np.random.rand(rows, cols)
    randmat = np.zeros((rows, cols), dtype=np.float64)
    randmat[mask >= 0.5] = 1
    randmat[mask < 0.5] = -1
    return randmat

def func_edge_height(img):
    """Calculate edge height using gradient filters."""
    G1 = np.array([[0, 0, 0, 0, 0],
                   [1, 3, 8, 3, 1],
                   [0, 0, 0, 0, 0],
                   [-1, -3, -8, -3, -1],
                   [0, 0, 0, 0, 0]], dtype=np.float64)

    G2 = np.array([[0, 0, 1, 0, 0],
                   [0, 8, 3, 0, 0],
                   [1, 3, 0, -3, -1],
                   [0, 0, -3, -8, 0],
                   [0, 0, -1, 0, 0]], dtype=np.float64)

    G3 = np.array([[0, 0, 1, 0, 0],
                   [0, 0, 3, 8, 0],
                   [-1, -3, 0, 3, 1],
                   [0, -8, -3, 0, 0],
                   [0, 0, -1, 0, 0]], dtype=np.float64)

    G4 = np.array([[0, 1, 0, -1, 0],
                   [0, 3, 0, -3, 0],
                   [0, 8, 0, -8, 0],
                   [0, 3, 0, -3, 0],
                   [0, 1, 0, -1, 0]], dtype=np.float64)

    grad = np.zeros((img.shape[0], img.shape[1], 4), dtype=np.float64)
    grad[:, :, 0] = convolve(img, G1, mode='reflect') / 16
    grad[:, :, 1] = convolve(img, G2, mode='reflect') / 16
    grad[:, :, 2] = convolve(img, G3, mode='reflect') / 16
    grad[:, :, 3] = convolve(img, G4, mode='reflect') / 16

    max_grad = np.max(np.abs(grad), axis=2)
    max_grad = max_grad[2:-2, 2:-2]
    edge_height = np.pad(max_grad, [(2, 2), (2, 2)], mode='symmetric')
    return edge_height

def func_edge_protect(img):
    """Protect edge regions using Canny edge detection and dilation."""
    img = np.array(img, dtype=np.float64)
    edge_h = 60
    edge_height = func_edge_height(img)
    max_val = np.max(edge_height)
    print(f"Max edge height: {max_val}")
    edge_threshold = edge_h / max_val
    if edge_threshold > 0.8:
        edge_threshold = 0.8

    img_uint8 = np.clip(img * 255, 0, 255).astype(np.uint8)
    edge_region = cv2.Canny(img_uint8, int(edge_threshold * 255), int(0.4 * edge_threshold * 255)) / 255.0
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    img_edge = cv2.dilate(edge_region, kernel)
    img_supedge = 1 - img_edge
    gaussian_kernel = cv2.getGaussianKernel(5, 0.8)
    gaussian_kernel = gaussian_kernel @ gaussian_kernel.T
    edge_protect = cv2.filter2D(img_supedge, -1, gaussian_kernel, borderType=cv2.BORDER_REFLECT)
    return edge_protect

def func_cmlx_num_compute(img):
    """Compute complexity number based on orientation selectivity."""
    r = 1
    nb = r * 8
    otr = 6
    kx = np.array([[-1, 0, 1], [-1, 0, 1], [-1, 0, 1]], dtype=np.float64) / 3
    ky = kx.T

    # Angle step (coordinate)
    sps = np.zeros((nb, 2))
    as_ = 2 * np.pi / nb
    for i in range(nb):
        sps[i, 0] = -r * np.sin(i * as_)
        sps[i, 1] = r * np.cos(i * as_)

    # OSVP computation
    imgd = np.pad(img, ((r, r), (r, r)), mode='symmetric')
    Gx = convolve(imgd, kx, mode='constant')
    Gy = convolve(imgd, ky, mode='constant')
    Cimg = np.sqrt(Gx**2 + Gy**2)
    Cvimg = np.zeros_like(Cimg)
    Cvimg[Cimg >= 5] = 1
    Oimg = np.round(np.arctan2(Gy, Gx) / np.pi * 180)
    Oimg[Oimg > 90] = Oimg[Oimg > 90] - 180
    Oimg[Oimg < -90] = 180 + Oimg[Oimg < -90]
    Oimg = Oimg + 90
    Oimg[Cvimg == 0] = 180 + 2 * otr
    Oimgc = Oimg[r:-r, r:-r]
    Cvimgc = Cvimg[r:-r, r:-r]

    Oimg_norm = np.round(Oimg / (2 * otr))
    Oimgc_norm = np.round(Oimgc / (2 * otr))
    onum = int(np.round(180 / (2 * otr))) + 1

    ssr_val = np.zeros((Oimgc.shape[0], Oimgc.shape[1], onum + 1))
    for x in range(onum + 1):
        Oimgc_valid = (Oimgc_norm == x)
        ssr_val[:, :, x] += Oimgc_valid

    for i in range(nb):
        dx = int(np.round(r + sps[i, 0]))
        dy = int(np.round(r + sps[i, 1]))
        Oimgn = Oimg_norm[dx:dx+Oimgc.shape[0], dy:dy+Oimgc.shape[1]]
        for x in range(onum + 1):
            Oimg_valid = (Oimgn == x)
            ssr_val[:, :, x] += Oimg_valid

    ssr_no_zero = (ssr_val != 0)
    cmlx = np.sum(ssr_no_zero, axis=2)
    cmlx[Cvimgc == 0] = 1
    cmlx[:r, :] = 1
    cmlx[-r:, :] = 1
    cmlx[:, :r] = 1
    cmlx[:, -r:] = 1
    return cmlx

def func_ori_cmlx_compute(img):
    """Compute orientation complexity with Gaussian smoothing."""
    cmlx_map = func_cmlx_num_compute(img)
    r = 3
    sig = 1
    cmlx_mat = gaussian_filter(cmlx_map, sigma=sig, radius=r, mode='reflect')
    return cmlx_mat

def func_luminance_contrast(img):
    """Calculate luminance contrast (variance)."""
    R = 2
    ker = np.ones((2*R+1, 2*R+1)) / (2*R+1)**2
    mean_mask = convolve(img, ker, mode='reflect')
    mean_img_sqr = mean_mask**2
    img_sqr = img**2
    mean_sqr_img = convolve(img_sqr, ker, mode='reflect')
    var_mask = mean_sqr_img - mean_img_sqr
    var_mask[var_mask < 0] = 0
    valid_mask = np.zeros_like(img)
    valid_mask[R:-R, R:-R] = 1
    var_mask = var_mask * valid_mask
    L_c = np.sqrt(var_mask)
    return L_c

def lum_jnd():
    """Calculate JND threshold due to background luminance."""
    bg_jnd = np.zeros(256)
    T0 = 17
    gamma = 3 / 128
    for k in range(256):
        lum = k
        if lum <= 127:
            bg_jnd[k] = T0 * (1 - np.sqrt(lum / 127)) + 3
        else:
            bg_jnd[k] = gamma * (lum - 127) + 3
    return bg_jnd

def func_bg_adjust(bg_lum0, min_lum):
    """Adjust luminance in dark regions."""
    bg_lum = bg_lum0.copy()
    bg_lum[bg_lum <= 127] = np.round(min_lum + bg_lum[bg_lum <= 127] * (127 - min_lum) / 127)
    return bg_lum

def func_bg_lum_jnd(img0):
    """Calculate JND threshold due to luminance adaptation."""
    min_lum = 32
    alpha = 0.7
    B = np.array([[1, 1, 1, 1, 1],
                  [1, 2, 2, 2, 1],
                  [1, 2, 0, 2, 1],
                  [1, 2, 2, 2, 1],
                  [1, 1, 1, 1, 1]], dtype=np.float64) / 32

    bg_lum0 = np.floor(convolve(img0, B, mode='reflect'))
    bg_lum = func_bg_adjust(bg_lum0, min_lum)
    bg_jnd = lum_jnd()
    rows, cols = img0.shape
    jnd_lum = np.zeros((rows, cols))
    for x in range(rows):
        for y in range(cols):
            jnd_lum[x, y] = bg_jnd[int(bg_lum[x, y])]
    jnd_lum_adapt = alpha * jnd_lum
    return jnd_lum_adapt

def func_JND_modeling_pattern_complexity(img):
    """Pattern Complexity based JND modeling."""
    if img.dtype != np.float64:
        img = img.astype(np.float64)

    # Luminance adaptation
    jnd_LA = func_bg_lum_jnd(img)

    # Luminance contrast masking
    L_c = func_luminance_contrast(img)
    a1 = 0.115 * 16
    a2 = 26
    jnd_LC = (a1 * L_c**2.4) / (L_c**2 + a2**2)

    # Content complexity
    P_c = func_ori_cmlx_compute(img)
    a3 = 0.3
    a4 = 2.7
    a5 = 1
    C_t = (a3 * P_c**a4) / (P_c**2 + a5**2)

    # Pattern masking
    jnd_PM = L_c * C_t
    edge_protect = func_edge_protect(img)
    jnd_PM_p = jnd_PM * edge_protect

    # Visual masking
    jnd_VM = np.maximum(jnd_LC, jnd_PM_p)

    # JND map
    jnd_map = jnd_LA + jnd_VM - 0.3 * np.minimum(jnd_LA, jnd_VM)

    # Inject noise into image with JND guidance
    rows, cols = img.shape
    randmat = func_randnum(rows, cols)
    adjuster = 0.7
    img_jnd = img + adjuster * randmat * jnd_map
    img_jnd = np.clip(img_jnd, 0, 255).astype(np.uint8)
    mse_val = np.mean((img_jnd.astype(np.float64) - img)**2)
    print(f'MSE = {mse_val:.3f}')

    return img_jnd, jnd_map, jnd_LA, jnd_VM, P_c

def main():
    # Load image
    img = cv2.imread('lena.png', cv2.IMREAD_GRAYSCALE)
    # Process image
    img_jnd, jnd_map, jnd_LA, jnd_VM, complexity_map = func_JND_modeling_pattern_complexity(img)


    # Display results
    plt.figure(figsize=(15, 10))
    plt.subplot(231), plt.imshow(img, cmap='gray'), plt.title('Original Image')
    plt.subplot(232), plt.imshow(mat2gray(jnd_LA), cmap='gray'), plt.title('Luminance Adaption')
    plt.subplot(233), plt.imshow(mat2gray(complexity_map), cmap='gray'), plt.title('Complexity Map')
    plt.subplot(234), plt.imshow(mat2gray(jnd_VM), cmap='gray'), plt.title('Visual Masking')
    plt.subplot(235), plt.imshow(img_jnd, cmap='gray'), plt.title('JND Image')
    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()