function jnd_CM = func_contrast_mask_jnd( img )

lum_diff = func_luminance_diff( img );
thre = 80;
lum_diff_ = thre * log10( 1 + lum_diff / thre ) / log10(4);
bg_lum = func_bg_lum(img);
LANDA = 1/2;
alpha = 0.0001*bg_lum+0.115;
belta = LANDA-0.01*bg_lum;
jnd_CM = abs( lum_diff_.*alpha + belta );

return;

function lum_diff = func_luminance_diff( img )
if ~isa(img, 'double')
    img = double(img);
end
G1 = [ 0  0  0  0  0
       1  3  8  3  1
       0  0  0  0  0
      -1 -3 -8 -3 -1
       0  0  0  0  0 ];
G2=[ 0  0  1  0  0
     0  8  3  0  0
     1  3  0 -3 -1
     0  0 -3 -8  0
     0  0 -1  0  0 ];
G3=[ 0  0  1  0  0
     0  0  3  8  0
    -1 -3  0  3  1
     0 -8 -3  0  0
     0  0 -1  0  0 ];
G4=[ 0  1  0 -1  0
     0  3  0 -3  0
     0  8  0 -8  0
     0  3  0 -3  0
     0  1  0 -1  0 ];
% calculate the max grad as the luminance difference
[size_x,size_y]=size(img);
grad=zeros(size_x,size_y,4);
grad(:,:,1) = filter2(G1,img)/16;
grad(:,:,2) = filter2(G2,img)/16;
grad(:,:,3) = filter2(G3,img)/16;
grad(:,:,4) = filter2(G4,img)/16;
lum_diff = max( abs(grad), [], 3 );
return;

function matout = func_bg_lum(matin)
% calculate the average background luminance of the image
if ~isa(matin, 'double')
    matin = double(matin);
end
B=[1 1 1 1 1
   1 2 2 2 1
   1 2 0 2 1
   1 2 2 2 1
   1 1 1 1 1];
matout = floor( filter2(B, matin) / 32 );
return;
