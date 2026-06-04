import numpy as np

def weibull_com(x):
    beta = 894.16
    eta = 0.99805
    f = (beta / eta) * (x / eta) ** (beta - 1) * np.exp(- (x / eta) ** beta)
    return f

def modcrop(img, q):
    sz = np.array(img.shape)
    sz = sz - sz % q
    img = img[:sz[0], :sz[1]]
    return img

def patch_extract(img, k):
    k_sqrt = int(np.sqrt(k))
    img = modcrop(img, k_sqrt)
    M, N = img.shape
    m = M//k_sqrt
    n = N//k_sqrt
    patch_matrix = []
    for i in range(m):
        for j in range(n):
            patch = img[i*k_sqrt:(i+1)*k_sqrt, j*k_sqrt:(j+1)*k_sqrt]
            patch_vector = patch.reshape(k_sqrt*k_sqrt, 1)
            patch_matrix.append(patch_vector)

    patch_matrix = np.hstack(patch_matrix)
    return patch_matrix

def image_reshape(im, test_matrix):
    k = test_matrix.shape[0]
    k_sqrt = int(np.sqrt(k))
    im = modcrop(im, k_sqrt)
    M, N = im.shape
    m = M//k_sqrt
    n = N//k_sqrt
    im_re = np.zeros(im.shape)
    for i in range(m):
        for j in range(n):
            patch_vector = test_matrix[:, i*n+j]
            patch = patch_vector.reshape(k_sqrt, k_sqrt)
            im_re[i*k_sqrt:(i+1)*k_sqrt, j*k_sqrt:(j+1)*k_sqrt] = patch
    return im_re

def pca(X, num_components=None):
    mean = np.mean(X, axis=0)
    centered_data = X - mean
    covariance_matrix = np.cov(centered_data, rowvar=False)
    eigenvalues, eigenvectors = np.linalg.eigh(covariance_matrix)
    
    sorted_indices = np.argsort(eigenvalues)[::-1]
    eigenvalues = eigenvalues[sorted_indices]
    eigenvectors = eigenvectors[:, sorted_indices]
    
    if num_components is not None:
        eigenvalues = eigenvalues[:num_components]
        eigenvectors = eigenvectors[:, :num_components]
    
    return eigenvalues, eigenvectors

def func_edge_protect(img):
    
    img = np.array(img, dtype=np.float32)
    edge_h = 50
    edge_height = func_edge_height(img)
    max_val = np.max(edge_height)
    print(max_val)
    edge_threshold = edge_h / max_val

    if edge_threshold > 0.8:
        edge_threshold = 0.8

    edge_region = cv2.Canny(np.uint8(img), int(edge_threshold * 255), int(0.4 * edge_threshold * 255)) / 255
    se = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    img_edge = cv2.dilate(edge_region, se)
    img_supedge = 1 - img_edge.astype(np.float32)
    gaussian_kernel = cv2.getGaussianKernel(5, 0.8)
    edge_protect = cv2.filter2D(img_supedge, -1, gaussian_kernel)

    return edge_protect

def func_edge_height(img):
    G1 = np.array([[0, 0, 0, 0, 0],
                   [1, 3, 8, 3, 1],
                   [0, 0, 0, 0, 0],
                   [-1, -3, -8, -3, -1],
                   [0, 0, 0, 0, 0]])

    G2 = np.array([[0, 0, 1, 0, 0],
                   [0, 8, 3, 0, 0],
                   [1, 3, 0, -3, -1],
                   [0, 0, -3, -8, 0],
                   [0, 0, -1, 0, 0]])

    G3 = np.array([[0, 0, 1, 0, 0],
                   [0, 0, 3, 8, 0],
                   [-1, -3, 0, 3, 1],
                   [0, -8, -3, 0, 0],
                   [0, 0, -1, 0, 0]])

    G4 = np.array([[0, 1, 0, -1, 0],
                   [0, 3, 0, -3, 0],
                   [0, 8, 0, -8, 0],
                   [0, 3, 0, -3, 0],
                   [0, 1, 0, -1, 0]])

    grad = np.zeros([img.shape[0], img.shape[1], 4], dtype=np.float32)

    grad[:, :, 0] = cv2.filter2D(img, -1, G1) / 16
    grad[:, :, 1] = cv2.filter2D(img, -1, G2) / 16
    grad[:, :, 2] = cv2.filter2D(img, -1, G3) / 16
    grad[:, :, 3] = cv2.filter2D(img, -1, G4) / 16

    max_grad = np.max(np.abs(grad), axis=2)
    max_grad = max_grad[2:-2, 2:-2]
    edge_height = np.pad(max_grad, [(2, 2), (2, 2)], mode='symmetric')

    return edge_height


def KLT_JND(im, ed_pro=True, L=0):
    '''
    args:
        im: input image (single channel, gray or Y channel)
        L: specified number of spectral components that included in inverse KLT,
        if do not input L (i.e. L=0), then the program will adopt weibull distribution 
        to compute the critical point
    return:
        jnd_map: the computed JND map
        CPL: critical perceptual lossless image
        thre_final: critical point 
    '''
    kernel_size = 64
    k_sqrt = int(np.sqrt(kernel_size))  # make sure dividable
    im = modcrop(im, k_sqrt)
    thre_cumu = 0
    f_cumu = 0
    test_matrix = patch_extract(im, kernel_size)
    _, KLT_kernel = pca(test_matrix.T)
    klt_coeff = np.dot(KLT_kernel.T, test_matrix)
    energy = np.sum(klt_coeff**2, axis=1) / klt_coeff.shape[1]
    p = energy / np.sum(energy)
    if L==0:
        P_cum = np.zeros(kernel_size)
        for i in range(kernel_size):
            P_cum[i] = np.sum(p[:i])
            thre_cumu = thre_cumu + i * weibull_com(P_cum[i])
            f_cumu = f_cumu + weibull_com(P_cum[i])
        thre_final = int(np.ceil(thre_cumu / f_cumu))
    else:
        thre_final = L
    KLT_kernel_re = np.zeros(KLT_kernel.shape)
    KLT_kernel_re[:, :thre_final] = KLT_kernel[:, :thre_final]
    test_matrix_re = np.dot(KLT_kernel_re, klt_coeff)
    CPL = image_reshape(im, test_matrix_re)
    jnd_map = np.abs(im-CPL)
    if ed_pro:
        edge_protect = func_edge_protect(im)
        jnd_map = jnd_map * edge_protect
    return jnd_map, CPL, thre_final

if __name__ == "__main__":
    import cv2


    image_path = './lena.bmp'
    img = cv2.imread(image_path)

    kernel_size = 64
    k_sqrt = int(np.sqrt(kernel_size))
    im = modcrop(img, k_sqrt)

    if img.shape[2] == 3:
        im = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
    else:
        im = img.astype(np.float32)
    
    jnd_map, CPL, thre_final = KLT_JND(im, ed_pro=False)

    print('Critical point: ', thre_final + 1)


    cv2.imshow('JND map', (jnd_map/np.max(jnd_map)*255).astype(np.uint8))
    cv2.imshow('CPL image', CPL.astype(np.uint8))
    cv2.imshow('Original image', im.astype(np.uint8))
    cv2.waitKey(0)
    cv2.destroyAllWindows()
