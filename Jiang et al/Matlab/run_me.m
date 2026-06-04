clc;clear;close all;
tic;
kernel_size=64;
img = imread(['.\lena.bmp']);
img = modcrop(img,sqrt(kernel_size));
if (size(img,3)==3)
   im = double(rgb2gray(img));
else
   im = double(img);
end
[jnd_map,CPL,thre_final] = KLT_JND(im,1);

jnd_map_show = img_scaled(log2(jnd_map+2));
figure,
imshow(jnd_map,[]), title('JND map');
% scale the JND map for finer observation
toc;
figure,
imshow(uint8(jnd_map_show)), title('JND map after scaling');
figure,
imshow(CPL,[]),title('CPL image');
figure,
imshow(im,[]),title('Original image');



