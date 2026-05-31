clc;
clear all;
close all;

% 加载输入图像
Y1 = imread('actor.png');
Y2 = imread('actor_shifted.png');

% 确保图像为灰度
if size(Y1, 3) == 3
    Y1 = rgb2gray(Y1);
end
if size(Y2, 3) == 3
    Y2 = rgb2gray(Y2);
end


% 确保图像尺寸可被 8（块大小）整除
bsize = 8;
if mod(size(Y1, 1), bsize) ~= 0 || mod(size(Y1, 2), bsize) ~= 0
    new_rows = floor(size(Y1, 1) / bsize) * bsize;
    new_cols = floor(size(Y1, 2) / bsize) * bsize;
    Y1 = Y1(1:new_rows, 1:new_cols);
    Y2 = Y2(1:new_rows, 1:new_cols);
end

% 调用 JND_video 函数
JND = JND_video(Y1, Y2);

% 显示 JND 图
figure;
imshow(JND, []);
title('JND Map');



% JND_video 函数：计算基于 DCT 的时空 JND
function JND = JND_video(Y1, Y2)

MV = motionvector(Y1, Y2);
a = size(MV);
[XSize, YSize] = size(Y1);

% 时空 CSF（对比敏感度函数）
n = 1;
wx = 0.0342;
wy = 0.0342;
fps = 30;
ppd = ceil(1/wx);    % 每度像素数
s = 0.92;            % 平滑追踪眼动的增益
v_min = 0.15;        % 最小眼动速度（漂移）：0.15 度/秒
v_max = 80;          % 最大眼动速度（过渡到跳视前）：80 度/秒
c0 = 1.14;
c1 = 0.67;
c2 = 1.7;
c3 = 1.186;
c4 = 3.677;

bsize = 8;
disp = zeros(a(1), a(2));
for i = 1:8
    for j = 1:8
        freq(i,j) = sqrt(((i-1)^2)/(wx^2)+((j-1)^2)/(wy^2))/16;
    end
end

psize = size(Y1);
Bsize = floor(psize/bsize);

% 计算块位移
for n1 = 1:Bsize(1)
    for n2 = 1:Bsize(2)
        disp(n1, n2) = sqrt(MV(n1, n2, 1)^2 + MV(n1, n2, 2)^2);
    end
end

% 位移平滑处理
disp_tmp = zeros(Bsize);
b_s = 5;
for n1 = (1+floor(b_s/2)):(Bsize(1)-floor(b_s/2))
    for n2 = (1+floor(b_s/2)):(Bsize(2)-floor(b_s/2))
        if disp(n1, n2) > mean(mean(disp((n1 - floor(b_s/2)):(n1 + floor(b_s/2)), (n2 - floor(b_s/2)):(n2 + floor(b_s/2))))) * 1.5
            disp_tmp(n1, n2) = median(median(disp((n1 - floor(b_s/2)):(n1 + floor(b_s/2)), (n2 - floor(b_s/2)):(n2 + floor(b_s/2)))));
        else
            disp_tmp(n1, n2) = disp(n1, n2);
        end
    end
end
disp = disp_tmp;

% 计算视网膜速度 vI
vI = zeros(Bsize);
for n1 = 1:Bsize(1)
    for n2 = 1:Bsize(2)
        vI(n1, n2) = disp(n1, n2) * fps / (ppd * n);    % 度/秒
    end
end

% 计算残余速度 vR
vR = zeros(Bsize);
for n1 = 1:Bsize(1)
    for n2 = 1:Bsize(2)
        vR(n1, n2) = vI(n1, n2) - min(s * vI(n1, n2) + v_min, v_max);
    end
end

