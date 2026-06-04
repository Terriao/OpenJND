function im_re = image_reshape(im,test_matrix)

k = size(test_matrix,1);
k_sqrt = sqrt(k);
im = modcrop(im,k_sqrt);
[M N H] = size(im);
m = M/k_sqrt; 
n = N/k_sqrt;
for i=1:m
    for j=1:n       
        patch_vec = test_matrix(:,(i-1)*n+j);
        patch = reshape(patch_vec,k_sqrt,k_sqrt);
        im_re((i-1)*k_sqrt+1:i*k_sqrt,(j-1)*k_sqrt+1:j*k_sqrt) = patch;                
    end    
end

end




