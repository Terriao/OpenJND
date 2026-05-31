%Matlab codes for DCT-based JND (Just-Noticeable Difference) model 

%Xiaohui Zhang, Nanyang Technological University, 2005

%This program implements the DCT-based JND (Just-Noticeable Difference) model developed during the MEng studies 
%under the supervision of Drs Weisi Lin (wslin@ntu.edu.sg) and Ping Xue (epxue@ntu.edu.sg). 
%The technical details have been described in the following paper:

%Xiaohui Zhang, Weisi Lin and Ping Xue, “Improved Estimation for Just-noticeable Visual Distortion”, 
%Signal Processing, Vol. 85(4), pp.795-808, April 2005.

%Related work to the pixel domain can be also found in:

%Xiaohui Zhang, Weisi Lin and Ping Xue, “Just-Noticeable Difference Estimation With Pixels in Images”, 
%Journal of Visual Communication and Image Representation, Vol 19(1), pp 30-41, 2008.


%% calculate the spatiotemporal JND based on two frames
%% modification of stjnd
%  1. fitting to watson's data, c3 = ; c4 = ;
%  2. orientation consideration
%  3. display fitting
%  4. omit the special consideration of low spatial frequencies
%% n is the interval of Y1 & Y2, ex. when Y1 = 'claire086', Y2 = 'claire090', n = 4 

function JND = JND_video(Y1, Y2)
%Y1=imread('001a.bmp');
%Y2=imread('004a.bmp');
MV=motionvector(Y1,Y2);
a=size(MV);
[XSize,YSize]=size(Y1);
%% spatiotemporal CSF


n = 1;
wx = 0.0342;
wy = 0.0342;

fps = 30;
ppd = ceil(1/wx);    % pixel per degree
s = 0.92;            % gain of the smooth pursuit eye movement
v_min = 0.15;        % minimum eye velocity due to drift: 0.15 deg/sec
v_max = 80;          % maximum eye velocity before transitioning to saccadic movements: 80 deg/sec
c0 = 1.14;
c1 = 0.67;
c2 = 1.7;
c3 = 1.186;
c4 = 3.677;

bsize = 8;
disp=zeros(a(1),a(2));
for i = 1:8
    for j = 1:8
        freq(i,j) = sqrt(((i-1)^2)/(wx^2)+((j-1)^2)/(wy^2))/16;
    end
end

psize = size(Y1);
Bsize = floor(psize/bsize);

%disp = zeros(Bsize);
for n1 = 1: Bsize(1)
    for n2 = 1: Bsize(2)
        disp(n1, n2) = sqrt(MV(n1, n2, 1)^2 + MV(n1, n2, 2)^2);
       
    end
end

disp_tmp = zeros(Bsize);
b_s = 5;
for n1 = (1+floor(b_s/2)): (Bsize(1)-floor(b_s/2))
    for n2 = (1+floor(b_s/2)): (Bsize(2)-floor(b_s/2))
        if disp(n1, n2) > mean(mean(disp((n1 - floor(b_s/2)):(n1 + floor(b_s/2)), (n2 - floor(b_s/2)):(n2 + floor(b_s/2))))) * 1.5
            disp_tmp(n1, n2) = median(median(disp((n1 - floor(b_s/2)):(n1 + floor(b_s/2)), (n2 - floor(b_s/2)):(n2 + floor(b_s/2)))));
        else
            disp_tmp(n1, n2) = disp(n1, n2);
        end
    end
end

disp = disp_tmp;

%% vI = (pixel displacement/ pixel per degree)/(time between the two frames) 
vI = zeros(Bsize);              
for n1 = 1: Bsize(1)
    for n2 = 1: Bsize(2)
        vI(n1, n2) = disp(n1, n2) * fps / (ppd * n);    % deg/sec
    end
end

% s... s decrease, vR increase
vR = zeros(Bsize);
for n1 = 1: Bsize(1)
    for n2 = 1: Bsize(2)
        vR(n1, n2) = vI(n1, n2) - min(s * vI(n1, n2) + v_min, v_max);
    end
end

%% benchmark csf
%%============================================
freq_max = zeros(Bsize);
csf = zeros(Bsize*bsize);

csf_0 = zeros(bsize, bsize);
vR_0 = 0.15;
freq_max0 = 45.9 / (c2 * vR_0 + 2);
k0 = 6.1 + 7.3 * abs(log10(c2 * vR_0/3))^3;
for i = 1: bsize
    for j = 1: bsize
    para = c4 * k0 * c0 * c2 * vR_0 * (2 * pi * freq(i, j) * c1)^2;
    csf_0(i, j) = para * exp(-(4 * pi * c1 * freq(i, j))/(freq_max0 * c3));    
    end
end
%%============================================


