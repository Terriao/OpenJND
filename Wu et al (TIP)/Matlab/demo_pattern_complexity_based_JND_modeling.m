% ========================================================================
% Visual Orientation Selectivity based Structure Description, Version 1.0
% Copyright(c) 2017 Jinjian Wu
% All Rights Reserved.
%
% ----------------------------------------------------------------------
% Permission to use, copy, or modify this software and its documentation
% for educational and research purposes only and without fee is here
% granted, provided that this copyright notice and the original authors'
% names appear on all copies and supporting documentation. This program
% shall not be used, rewritten, or adapted as the basis of a commercial
% software or hardware product without first obtaining permission of the
% authors. The authors make no representations about the suitability of
% this software for any purpose. It is provided "as is" without express
% or implied warranty.
%----------------------------------------------------------------------
%
% This is an implementation of the algorithm for creating the
% Pattern Complexity based Just Noticeable Difference Modeling
%
% Please refer to the following papers
%
% Jinjian Wu, Leida Li, Weisheng Dong, Guangming Shi, Weisi Lin, and 
% C.-C. Jay Kuo, "Enhanced Just Noticeable Difference Model for Images 
% with Pattern Complexity", IEEE Trans. On Image Processing. 
%
%-----------------------------------------------------------------------
%-----------------------------------------------------------------------

clear all;
close all;
clc;

% load image
img = imread( 'actor.png' ); % 0_5_5785.jpg, lighthouse.bmp, lena.png
if size( img, 3 ) == 3 % for gray image; operating it on the three channel seperatively for colorful result 
    img = rgb2gray( img );
end

% JND mask
[ img_jnd, jnd_map, jnd_LA, jnd_VM, complexity_map ] = func_JND_modeling_pattern_complexity( img );

% show result
figure, imshow( img ); % show original image
figure('name','luminance-adaption'), imshow( mat2gray( jnd_LA ) ); % luminance adaption
figure('name','complexity-map'), imshow( mat2gray( complexity_map ) ); % complexity mask
figure('name','visual-masking'), imshow( mat2gray( jnd_VM ) ); % visual masking
figure('name','JND-map'), imshow( mat2gray( jnd_map) ); % JND map

% end of this file
