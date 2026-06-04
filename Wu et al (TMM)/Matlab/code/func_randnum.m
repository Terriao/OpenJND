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