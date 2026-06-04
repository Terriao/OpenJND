function [jnd_map,CPL,thre_final] = KLT_JND(im,ed_pro,L)
% input
% im: input image that need to compute the JND map
% ed_pro: whether use edge protect
% L: specified number of spectral components that included in inverse KLT
% If you do not input L or L=0, then the program will adopt weibull
% distribution to compute the critical point
% output
% jnd_map: the computed JND map
% CPL: perceptual lossless image
% thre_final: critical point
if (nargin==1)
    ed_pro = 1;
    L = 0;
end
if (nargin==2) 
    L = 0;
end
kernel_size = 64;
k_sqrt = sqrt(kernel_size);  % make sure dividable
im = modcrop(im, k_sqrt);
thre_cumu = 0;
f_cumu = 0;
text_matrix = patch_extract(im,kernel_size);
KLT_kernel = pca(text_matrix');
klt_coeff = KLT_kernel'*text_matrix;     
energy = (sum(klt_coeff.^2,2)/size(klt_coeff,2));
p = energy/sum(energy);
if L==0
   for i = 1:kernel_size
       P_cum(i) = sum(p(1:i));   
       thre_cumu = thre_cumu + i*weibull_com(P_cum(i));
       f_cumu = f_cumu + weibull_com(P_cum(i)); 
  end
  thre_final = ceil(thre_cumu/f_cumu);
else
  thre_final = L;
end 
klt_coeff_re = zeros(size(klt_coeff)); 
klt_coeff_re(1:thre_final,:) = klt_coeff(1:thre_final,:);
test_matrix_re = KLT_kernel*klt_coeff_re; 
CPL = image_reshape(im,test_matrix_re);
jnd_map_raw = abs(im-CPL);
edge_protect = func_edge_protect(im);
jnd_map = jnd_map_raw.*edge_protect;
end

function edge_protect = func_edge_protect( img )
% protect the edge region since the HVS is highly sensitive to it

if ~isa( img, 'double' )
    img = double( img );
end
edge_h = 60;
edge_height = func_edge_height( img );
max_val = max( edge_height(:) );
edge_threshold = edge_h / max_val;
if edge_threshold > 0.8
    edge_threshold = 0.8;
end
edge_region = edge(img,'canny',edge_threshold);
se = strel('disk',3);
img_edge = imdilate(edge_region,se);
img_supedge = 1-1*double(img_edge);
gaussian_kernal = fspecial('gaussian',5,0.8);
edge_protect = filter2(gaussian_kernal,img_supedge);
end

function edge_height = func_edge_height( img )
G1 = [0 0 0 0 0
   1 3 8 3 1
   0 0 0 0 0
   -1 -3 -8 -3 -1
   0 0 0 0 0];
G2=[0 0 1 0 0
   0 8 3 0 0
   1 3 0 -3 -1
   0 0 -3 -8 0
   0 0 -1 0 0];
G3=[0 0 1 0 0
   0 0 3 8  0
   -1 -3 0 3 1
   0 -8 -3 0 0
   0 0 -1 0 0];
G4=[0 1 0 -1 0
   0 3 0 -3 0
   0 8 0 -8 0
   0 3 0 -3 0
   0 1 0 -1 0];
% calculate the max grad
[size_x,size_y]=size(img);
grad=zeros(size_x,size_y,4);
grad(:,:,1) = filter2(G1,img)/16;
grad(:,:,2) = filter2(G2,img)/16;
grad(:,:,3) = filter2(G3,img)/16;
grad(:,:,4) = filter2(G4,img)/16;
max_gard = max( abs(grad), [], 3 );
maxgard = max_gard( 3:end-2, 3:end-2 );
edge_height = padarray( maxgard, [2,2], 'symmetric' );
end
