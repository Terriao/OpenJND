function [ img_jnd, jnd_map, jnd_LA, jnd_VM, P_c ] = func_JND_modeling_pattern_complexity(img)

if ~isa(img, 'double')
    img = double(img);
end

% luminance adaptation
jnd_LA = func_bg_lum_jnd( img );

% luminance contrast masking
L_c = func_luminance_contrast( img ); % variance value
a1 = 0.115*16;
a2 = 26;
jnd_LC = ( a1*L_c.^2.4 ) ./ ( L_c.^2+a2^2 ); % transducer

% Content complexity
P_c = func_ori_cmlx_compute( img );
a3=0.3;
a4=2.7;
a5=1;
C_t = ( a3*P_c .^a4 ) ./ ( P_c.^2+a5^2 ); % complexity transducer
% pattern maksing
jnd_PM = L_c .* C_t;
% edge protection
edge_protect = func_edge_protect( img );
jnd_PM_p = jnd_PM .* edge_protect;

% visual masking
jnd_VM = max( jnd_LC, jnd_PM_p );

% JND map
jnd_map = jnd_LA + jnd_VM - 0.3*min( jnd_LA, jnd_VM );

% inject noise into image with the guidance of JND
[row,col] = size(img);
randmat = func_randnum(row, col); % create random matrix
adjuster = 0.7; % noise level adjuster
img_jnd = uint8( double( img ) + adjuster .* randmat .* jnd_map );
MSE_val = mean( ( double( img_jnd(:) ) - double( img(:) ) ).^2 );
fprintf( 'MSE = %.3f\n', MSE_val );


% luminance adaptation
function jnd_lum_adapt = func_bg_lum_jnd( img0 )
% JND threshold due to Luminance Adaption
min_lum = 32;
alpha = 0.7;
B=[1 1 1 1 1
   1 2 2 2 1
   1 2 0 2 1
   1 2 2 2 1
   1 1 1 1 1]; % filter
bg_lum0 = floor( filter2(B, img0) / 32 );
bg_lum = func_bg_adjust( bg_lum0, min_lum ); % adjust the luminance on dark region~(near 0)
[col, row] = size(img0);
bg_jnd = lum_jnd; % visuable threshold due to bg lum.
jnd_lum = zeros(col, row); % calculate the LA for each pixel
for x = 1:col
    for y = 1:row        
        jnd_lum(x,y) = bg_jnd( bg_lum(x,y)+1 );
    end
end
jnd_lum_adapt = alpha * jnd_lum;
return;

%--------------------------------------
function bg_jnd = lum_jnd
% visuable threshold due to bg lum.
bg_jnd = zeros(256, 1); 
T0 = 17;
gamma = 3 / 128;
for k = 1 : 256
    lum = k-1;
    if lum <= 127
        bg_jnd(k) = T0 * (1 - sqrt( lum/127)) + 3;
    else
        bg_jnd(k) = gamma * (lum-127) + 3;
    end
end
return;

%------------------------------------------
function bg_lum = func_bg_adjust( bg_lum0, min_lum )
% adjust the luminance on dark region~(near 0)
[row, col] = size( bg_lum0 );
bg_lum = bg_lum0;
for x = 1 : row
    for y = 1  :col
        if bg_lum( x,y ) <= 127
            bg_lum(x,y) = round( min_lum + bg_lum(x,y)*(127-min_lum)/127 );
        end
    end
end

function L_c = func_luminance_contrast( img )
% calculate the luminance contrast for each pixel
R = 2;
ker = ones( 2*R+1 ) / ( 2*R+1 )^2;
mean_mask = imfilter( img, ker ); % mean value of each pixel
mean_img_sqr = mean_mask.^2; % square mean
img_sqr = img.^2; % square
mean_sqr_img = imfilter( img_sqr, ker ); % mean square
var_mask = mean_sqr_img - mean_img_sqr; % variance
var_mask(var_mask<0) = 0;
[row,col] = size( img );
valid_mask = zeros(row,col);
valid_mask(R+1:end-R,R+1:end-R) = 1;
var_mask = var_mask .* valid_mask;
L_c = sqrt( var_mask );

