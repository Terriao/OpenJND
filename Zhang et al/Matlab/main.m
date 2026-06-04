% main.m
% 基于DCT的JND（刚可察觉差异）模型
% 参考文献：
% Xiaohui Zhang, Weisi Lin and Ping Xue, "Improved Estimation for Just-noticeable Visual Distortion",
% Signal Processing, Vol. 85(4), pp.795-808, April 2005.
%
% 输入：
%   distImg: 灰度图像矩阵
%
% 输出：
%   JND: 每个像素的JND阈值矩阵

function JND = JND_dct(distImg)
    % 将输入图像转换为双精度
    Lum = double(distImg);
    M = 256; % 假设8位图像
    [row, col] = size(Lum);
    % 裁剪图像尺寸为8的倍数
    Lum = Lum(1:floor(row/8)*8, 1:floor(col/8)*8);
    [row, col] = size(Lum);
    tfac = 0.3; % JND调整因子


    % 假设最大和最小亮度值
    Lmax = 130;
    Lmin = 0;

    % DCT变换（8x8块）
    Tr = dctmtx(8); % 8x8 DCT矩阵
    C = zeros(size(Lum));
    for i = 1:8:row
        for j = 1:8:col
            C(i:i+7, j:j+7) = Tr * Lum(i:i+7, j:j+7) * Tr';
        end
    end

    % 亮度-DCT系数转换
    L = zeros(size(C));
    for i = 1:8:row
        for j = 1:8:col
            L(i:i+7, j:j+7) = Lmin + (Lmax - Lmin) / M * (C(i, j) / 8);
        end
    end

    % 8x8块的数量
    row1 = row / 8;
    col1 = col / 8;

    % CSF计算参数
    wx = 0.0298; % 水平像素宽度
    wy = 0.0298; % 垂直像素宽度
    r = 0.6;
    LT = 13.45;
    S0 = 94.7;
    aT = 0.649;
    aL = 0.500;
    f0 = 6.78;
    af = 0.182;
    Lf = 300;
    K0 = 3.125;
    aK = 0.0706;
    LK = 300;
    L0 = 65;
    s = 0.25;
    LB = 65; % 假设灰度值128对应65 cd/m^2
    C00 = 1024;

    % Ahumada-Peterson CSF方程
    if LB <= LK
        K = K0 * ((LB / LK) ^ aK);
    else
        K = K0;
    end
    if LB <= Lf
        fmin = f0 * ((LB / Lf) ^ af);
    else
        fmin = f0;
    end
    if LB <= LT
        Tmin = LT / S0 * ((LB / LT) ^ aT);
    else
        Tmin = LB / S0;
    end

    % 频率和角度计算
    freq = zeros(8, 8);
    sinang = zeros(8, 8);
    for i = 1:8
        for j = 1:8
            freq(i, j) = sqrt(((i-1)^2 / wx^2 + (j-1)^2 / wy^2)) / 16;
            if freq(i, j) == 0
                sinang(1, 1) = 0;
            elseif i == j
                sinang(i, j) = 1.0;
            else
                sinang(i, j) = 2 * freq(i, 1) * freq(1, j) / (freq(i, j)^2);
            end
        end
    end

    ang = zeros(8, 8);
    g = zeros(8, 8);
    T = zeros(8, 8);
    for i = 1:8
        for j = 1:8
            f = freq;
            f(1, 1) = freq(1, 2);
            ang(i, j) = asin(sinang(i, j));
            f1 = (log10(f(i, j)) - log10(fmin))^2;
            g(i, j) = log10(s * Tmin / (r + (1 - r) * (cos(ang(i, j))^2))) + K * f1;
            T(i, j) = 10^g(i, j);
        end
    end

    tij = zeros(8, 8);
    for i = 1:8
        for j = 1:8
            ai = sqrt(1/8) * (i == 1) + sqrt(2/8) * (i ~= 1);
            aj = sqrt(1/8) * (j == 1) + sqrt(2/8) * (j ~= 1);
            tij(i, j) = M * T(i, j) / (Lmax - Lmin) / ai / aj;
        end
    end

    % 调整DC的JND
    tij(1, 1) = min(tij(1, 2), tij(2, 1));

    % 将DCT系数重新组织为块
    C1 = zeros(row1, col1, 8, 8);
    for i = 1:row
        for j = 1:col
            n1 = floor((i-1)/8) + 1;
            n2 = floor((j-1)/8) + 1;
            C1(n1, n2, mod(i-1,8)+1, mod(j-1,8)+1) = C(i, j);
        end
    end

    % 亮度适配：准抛物线函数
    aT = 3; kT = 2; aM = 0.649; kQ = 0.8; aQ = 2;
    tDCT = zeros(row1, col1, 8, 8);
    aLum = zeros(row1, col1);
    for n1 = 1:row1
        for n2 = 1:col1
            for i = 1:8
                for j = 1:8
                    if C1(n1, n2, 1, 1) > C00
                        tDCT(n1, n2, i, j) = tij(i, j) * (kQ * (C1(n1, n2, 1, 1) / C00 - 1)^aQ + 1);
                        aLum(n1, n2) = kQ * (C1(n1, n2, 1, 1) / C00 - 1)^aQ + 1;
                    else
                        tDCT(n1, n2, i, j) = tij(i, j) * (kT * (1 - C1(n1, n2, 1, 1) / C00)^aT + 1);
                        aLum(n1, n2) = kT * (1 - C1(n1, n2, 1, 1) / C00)^aT + 1;
                    end
                end
            end
        end
    end

    % 块分类
    block = repmat({''}, [row1, col1]);
    edg = zeros(row1, col1);
    lowf = zeros(row1, col1);
    highf = zeros(row1, col1);
    TexMask = zeros(row1, col1);
    for n1 = 1:row1
        for n2 = 1:col1
            % 纹理掩蔽模型参数
            u1 = 125; u2 = 900;
            a1 = 2.3*3; b1 = 1.6*3;
            a2 = 1; b2 = 1.6;
            y1 = 2.0; y = 4*4;
            k1 = 290;

            % 边缘、低频、高频能量
            edg(n1, n2) = sum(abs(C1(n1, n2, 4:7, 1)), 'all') + ...
                          sum(abs(C1(n1, n2, 1, 4:7)), 'all') + ...
                          sum(abs(C1(n1, n2, 3, 2:3)), 'all') + ...
                          abs(C1(n1, n2, 2, 3)) + ...
                          abs(C1(n1, n2, 4, 4));
            lowf(n1, n2) = sum(abs(C1(n1, n2, 2:3, 1)), 'all') + ...
                           sum(abs(C1(n1, n2, 1, 2:3)), 'all') + ...
                           abs(C1(n1, n2, 2, 2));
            highf(n1, n2) = sum(abs(C1(n1, n2, :, :)), 'all') - edg(n1, n2) - lowf(n1, n2) - C1(n1, n2, 1, 1);

            edgn = edg(n1, n2) / 12;
            lowfn = lowf(n1, n2) / 5;
            highfn = highf(n1, n2) / 46;

            % 块分类
            if edg(n1, n2) + highf(n1, n2) < u1
                block{n1, n2} = 'p';
            elseif edg(n1, n2) + highf(n1, n2) > u2
                if ((lowfn / edgn >= a2) && ((lowfn + edgn) / highfn >= b2)) || ...
                   ((lowfn / edgn >= b2) && ((lowfn + edgn) / highfn >= a2)) || ...
                   ((lowfn + edgn) / highfn >= y1)
                    block{n1, n2} = 'e';
                else
                    block{n1, n2} = 't';
                end
            elseif ((lowfn / edgn >= a1) && ((lowfn + edgn) / highfn >= b1)) || ...
                   ((lowfn / edgn >= b1) && ((lowfn + edgn) / highfn >= a1)) || ...
                   ((lowfn + edgn) / highfn >= y)
                block{n1, n2} = 'e';
            elseif edg(n1, n2) + highf(n1, n2) > k1
                block{n1, n2} = 't';
            else
                block{n1, n2} = 'p';
            end

            % 纹理掩蔽
            max1 = 1800; min1 = 290;
            if strcmp(block{n1, n2}, 't') % 纹理块
                TexE = edg(n1, n2) + highf(n1, n2);
                FmaxT = 2.5;
                TexMask(n1, n2) = (FmaxT - 1) * (TexE - min1) / (max1 - min1) + 1;
            elseif strcmp(block{n1, n2}, 'e') % 边缘块
                EdgE = edg(n1, n2) + lowf(n1, n2);
                TexMask(n1, n2) = 1.125 * (EdgE <= 400) + 1.25 * (EdgE > 400);
            elseif strcmp(block{n1, n2}, 'p') % 平坦块
                TexMask(n1, n2) = 1;
            end
        end
    end

    % 纹理掩蔽提升
    aCM = zeros(row1, col1, 8, 8);
    tJND = zeros(row1, col1, 8, 8);
    for n1 = 1:row1
        for n2 = 1:col1
            for i = 1:8
                for j = 1:8
                    if i == 1 && j == 1
                        aCM(n1, n2, 1, 1) = 1; % DC的掩蔽提升因子
                    else
                        aCM(n1, n2, i, j) = max(1, (abs(C1(n1, n2, i, j) / tDCT(n1, n2, i, j)))^0.36) * TexMask(n1, n2);
                    end
                    if strcmp(block{n1, n2}, 'e')
                        aCM(n1, n2, 2:7, 1) = TexMask(n1, n2);
                        aCM(n1, n2, 1, 2:7) = TexMask(n1, n2);
                        aCM(n1, n2, 2, 2:3) = TexMask(n1, n2);
                        aCM(n1, n2, 3, 2:3) = TexMask(n1, n2);
                        aCM(n1, n2, 4, 4) = TexMask(n1, n2);
                    end
                    tJND(n1, n2, i, j) = tDCT(n1, n2, i, j) * aCM(n1, n2, i, j);
                end
            end
        end
    end

    % 最终JND映射
    JND = zeros(row, col);
    for i = 1:row
        for j = 1:col
            n1 = floor((i-1)/8) + 1;
            n2 = floor((j-1)/8) + 1;
            JND(i, j) = tJND(n1, n2, mod(i-1,8)+1, mod(j-1,8)+1) * tfac;
        end
    end
end

% 主程序
try
    % 读取灰度图像
    distImg = imread('actor.png');
    if size(distImg, 3) == 3
        distImg = rgb2gray(distImg); % 转换为灰度
    end
    
    % 打印输入图像尺寸
    fprintf('Input size：[%d, %d]\n', size(distImg));
    
    % 计算 JND
    JND = JND_dct(distImg);
    fprintf('JND Matrix Shape：[%d, %d]\n', size(JND));
    
    % 可视化 JND 矩阵
    figure('Name', 'JND Visualization');
    imagesc(JND); colormap gray;
    c = colorbar;
    c.Label.String = 'JND Value';
    title('JND Visualization');
    drawnow;
    
catch e

end