% patch extract
% extract a designed size img patch and reshape it into a vector
% cat all vector into a matrix
% img must be M-N-1
function patch_matrix = patch_extract(img, k)

k_sqrt = sqrt(k);
% change the img with M-N , mod(M,size)=0, mod(N,size)=0 
img = modcrop(img,k_sqrt);
[M,N,~] = size(img);
m = M/k_sqrt; 
n = N/k_sqrt;
patch_matrix = [];
for i = 1:m
    for j = 1:n      
        patch = img((i-1)*k_sqrt+1:i*k_sqrt,(j-1)*k_sqrt+1:j*k_sqrt);
        patch_matrix = [patch_matrix reshape(patch,k_sqrt*k_sqrt,1)];                             
    end
end
   
end