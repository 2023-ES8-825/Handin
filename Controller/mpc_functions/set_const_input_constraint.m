% Set input constraint matrix
function mpc = set_const_input_constraint(mpc,constraint)
    
dim = size(constraint);

if dim(2) ~= mpc.n_inputs + 1
    error("Width of constraint matrix should be n_inputs + 1")
end

% Extract submatrices for gradient and offset parts
Fa = constraint(:,1:end-1);
Fb = constraint(:,end);

F = zeros(dim(1)*mpc.Nc,mpc.Nc*mpc.n_inputs+1);
for i = 1:mpc.Nc
    F((i-1)*dim(1) + 1:i*dim(1),(i-1)*(dim(2)-1) + 1:i*(dim(2)-1)) = Fa;
    F((i-1)*dim(1) + 1:i*dim(1),end) = Fb;
end

% Make function of delta inputs
Fdim = size(F);
for i = 1:mpc.Nc
    for j = i+1:mpc.Nc
        F(:,(i-1)*(dim(2)-1) + 1:i*(dim(2)-1)) =...
            F(:,(i-1)*(dim(2)-1) + 1:i*(dim(2)-1)) +...
            F(:,(j-1)*(dim(2)-1) + 1:j*(dim(2)-1));
    end
end

mpc.F_input_constraint = F;