% 基准 CSF
freq_max = zeros(Bsize);
csf = zeros(Bsize*bsize);
csf_0 = zeros(bsize, bsize);
vR_0 = 0.15;
freq_max0 = 45.9 / (c2 * vR_0 + 2);
k0 = 6.1 + 7.3 * abs(log10(c2 * vR_0/3))^3;
for i = 1:bsize
    for j = 1:bsize
        para = c4 * k0 * c0 * c2 * vR_0 * (2 * pi * freq(i, j) * c1)^2;
        csf_0(i, j) = para * exp(-(4 * pi * c1 * freq(i, j))/(freq_max0 * c3));
    end
end

% 计算空间频率和 CSF
for curr_y = 1:bsize:(Bsize(1)*bsize)
    for curr_x = 1:bsize:(Bsize(2)*bsize)
        blk_y = ceil(curr_y/bsize);
        blk_x = ceil(curr_x/bsize);
        freq_max(blk_y, blk_x) = 45.9 / (c2 * abs(vR(blk_y, blk_x)) + 2);
        k = 6.1 + 7.3 * (abs(log10(c2 * abs(vR(blk_y, blk_x))/3)))^3;
        for i = 1:bsize
            for j = 1:bsize
                para = c4 * k * c0 * c2 * abs(vR(blk_y, blk_x)) * (2 * pi * freq(i, j) * c1)^2;
                csf(curr_y + i - 1, curr_x + j - 1) = para * exp(-(4 * pi * c1 * freq(i, j))/(freq_max(blk_y, blk_x) * c3));
                if (abs(vR(blk_y, blk_x)) < 0.15) && (csf(curr_y + i - 1, curr_x + j - 1) > csf_0(i, j))
                    csf(curr_y + i - 1, curr_x + j - 1) = csf_0(i, j);
                end
            end
        end
        % 修正 DC 系数
        csf(curr_y, curr_x) = csf(curr_y + 1, curr_x);
        % 修正高频系数
        if abs(vR(blk_y, blk_x)) > 0.15
            [t1, t2] = find(csf(curr_y:curr_y + bsize - 1, curr_x:curr_x + bsize - 1) < 0.08 * csf(curr_y, curr_x));
            for t = 1:length(t1)
                csf(curr_y + t1(t) - 1, curr_x + t2(t) - 1) = 0.08 * csf(curr_y, curr_x);
            end
        end
    end
end

% 时空 CSF 引起的阈值提升因子
freq_peak0 = freq_max0/(2 * pi * c1);
para = k0 * c0 * c2 * vR_0 * (2 * pi * freq_peak0 * c1)^2;
csf_max0 = para * exp(-(4 * pi * c1 * freq_peak0)/(freq_max0));
thr = zeros(Bsize*bsize);
for curr_y = 1:bsize:(Bsize(1)*bsize)
    for curr_x = 1:bsize:(Bsize(2)*bsize)
        for i = 1:bsize
            for j = 1:bsize
                thr(curr_y + i - 1, curr_x + j - 1) = csf_max0 / csf(curr_y + i - 1, curr_x + j - 1);
            end
        end
    end
end

% 方向性校正
r = 0.6;
b = 2;
for i = 1:8
    for j = 1:8
        freq(i,j) = sqrt(((i-1)^2)/(wx^2)+((j-1)^2)/(wy^2))/16;
        if freq(i,j) == 0
            sinang(1,1) = 0;
        elseif i == j
            sinang(i,j) = 1.0;
        else
            sinang(i,j) = 2*freq(i,1)*freq(1,j)/(freq(i,j)^2);
        end
    end
end

Orien = zeros(8, 8);
for i = 1:8
    for j = 1:8
        f = freq;
        f(1,1) = freq(1,2);
        ang(i,j) = asin(sinang(i,j));
        Orien(i,j) = 1/(r+(1-r)*((cos(ang(i,j)))^b));
    end
end

thr_cor = zeros(Bsize*bsize);
for curr_y = 1:bsize:(Bsize(1)*bsize)
    for curr_x = 1:bsize:(Bsize(2)*bsize)
        for i = 1:bsize
            for j = 1:bsize
                thr_cor(curr_y + i - 1, curr_x + j - 1) = thr(curr_y + i - 1, curr_x + j - 1) * Orien(i,j);
            end
        end
    end
