function write_img(imagePath, allV, allF,imageData,Rt)

disp('Writing scene to tensor... ');

if length(allV) == 0 || length(allF) ==0 
    return
end

renderF = [allF allF(:,1)];
K = imageData.K;
P = K*[inv(imageData.Rtilt*[1 0 0;0 0 1;0 1 0]) zeros(3,1)];
img = imread(imageData.depthpath);
imsize = size(img);

result = RenderMex(P, imsize(2), imsize(1), allV', uint32(renderF'-1))';
z_near = 0.3;
depth = z_near./double(1-double(result)/2^32);
depthMin = min(depth(:));
depthMax = max(depth(abs(depth) < 100));
depth(depth>10) = 0;

tensors=[];
tensors(1).type = 'half';
tensors(1).value = single(depth);
tensors(1).sizeof = 2;
tensors(1).name = 'depth';
tensors(2).type = 'float';
tensors(2).value = single(Rt);
tensors(2).sizeof = 4;
tensors(2).name = 'Rt';

writeTensor(imagePath, tensors);
end