function cmlx_mat = func_ori_cmlx_compute( img )
% compute the complexity value of each pixel with its osvp 
cmlx_map = func_cmlx_num_compute( img );
r = 3;
sig = 1;
fker = fspecial( 'gaussian', r, sig );
cmlx_mat = imfilter( cmlx_map, fker );


function cmlx = func_cmlx_num_compute( img )
% set parameters
r = 1;
nb = r*8; % neighborhood size
otr = 6; % threshold for judging similar orientaion
kx = [ -1 0 1; -1 0 1; -1 0 1 ]/3;
ky = kx';
% Angle step. (coordinate)
sps=zeros(nb,2);
as = 2*pi/nb;
for i = 1:nb
    sps(i,1) = -r*sin((i-1)*as);
    sps(i,2) = r*cos((i-1)*as);
end
% osvp computation
imgd = padarray( img, [r r], 'symmetric' );
[ row, col ] = size( imgd );
Gx = imfilter( imgd, kx ); % gradient along x 
Gy = imfilter( imgd, ky ); % gradient along x
Cimg = sqrt( Gx.^2 + Gy.^2 ); % gradient
Cvimg = zeros( row,col ); % valid pixels (unshooth region)
Cvimg( Cimg>=5 ) = 1; % selecting unshooth region
Oimg = round( atan2(Gy, Gx)/pi*180 ); % algle value
Oimg( Oimg > 90 ) = Oimg( Oimg > 90 ) - 180; % [-90 90]
Oimg( Oimg < -90 ) = 180 + Oimg( Oimg < -90 );
Oimg = Oimg + 90; % [ 0 180 ]
Oimg( Cvimg==0 ) = 180+2*otr;
Oimgc = Oimg( r+1:row-r,r+1:col-r );
Cvimgc = Cvimg( r+1:row-r,r+1:col-r );

Oimg_norm = round( Oimg/2/otr );% normalize with threshold 2*otr
Oimgc_norm = round( Oimgc/2/otr );
onum = round( 180/2/otr )+1; % the type number of orientation bin
% orientation types
ssr_val = zeros( row-2*r, col-2*r, onum+1 );
for x = 0 : onum % for central pixel
    Oimgc_valid = Oimgc_norm==x;
    ssr_val( :,:,x+1 ) = ssr_val( :,:,x+1 ) + Oimgc_valid; % the ori. no. on the x-th bin for each pixel
end
for i = 1:nb % for neighbor pixels
  dx = round( r+sps(i,1) );
  dy = round( r+sps(i,2) );
  Oimgn = Oimg_norm( dx+1:row-2*r+dx, dy+1:col-2*r+dy );
  for x = 0 : onum
    Oimg_valid = Oimgn==x;
    ssr_val( :,:,x+1 ) = ssr_val( :,:,x+1 ) + Oimg_valid;
  end  
end
% complexity
ssr_no_zero = ssr_val~=0;
cmlx = sum( ssr_no_zero, 3 ); % calculate the rule number
cmlx( Cvimgc==0 ) = 1; % set the rule number of plain as 1
cmlx( 1:r, : ) = 1; % set the rule number for the image boundary
cmlx( end-r+1:end, : ) = 1;
cmlx( :, 1:r ) = 1;
cmlx( :, end-r+1:end ) = 1;


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

return;

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

function randmat = func_randnum(col,row)
% create a matrix with the value 1 or -1

mask = rand(col, row);
randmat = zeros(col, row);
for i = 1:col
    for j = 1:row
        if mask(i,j) >= 0.5
            randmat(i,j) = 1;
        else
            randmat(i,j) = -1;
        end
    end
end

return;