end

% 将亮度值转换为灰度级
Lmax = 130;
Lmin = 0;
M = 256;
thr_csf = zeros(Bsize*bsize);
for curr_y = 1:bsize:(Bsize(1)*bsize)
    for curr_x = 1:bsize:(Bsize(2)*bsize)
        for i = 1:bsize
            for j = 1:bsize
                if i == 1
                    ai = sqrt(1/8);
                else
                    ai = sqrt(2/8);
                end
                if j == 1
                    aj = sqrt(1/8);
                else
                    aj = sqrt(2/8);
                end
                thr_csf(curr_y + i - 1, curr_x + j - 1) = M * thr_cor(curr_y + i - 1, curr_x + j - 1)/(Lmax - Lmin)/ai/aj;
            end
        end
    end
end

% 修正 DC JND
for curr_y = 1:bsize:(Bsize(1)*bsize)
    for curr_x = 1:bsize:(Bsize(2)*bsize)
        thr_csf(curr_y, curr_x) = min(thr_csf(curr_y + 1, curr_x), thr_csf(curr_y, curr_x + 1));
    end
end

% 亮度适应的提升因子
Lum = double(Y2);
k = 1;
M = 256;
[row, col] = size(Lum);

% DCT 变换
Tr = dctmtx(8);
C = blkproc(Lum, [8 8], 'P1*x*P2', Tr, Tr');

% 提取 DCT 系数
for n1 = 1:Bsize(1)
    for n2 = 1:Bsize(2)
        for i = 1:8
            for j = 1:8
                C1(n1, n2, i, j) = C(8 * (n1 - 1) + i, 8 * (n2 - 1) + j);
            end
        end
    end
end

% 亮度适应：准抛物线函数
aT = 3; kT = 2; kQ = 0.8; aQ = 2; C00 = 1024;
aLum = zeros(Bsize);
for n1 = 1:Bsize(1)
    for n2 = 1:Bsize(2)
        if C1(n1, n2, 1, 1) > C00
            aLum(n1, n2) = kQ * (C1(n1, n2, 1, 1)/C00 - 1)^aQ + 1;
        else
            aLum(n1, n2) = kT * (1 - C1(n1, n2, 1, 1)/C00)^aT + 1;
        end
    end
end

% 结合 CSF 和亮度适应的效果
f_csf_lum = zeros(Bsize*bsize);
for curr_y = 1:bsize:(Bsize(1)*bsize)
    for curr_x = 1:bsize:(Bsize(2)*bsize)
        blk_y = ceil(curr_y/bsize);
        blk_x = ceil(curr_x/bsize);
        for i = 1:bsize
            for j = 1:bsize
                f_csf_lum(curr_y + i - 1, curr_x + j - 1) = thr_csf(curr_y + i - 1, curr_x + j - 1) * aLum(blk_y, blk_x);
            end
        end
    end
end

% 对比度掩蔽 - 块分类
block = zeros(Bsize);
TexMask = zeros(Bsize);
for n1 = 1:Bsize(1)
    for n2 = 1:Bsize(2)
        % 纹理掩蔽模型
        u1 = 125;
        u2 = 900;
        a1 = 2.3*3;
        b1 = 1.6*3;
        a2 = 1;
        b2 = 1.6;
        y1 = 2.0;
        y = 4*4;
        k1 = 290;
        edge_area = 1;
        texture_area = 2;
        plain_area = 0;
        edg(n1,n2) = sum(abs(C1(n1,n2,4:7,1))) + sum(abs(C1(n1,n2,1,4:7))) + sum(abs(C1(n1,n2,3,2:3)))...
                     + abs(C1(n1,n2,2,3)) + abs(C1(n1,n2,4,4));
        lowf(n1,n2) = sum(abs(C1(n1,n2,2:3,1))) + sum(abs(C1(n1,n2,1,2:3))) + abs(C1(n1,n2,2,2));
        highf(n1,n2) = sum(sum(abs(C1(n1,n2,:,:)))) - edg(n1,n2) - lowf(n1,n2) - C1(n1,n2,1,1);
        
        edgn(n1,n2) = edg(n1,n2)/12;
        lowfn(n1,n2) = lowf(n1,n2)/5;
        highfn(n1,n2) = highf(n1,n2)/46;
        
        if edg(n1,n2) + highf(n1,n2) < u1
            block(n1,n2) = 'p';
        elseif edg(n1,n2) + highf(n1,n2) > u2
            if ((lowfn(n1,n2)/edgn(n1,n2) >= a2) & ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= b2))... 
                | ((lowfn(n1,n2)/edgn(n1,n2) >= b2) & ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= a2))...
                | ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= y1)
                block(n1,n2) = 'e';
            else
                block(n1,n2) = 't';
            end
        elseif ((lowfn(n1,n2)/edgn(n1,n2) >= a1) & ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= b1))...
                | ((lowfn(n1,n2)/edgn(n1,n2) >= b1) & ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= a1))...
                | ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= y)
            block(n1,n2) = 'e';
        elseif edg(n1,n2) + highf(n1,n2) > k1
            block(n1,n2) = 't';
        else
            block(n1,n2) = 'p';
        end        
        max1 = 1800;
        min1 = 290;
        if block(n1,n2) == 't'          % 纹理块
            TexE = edg(n1,n2) + highf(n1,n2);
            FmaxT = 2.5;
            TexMask(n1,n2) = (FmaxT -1)*(TexE - min1)/(max1 - min1) + 1;    
        elseif block(n1,n2) == 'e'      % 边缘块
            EdgE(n1,n2) = edg(n1,n2) + lowf(n1,n2);
            if EdgE(n1,n2) <= 400
                TexMask(n1,n2) = 1.125;
            else 
                TexMask(n1,n2) = 1.25;
            end
        elseif block(n1,n2) == 'p'      % 平坦块
            TexMask(n1,n2) = 1;
        end
    end
