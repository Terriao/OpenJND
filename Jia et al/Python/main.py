import numpy as np
from scipy.fft import dct, idct
import cv2

def dctmtx(n):
    """Generate an n x n DCT-II matrix."""
    x = np.arange(n)
    C = np.sqrt(2/n) * np.cos(np.pi * (2*x + 1)[:, None] * x / (2*n))
    C[0, :] = 1 / np.sqrt(n)
    return C

def JND_video(Y1, Y2):
    """
    Calculate the spatiotemporal JND based on two frames.
    Y1, Y2: Input frames (numpy arrays, grayscale).
    Returns: JND matrix.
    """
    # Placeholder for motion vector calculation
    # Replace with actual motionvector(Y1, Y2) if available
    MV = np.zeros((Y1.shape[0]//8, Y1.shape[1]//8, 2))

    XSize, YSize = Y1.shape
    n = 1  # Frame interval
    wx = 0.0342
    wy = 0.0342
    fps = 30
    ppd = int(np.ceil(1/wx))  # Pixels per degree
    s = 0.92  # Gain of smooth pursuit eye movement
    v_min = 0.15  # Minimum eye velocity (deg/sec)
    v_max = 80  # Maximum eye velocity (deg/sec)
    c0 = 1.14
    c1 = 0.67
    c2 = 1.7
    c3 = 1.186
    c4 = 3.677
    bsize = 8
    epsilon = 1e-6  # Small value to avoid division by zero

    # Calculate spatial frequencies
    freq = np.zeros((bsize, bsize))
    for i in range(bsize):
        for j in range(bsize):
            freq[i, j] = np.sqrt(((i)**2)/(wx**2) + ((j)**2)/(wy**2)) / 16

    psize = Y1.shape
    Bsize = (psize[0] // bsize, psize[1] // bsize)

    # Motion displacement
    disp = np.zeros(Bsize)
    for n1 in range(Bsize[0]):
        for n2 in range(Bsize[1]):
            disp[n1, n2] = np.sqrt(MV[n1, n2, 0]**2 + MV[n1, n2, 1]**2)

    # Smooth displacement outliers
    disp_tmp = np.zeros(Bsize)
    b_s = 5
    for n1 in range(int(np.floor(b_s/2)), Bsize[0] - int(np.floor(b_s/2))):
        for n2 in range(int(np.floor(b_s/2)), Bsize[1] - int(np.floor(b_s/2))):
            window = disp[n1 - int(np.floor(b_s/2)):n1 + int(np.floor(b_s/2)) + 1,
                          n2 - int(np.floor(b_s/2)):n2 + int(np.floor(b_s/2)) + 1]
            if disp[n1, n2] > np.mean(window) * 1.5:
                disp_tmp[n1, n2] = np.median(window)
            else:
                disp_tmp[n1, n2] = disp[n1, n2]
    disp = disp_tmp

    # Calculate retinal velocity
    vI = disp * fps / (ppd * n)  # deg/sec
    vR = np.clip(vI - np.minimum(s * vI + v_min, v_max), 0, None)

    # Benchmark CSF
    csf_0 = np.zeros((bsize, bsize))
    vR_0 = 0.15
    freq_max0 = 45.9 / (c2 * vR_0 + 2)
    k0 = 6.1 + 7.3 * np.abs(np.log10(c2 * vR_0 / 3))**3
    for i in range(bsize):
        for j in range(bsize):
            para = c4 * k0 * c0 * c2 * vR_0 * (2 * np.pi * freq[i, j] * c1)**2
            csf_0[i, j] = para * np.exp(-(4 * np.pi * c1 * freq[i, j]) / (freq_max0 * c3))

    # Spatiotemporal CSF
    csf = np.zeros((Bsize[0] * bsize, Bsize[1] * bsize))
    freq_max = np.zeros(Bsize)
    for curr_y in range(0, Bsize[0] * bsize, bsize):
        for curr_x in range(0, Bsize[1] * bsize, bsize):
            blk_y = curr_y // bsize
            blk_x = curr_x // bsize
            vR_safe = np.abs(vR[blk_y, blk_x]) + epsilon
            freq_max[blk_y, blk_x] = 45.9 / (c2 * vR_safe + 2)
            k = 6.1 + 7.3 * (np.abs(np.log10(c2 * vR_safe / 3)))**3
            for i in range(bsize):
                for j in range(bsize):
                    para = c4 * k * c0 * c2 * vR_safe * (2 * np.pi * freq[i, j] * c1)**2
                    csf[curr_y + i, curr_x + j] = para * np.exp(-(4 * np.pi * c1 * freq[i, j]) / (freq_max[blk_y, blk_x] * c3))
                    if vR_safe < 0.15 + epsilon and csf[curr_y + i, curr_x + j] > csf_0[i, j]:
                        csf[curr_y + i, curr_x + j] = csf_0[i, j]
            csf[curr_y, curr_x] = csf[curr_y + 1, curr_x]
            if vR_safe > 0.15:
                block = csf[curr_y:curr_y + bsize, curr_x:curr_x + bsize]
                t1, t2 = np.where(block < 0.08 * csf[curr_y, curr_x])
                for t in range(len(t1)):
                    csf[curr_y + t1[t], curr_x + t2[t]] = 0.08 * csf[curr_y, curr_x]

    # Threshold elevation factor
    freq_peak0 = freq_max0 / (2 * np.pi * c1)
    para = k0 * c0 * c2 * vR_0 * (2 * np.pi * freq_peak0 * c1)**2
    csf_max0 = para * np.exp(-(4 * np.pi * c1 * freq_peak0) / freq_max0)
    thr = np.zeros((Bsize[0] * bsize, Bsize[1] * bsize))
    for curr_y in range(0, Bsize[0] * bsize, bsize):
        for curr_x in range(0, Bsize[1] * bsize, bsize):
            for i in range(bsize):
                for j in range(bsize):
                    thr[curr_y + i, curr_x + j] = csf_max0 / csf[curr_y + i, curr_x + j]
                    if np.isnan(thr[curr_y + i, curr_x + j]):
                        thr[curr_y + i, curr_x + j] = csf_max0 / csf_0[i, j]

    # Orientation correction
    r = 0.6
    b = 2
    sinang = np.zeros((bsize, bsize))
    for i in range(bsize):
        for j in range(bsize):
            if freq[i, j] == 0:
                sinang[0, 0] = 0
            elif i == j:
                sinang[i, j] = 1.0
            else:
                sinang[i, j] = 2 * freq[i, 0] * freq[0, j] / (freq[i, j]**2)
    Orien = np.zeros((bsize, bsize))
    for i in range(bsize):
        for j in range(bsize):
            f = freq.copy()
            f[0, 0] = freq[0, 1]
            ang = np.arcsin(sinang[i, j])
            Orien[i, j] = 1 / (r + (1 - r) * (np.cos(ang))**b)

    thr_cor = np.zeros((Bsize[0] * bsize, Bsize[1] * bsize))
    for curr_y in range(0, Bsize[0] * bsize, bsize):
        for curr_x in range(0, Bsize[1] * bsize, bsize):
            for i in range(bsize):
                for j in range(bsize):
                    thr_cor[curr_y + i, curr_x + j] = thr[curr_y + i, curr_x + j] * Orien[i, j]

    # Conversion to grey levels
    Lmax = 130
    Lmin = 0
    M = 256
    thr_csf = np.zeros((Bsize[0] * bsize, Bsize[1] * bsize))
    for curr_y in range(0, Bsize[0] * bsize, bsize):
        for curr_x in range(0, Bsize[1] * bsize, bsize):
            for i in range(bsize):
                for j in range(bsize):
                    ai = np.sqrt(1/8) if i == 0 else np.sqrt(2/8)
                    aj = np.sqrt(1/8) if j == 0 else np.sqrt(2/8)
                    thr_csf[curr_y + i, curr_x + j] = M * thr_cor[curr_y + i, curr_x + j] / (Lmax - Lmin) / ai / aj
            thr_csf[curr_y, curr_x] = min(thr_csf[curr_y + 1, curr_x], thr_csf[curr_y, curr_x + 1])

    # Luminance adaptation
    Lum = Y2.astype(float)
    Tr = dctmtx(8)
    C = np.zeros_like(Lum)
    for i in range(0, Lum.shape[0], bsize):
        for j in range(0, Lum.shape[1], bsize):
            block = Lum[i:i+bsize, j:j+bsize]
            if block.shape == (bsize, bsize):
                C[i:i+bsize, j:j+bsize] = Tr @ block @ Tr.T

    C1 = np.zeros((Bsize[0], Bsize[1], bsize, bsize))
    for n1 in range(Bsize[0]):
        for n2 in range(Bsize[1]):
            C1[n1, n2] = C[n1*bsize:(n1+1)*bsize, n2*bsize:(n2+1)*bsize]

    aT = 3
    kT = 2
    kQ = 0.8
    aQ = 2
    C00 = 1024
    aLum = np.zeros(Bsize)
    for n1 in range(Bsize[0]):
        for n2 in range(Bsize[1]):
            if C1[n1, n2, 0, 0] > C00:
                aLum[n1, n2] = kQ * (C1[n1, n2, 0, 0] / C00 - 1)**aQ + 1
            else:
                aLum[n1, n2] = kT * (1 - C1[n1, n2, 0, 0]/C00)**aT + 1

    # Combined effects of CSF and luminance adaptation
    f_csf_lum = np.zeros((Bsize[0] * bsize, Bsize[1] * bsize))
    for curr_y in range(0, Bsize[0] * bsize, bsize):
        for curr_x in range(0, Bsize[1] * bsize, bsize):
            blk_y = curr_y // bsize
            blk_x = curr_x // bsize
            for i in range(bsize):
                for j in range(bsize):
                    f_csf_lum[curr_y + i, curr_x + j] = thr_csf[curr_y + i, curr_x + j] * aLum[blk_y, blk_x]

    # Contrast masking - block classification
    block = np.zeros(Bsize, dtype=str)
    TexMask = np.zeros(Bsize)
    for n1 in range(Bsize[0]):
        for n2 in range(Bsize[1]):
            u1 = 125
            u2 = 900
            a1 = 2.3 * 3
            b1 = 1.6 * 3
            a2 = 1
            b2 = 1.6
            y1 = 2.0
            y = 4 * 4
            k1 = 290
            edg = (np.sum(np.abs(C1[n1, n2, 3:7, 0])) + np.sum(np.abs(C1[n1, n2, 0, 3:7])) +
                   np.sum(np.abs(C1[n1, n2, 2, 1:3])) + np.abs(C1[n1, n2, 1, 2]) + np.abs(C1[n1, n2, 3, 3]))
            lowf = (np.sum(np.abs(C1[n1, n2, 1:3, 0])) + np.sum(np.abs(C1[n1, n2, 0, 1:3])) +
                    np.abs(C1[n1, n2, 1, 1]))
            highf = np.sum(np.abs(C1[n1, n2])) - edg - lowf - C1[n1, n2, 0, 0]
            edgn = edg / 12 if edg != 0 else epsilon
            lowfn = lowf / 5 if lowf != 0 else epsilon
            highfn = highf / 46 if highf != 0 else epsilon

            if edg + highf < u1:
                block[n1, n2] = 'p'
            elif edg + highf > u2:
                if ((lowfn / edgn >= a2 and (lowfn + edgn) / highfn >= b2) or
                    (lowfn / edgn >= b2 and (lowfn + edgn) / highfn >= a2) or
                    ((lowfn + edgn) / highfn >= y1)):
                    block[n1, n2] = 'e'
                else:
                    block[n1, n2] = 't'
            elif ((lowfn / edgn >= a1 and (lowfn + edgn / highfn) >= b1) or
                  (lowfn / edgn >= b1 and (lowfn + edgn) / highfn >= a1) or
                  ((lowfn + edgn) / highfn >= y)):
                block[n1, n2] = 'e'
            elif edg + highf > k1:
                block[n1, n2] = 't'
            else:
                block[n1, n2] = 'p'

            max1 = 1800
            min1 = 290
            if block[n1, n2] == 't':
                TexE = edg + highf
                FmaxT = 2.5
                TexMask[n1, n2] = (FmaxT - 1) * (TexE - min1) / (max1 - min1) + 1
            elif block[n1, n2] == 'e':
                EdgE = edg + lowf
                TexMask[n1, n2] = 1.125 if EdgE <= 400 else 1.25
            elif block[n1, n2] == 'p':
                TexMask[n1, n2] = 1

    # Texture masking elevation
    tJND = np.zeros((Bsize[0], Bsize[1], bsize, bsize))
    for n1 in range(Bsize[0]):
        for n2 in range(Bsize[1]):
            for i in range(bsize):
                for j in range(bsize):
                    if i == 0 and j == 0:
                        aCM = 1
                    else:
                        denominator = f_csf_lum[n1*bsize+i, n2*bsize+j]
                        if denominator == 0:
                            denominator = epsilon
                        aCM = max(1, (np.abs(C1[n1, n2, i, j] / denominator))**0.36) * TexMask[n1, n2]
                    if block[n1, n2] in ['e', 'p']:
                        if (1 <= i <= 6 and j == 0) or (i == 0 and 1 <= j <= 6) or \
                           (i == 1 and 1 <= j <= 2) or (i == 2 and 1 <= j <= 2) or (i == 3 and j == 3):
                            aCM = TexMask[n1, n2]
                    tJND[n1, n2, i, j] = 0.4 * f_csf_lum[n1*bsize+i, n2*bsize+j] * aCM

    # Final JND
    JND = np.zeros_like(Y1, dtype=float)
    for i in range(0, Y1.shape[0], bsize):
        for j in range(0, Y1.shape[1], bsize):
            if i + bsize <= Y1.shape[0] and j + bsize <= Y1.shape[1]:
                JND[i:i+bsize, j:j+bsize] = tJND[i//bsize, j//bsize]

    return JND

if __name__ == "__main__":
    try:
        # Load example images
        Y1 = cv2.imread('001a.bmp', cv2.IMREAD_GRAYSCALE)
        Y2 = cv2.imread('004a.bmp', cv2.IMREAD_GRAYSCALE)

        JND = JND_video(Y1, Y2)
        print("JND shape:", JND.shape)

        # Normalize and convert JND to uint8 for saving
        JND_normalized = JND / np.max(JND, where=(JND != 0), initial=1) * 255
        JND_uint8 = JND_normalized.astype(np.uint8)
        cv2.imwrite('jnd.png', JND_uint8)
    except Exception as e:
        print(f"Error: {str(e)}")