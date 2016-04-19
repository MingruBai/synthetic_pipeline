function write_img(imagePath, allV, allF,imageData,Rt)

if length(allV) == 0 || length(allF) ==0 
    return
end

disp('Writing scene to img... ');

shiftVector = Rt(:,4);
rMatrix = Rt(:,1:3);

renderF = [allF allF(:,1)];
K = imageData.K;
P = K*[inv(rMatrix*imageData.Rtilt*[1 0 0;0 0 1;0 1 0]) shiftVector];
img = imread(imageData.depthpath);
imsize = size(img);

result = RenderMex(P, imsize(2), imsize(1), allV', uint32(renderF'-1))';
z_near = 0.3;
depth = z_near./double(1-double(result)/2^32);
depthMin = min(depth(:));
depthMax = max(depth(abs(depth) < 100));
%depth(depth>10) = 0;
depth = double(depth-depthMin)/double(depthMax-depthMin);
imwrite(depth, imagePath);

end