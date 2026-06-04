function  im_scaled = img_scaled(im)
im_scaled = ((im - min(min(im)))/(max(max(im))-min(min(im))))*255;
end