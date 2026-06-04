function img_predict = func_ar_predict_decomp(img0,min_thr,r,R)

if (nargin < 1 || nargin > 4)
    error('Input wrong data!');
end

if (nargin == 1)
    min_thr = 5; % JND 20 VS. JPEG 5
    r = 3;
    R = 10;
end
if (nargin == 2)
    r = 3;
    R = 10;
end
if (nargin == 3)
    R = 10;
end


min_sigma = func_bg_lum_jnd( img0 );
min_sigma( min_sigma < min_thr ) = min_thr;
img_predict = func_ar_nl( img0, min_sigma,r,R );

return;


%-----------------------------
function jnd_lum_adapt = func_bg_lum_jnd( img0 )
% estimate the background luminance distortion
if ~isa(img0, 'double')
    img0 = double(img0);
end
min_lum = 32;
bg_lum0 = func_bg_lum(img0);
bg_lum = func_bg_adjust( bg_lum0, min_lum );
[col, row] = size(img0);
bg_jnd = lum_jnd;
jnd_lum_adapt = zeros(col, row);
for x = 1:col
    for y = 1:row        
        jnd_lum_adapt(x,y) = bg_jnd( bg_lum(x,y)+1 );
    end
end
return;


%-------------------------------------
function matout = func_bg_lum(matin)
B=[1 1 1 1 1
   1 2 2 2 1
   1 2 0 2 1
   1 2 2 2 1
   1 1 1 1 1];
matout = floor( filter2(B, matin) / 32 );
return;

%--------------------------------------
function bg_jnd = lum_jnd
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
[row, col] = size( bg_lum0 );
bg_lum = bg_lum0;
for x = 1 : row
    for y = 1  :col
        if bg_lum( x,y ) <= 127
            bg_lum(x,y) = round( min_lum + bg_lum(x,y)*(127-min_lum)/127 );
        end
    end
end
return;


%---------------------------------
function img_reconst = func_ar_nl( img_in, min_sigma,r,R )

if ~isa( img_in, 'double' )
    img_in = double( img_in );
end
[row, col] = size(img_in);
vari = func_statistic_value( img_in, r );
% param.sigma = mean( vari(:) );
sigma_value = min_sigma.^2;
sigma_value(vari>min_sigma) = ( min_sigma(vari>min_sigma) .* ...
    ( min_sigma(vari>min_sigma) ./ vari(vari>min_sigma) ).^(0.5) ).^2;

mat_pad = padarray(img_in, [R+r,R+r], 'symmetric'); % pad the mat for edge processing
img_pad = mat_pad( R+1:end-R, R+1:end-R );
% pixel value reconstruct
ker = ones( 2*r+1 ) / ( 2*r+1 )^2;
img_reco = zeros( row, col );
weight_mat = zeros( row, col );
max_weight = zeros( row, col );
for u = -R : R
    for v = -R : R
        
        if u==0 && v==0
            continue;
        end
        
        % difference with moving step (u,v)
        img_move = mat_pad( R+1+u:end-R+u, R+1+v:end-R+v );
        mat_dif = ( img_pad - img_move ).^2;
        sum_val = filter2( ker, mat_dif, 'valid' );        
        mat_simi = exp( - sum_val ./ sigma_value );
        
        % reconstruct value
        img_reco = img_reco + img_move(r+1:end-r, r+1:end-r).*mat_simi;
        weight_mat = weight_mat + mat_simi;
        max_weight( mat_simi > max_weight ) = mat_simi( mat_simi > max_weight );
%         max_weight( weight_mat > max_weight ) = weight_mat( weight_mat > max_weight );
    end
end

img_recon = img_reco + max_weight .* img_in;
weight_mat = weight_mat + max_weight;
img_reconst = uint8( img_recon ./ weight_mat );

% end of this file