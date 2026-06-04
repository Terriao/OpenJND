function jnd_dis = func_disorder_jnd( img0, img, r )

ker = fspecial( 'gaussian', 2*r+1, (2*r+1) / 3 );
vari_map = func_statistic_value( img0, 3 );
img_mean = imfilter( img, ker );
img_min = min( img_mean, img );
jnd_dis = img;
jnd_dis( vari_map < 10 ) = img_min( vari_map < 10 );

superedge = func_edge( img0, 0.7 );
jnd_dis = jnd_dis .* superedge;

return;


function matout = func_edge(matin,thre)
% estimate the edge with canny operator
edge_threshold = thre;
edge_region = edge(matin,'canny',edge_threshold);
se = strel('disk',2);
img_edge = imdilate(edge_region,se);
img_supedge = 1-0.8*double(img_edge);
gaussian_kernal = fspecial('gaussian',5,0.8);
matout = filter2(gaussian_kernal,img_supedge);
return;