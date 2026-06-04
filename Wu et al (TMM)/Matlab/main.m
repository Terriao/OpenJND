% ========================================================================
% JND Index with automatic downsampling, Version 1.0
% Copyright(c) 2012 Jinjian Wu, Guangming Shi, Weisi Lin, Anmin Liu, and
% Fei Qi
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
% This is an implementation of the algorithm for calculating the
% Free-energy based JND.
%
% Please refer to the following paper
%
% J. Wu, G. Shi, W. Lin, A. Liu, and F. Qi, 揓ust Noticeable Difference 
% Estimation For Images with Free-Energy Principle�, IEEE Trans. on 
% Multimedia, accepted, 2012
%-----------------------------------------------------------------------
%-----------------------------------------------------------------------

clear all;
close all;
clc;

addpath( [ cd '\code' ] );

%--------------------------------
% load image
img0 = imread( 'actor.png' );

%--------------------------------
% JND computation
% jnd_map = func_jnd_ssr( img0 );
% Autoregression based on ar model
min_sigma = 8;
min_lum = 32;
r = 3;
img_ar = func_ar_predict_decomp( img0, min_sigma );
img_free_energy = abs( double( img0 ) - double( img_ar ) );

% Luminance adaption JND based on background luminance
jnd_LA = func_bg_lum_jnd( img_ar, min_lum );

% Contrast masking JND based on edge height
jnd_CM = func_contrast_mask_jnd( img_ar );

% Uncertainty jnd based on disorder
jnd_Dis = func_disorder_jnd( img0, img_free_energy, r );

% jnd mask
jnd_order = jnd_LA + jnd_CM - 0.3 * min( jnd_LA, jnd_CM );
jnd_disorder = jnd_Dis;
jnd_map0 = jnd_order + jnd_disorder - 0.3 * min( jnd_order, jnd_disorder );
[row, col] = size( img0 );
valid_mask = zeros( row, col );
valid_mask( r:row-r,r:col-r ) = 1;
jnd_map = jnd_map0 .* valid_mask;
jnd_img = uint8( jnd_map / max( jnd_map(:) ) * 255 );

% inject jnd noise into image
randmat = func_randnum(row, col);
alpha = 1;
img_distort_jnd = uint8( double( img0 ) + alpha* randmat .* jnd_map );
MSE_val = mean( ( double(img0(:)) - double(img_distort_jnd(:)) ).^2 );
fprintf( 'MSE = %.2f\n', MSE_val );


figure( 'name', 'original image' ), imshow( img0 );
figure( 'name', 'jnd mask' ), imshow( jnd_img );
figure( 'name', 'distorted image' ), imshow( img_distort_jnd );

rmpath( [ cd '\code' ] );

% end of this file