end

% 纹理掩蔽提升
st_jnd = zeros(Bsize*bsize);
for n1 = 1:Bsize(1)
    for n2 = 1:Bsize(2)
        for i = 1:8
            for j = 1:8
                if i+j == 2
                    aCM(n1,n2,1,1) = 1; % DC 的掩蔽提升因子
                else
                    aCM(n1,n2,i,j) = max(1,(abs(C1(n1,n2,i,j)/f_csf_lum(8*(n1-1)+i,8*(n2-1)+j)))^0.36) * TexMask(n1,n2);
                end
                if (block(n1,n2) == 'e' || block(n1,n2) == 'p')  
                    aCM(n1,n2,2:7,1) = TexMask(n1,n2);
                    aCM(n1,n2,1,2:7) = TexMask(n1,n2);
                    aCM(n1,n2,2,2:3) = TexMask(n1,n2);
                    aCM(n1,n2,3,2:3) = TexMask(n1,n2);
                    aCM(n1,n2,4,4) = TexMask(n1,n2);
                end
                % 每个 DCT 系数的最终 JND
                tJND(n1,n2,i,j) = 0.4 * f_csf_lum(8*(n1-1)+i, 8*(n2-1)+j) * aCM(n1,n2,i,j);
            end
        end
    end
end

Lmax = 130;
Lmin = 0;
[row1, col1] = size(C);
for i = 0:floor(row/8)*8-1
    for j = 0:floor(col/8)*8-1
        JND(i+1,j+1) = tJND(floor(i/8)+1,floor(j/8)+1,i+1-floor(i/8)*8,j+1-floor(j/8)*8);
    end
end
end 


function MV = motionvector(Y1, Y2)

    [rows, cols] = size(Y1);
    block_size = 8;
    num_blocks_x = floor(cols / block_size);
    num_blocks_y = floor(rows / block_size);
    MV = zeros(num_blocks_y, num_blocks_x, 2); % 零运动矢量
end