function variance_val = func_statistic_value(img_in, r)

% calculate the mean value, variance value and squre different value

if ~isa(img_in, 'double')
    img_in = double(img_in);
end
ker = ones( 2*r+1 ) / ( 2*r+1 )^2;
mean_mask = imfilter( img_in, ker, 'same' );
mean_img_sqr = mean_mask.^2;
img_sqr = img_in.^2;
mean_sqr_img = imfilter( img_sqr, ker, 'same' );
var_mask = mean_sqr_img - mean_img_sqr;
variance_val = sqrt( var_mask );