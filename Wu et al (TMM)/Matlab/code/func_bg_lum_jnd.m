function jnd_lum_adapt = func_bg_lum_jnd( img0, min_lum )

% luminance adaption jnd
alpha = 1;
jnd_ld = func_lum_jnd( img0, min_lum );
jnd_lum_adapt = alpha * jnd_ld;
return;

function matout = func_lum_jnd( matin, min_lum )
if ~isa(matin, 'double')
    matin = double(matin);
end
bg_lum0 = func_bg_lum(matin);
% bg_lum = round( min_lum + bg_lum0 * ( (255-min_lum) / 255 ) );
bg_lum = func_bg_adjust( bg_lum0, min_lum );
[col, row] = size(matin);
bg_jnd = lum_jnd;
jnd_lum = zeros(col, row);
for x = 1:col
    for y = 1:row        
        jnd_lum(x,y) = bg_jnd( bg_lum(x,y)+1 );
    end
end
matout = jnd_lum;
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

% end of this file