%% freq(i, j): spatial frequencies -- cycles/degree
for curr_y = 1: bsize: (Bsize(1)*bsize)
    for curr_x = 1: bsize: (Bsize(2)*bsize)
        blk_y = ceil(curr_y/bsize);
        blk_x = ceil(curr_x/bsize);
        freq_max(blk_y, blk_x) = 45.9 / (c2 * abs(vR(blk_y, blk_x)) + 2);
        k = 6.1 + 7.3 * (abs(log10(c2 * abs(vR(blk_y, blk_x))/3)))^3;
        for i = 1: bsize
            for j = 1: bsize
                
                para = c4 * k * c0 * c2 * abs(vR(blk_y, blk_x)) * (2 * pi * freq(i, j) * c1)^2;  %% in the paper, c0 = c0 * c4
                csf(curr_y + i - 1, curr_x + j - 1) = para * exp(-(4 * pi * c1 * freq(i, j))/(freq_max(blk_y, blk_x) * c3));
                if ((abs(vR(blk_y, blk_x)) < 0.15) && (csf(curr_y + i - 1, curr_x + j - 1) > csf_0(i, j)))
                    csf(curr_y + i - 1, curr_x + j - 1) = csf_0(i, j);
                end
                
            end
        end
%% make correction for the DC coefficients     
        csf(curr_y, curr_x) = csf(curr_y + 1, curr_x);
%% make correction for the high frequency coefficients        
        if (abs(vR(blk_y, blk_x)) > 0.15)
            [t1, t2] = find(csf(curr_y: curr_y + bsize - 1, curr_x: curr_x + bsize - 1) < 0.08 * csf(curr_y, curr_x));
            for t = 1: length(t1)
                csf(curr_y + t1(t) - 1, curr_x + t2(t) - 1) =  0.08 * csf(curr_y, curr_x);
            end
        end
        
     end
end


%% threshold elevation factor because of temporal CSF
% csf_max0 is actually a constant
freq_peak0 = freq_max0/(2 * pi * c1); 
para = k0 * c0 * c2 * vR_0 * (2 * pi * freq_peak0 * c1)^2;
csf_max0 = para * exp(-(4 * pi * c1 * freq_peak0)/(freq_max0));  

thr = zeros(Bsize*bsize);

for curr_y = 1: bsize: (Bsize(1)*bsize)
    for curr_x = 1: bsize: (Bsize(2)*bsize)
        for i = 1: bsize
            for j = 1: bsize

             
             thr(curr_y + i - 1, curr_x + j - 1) = csf_max0 / csf(curr_y + i - 1, curr_x + j - 1);
          
            end
        end
        
     end
end

%% Orientation correction 
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
for curr_y = 1: bsize: (Bsize(1)*bsize)
    for curr_x = 1: bsize: (Bsize(2)*bsize)
    
        for i = 1: bsize
            for j = 1: bsize
               
            thr_cor(curr_y + i - 1, curr_x + j - 1) = thr(curr_y + i - 1, curr_x + j - 1) * Orien(i,j);
          
            end
        end
        
     end
end

%% conversion from luminance values to corresponding grey levels
% Assume maximum luminance and minimum luminance values
Lmax = 130;
Lmin = 0;
M = 256;

thr_csf = zeros(Bsize*bsize);
for curr_y = 1: bsize: (Bsize(1)*bsize)
    for curr_x = 1: bsize: (Bsize(2)*bsize)
       
        for i = 1: bsize
            for j = 1: bsize
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

%% correct the DC JND
for curr_y = 1: bsize: (Bsize(1)*bsize)
    for curr_x = 1: bsize: (Bsize(2)*bsize)
       
               thr_csf(curr_y, curr_x) = min(thr_csf(curr_y + 1, curr_x), thr_csf(curr_y, curr_x + 1));
        
     end
end

%% elevation factor due to luminance adaptation
% Luminance Adaptation: a quasi-parabola function

Lum = double(Y2);
k = 1;
M = 256;
[row,col] = size(Lum);
% Assume maximum luminance and minimum luminance values
% Lmax = 130;
% Lmin = 0;

% DCT Transform
% C is the DCT coefficients
Tr = dctmtx(8);
C = blkproc(Lum,[8 8],'P1*x*P2',Tr,Tr');

%conversion of Luminance-DCT coefficient
% L = blkproc(C, [8 8], 'P1 + (P2 -P1)/P3*(x(1,1)/8)', Lmin, Lmax, M);

for n1 = 1: Bsize(1)
    for n2 = 1: Bsize(2)
        for i = 1: 8
            for j = 1: 8
                C1(n1, n2, i, j) = C(8 * (n1 - 1) + i, 8 * (n2 - 1) + j);
            end
        end
    end
end

%% Luminance Adaptation: a quasi-parabola function
aT = 3; kT = 2;  kQ = 0.8; aQ = 2; C00 = 1024;
%aM = 0.649;
aLum = zeros(Bsize);
for n1 = 1: Bsize(1)
    for n2 = 1: Bsize(2)
                if C1(n1, n2, 1, 1) > C00
                    aLum(n1, n2) = kQ * (C1(n1, n2, 1, 1)/C00 - 1)^aQ + 1;
                else
                    aLum(n1, n2) = kT * (1 - C1(n1, n2, 1, 1)/C00)^aT + 1;
                end
    end
end

%% combined effects of csf and luminance adaptation
f_csf_lum = zeros(Bsize*bsize);
for curr_y = 1: bsize: (Bsize(1)*bsize)
    for curr_x = 1: bsize: (Bsize(2)*bsize)
        blk_y = ceil(curr_y/bsize);
        blk_x = ceil(curr_x/bsize);
        for i = 1: bsize
            for j = 1: bsize
               f_csf_lum(curr_y + i - 1, curr_x + j - 1) = thr_csf(curr_y + i - 1, curr_x + j - 1) * aLum(blk_y, blk_x);
            end
        end
    end
end
%f_csf_lum = thr_csf;

%% Contrast Masking -- block classification
block = zeros(Bsize);
TexMask = zeros(Bsize);
% Block Classification
for n1 = 1: Bsize(1)
    for n2 = 1: Bsize(2)
        %texture masking model
        u1 = 125;
        u2 = 900;
        a1 = 2.3*3;
        b1 = 1.6*3;
        a2 = 1;
        b2 = 1.6;
        y1 = 2.0;
        y  = 4*4;
        k1  = 290;
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
            else block(n1,n2) = 't';
            end
        elseif ((lowfn(n1,n2)/edgn(n1,n2) >= a1) & ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= b1))...
                | ((lowfn(n1,n2)/edgn(n1,n2) >= b1) & ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= a1))...
                | ((lowfn(n1,n2) + edgn(n1,n2))/highfn(n1,n2) >= y)
            block(n1,n2) = 'e';
        elseif edg(n1,n2) + highf(n1,n2) > k1
            block(n1,n2) = 't';
        else block(n1,n2) = 'p';
        end        
        max1 = 1800;
        min1 = 290;
        if block(n1,n2) == 't'          %texture block
            TexE = edg(n1,n2) + highf(n1,n2);
            FmaxT = 2.5;
            TexMask(n1,n2) = (FmaxT -1)*(TexE - min1)/(max1 - min1) + 1;    
        elseif block(n1,n2) == 'e'      %edge block
            EdgE(n1,n2) = edg(n1,n2) + lowf(n1,n2);
            if EdgE(n1,n2) <= 400
                TexMask(n1,n2) = 1.125;
            else 
                TexMask(n1,n2) = 1.25;
            end
        elseif block(n1,n2) == 'p'      %plain block
            TexMask(n1,n2) = 1;
        end
    end
end
%foveation

%aFov=foveation1([round(XSize/2) round(YSize/2)], XSize,YSize);

%Texture masking elevation
st_jnd = zeros(Bsize*bsize);
for n1 = 1: Bsize(1)
    for n2 = 1: Bsize(2)
        for i = 1:8
            for j = 1:8
                if i+j == 2
                    aCM(n1,n2,1,1) = 1; %Masking elevation factor for DC
                else
                    aCM(n1,n2,i,j) = max(1,(abs(C1(n1,n2,i,j)/f_csf_lum(8*(n1-1)+i,8*(n2-1)+j)))^0.36) * TexMask(n1,n2);
                end
                if (block(n1,n2) == 'e'|| block(n1,n2) == 'p')  
                    aCM(n1,n2,2:7,1) = TexMask(n1,n2);
                    aCM(n1,n2,1,2:7) = TexMask(n1,n2);
                    aCM(n1,n2,2,2:3) = TexMask(n1,n2);
                    aCM(n1,n2,3,2:3) = TexMask(n1,n2);
                    aCM(n1,n2,4,4)   = TexMask(n1,n2);
                end
%               aCM(n1,n2) = TexMask(n1,n2);
                %Final JND for each DCT coefficient         
                tJND(n1,n2,i,j) = .4*f_csf_lum(8*(n1-1)+i, 8*(n2-1)+j) * aCM(n1,n2,i,j);%/aFov(n1,n2,i,j);
                %st_jnd(8*(n1-1)+i,8*(n2-1)+j) = tJND(n1,n2,i,j);
            end
        end
    end
end

Lmax = 130;
Lmin = 0;

[row1,col1] = size(C);
% 
for i = 0:floor(row/8)*8-1
    for j = 0:floor(col/8)*8-1
        JND(i+1,j+1) = tJND(floor(i/8)+1,floor(j/8)+1,i+1-floor(i/8)*8,j+1-floor(j/8)*8);
    end
end