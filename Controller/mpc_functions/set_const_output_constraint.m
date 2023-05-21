% Set output constraint matrix
function mpc = set_const_output_constraint(mpc,constraint)
    
dim = size(constraint);

if dim(2) ~= mpc.n_controlled_outputs + 1
    error("Width of constraint matrix should be n_outputs + 1")
end

% Extract submatrices for gradient and offset parts
Ga = constraint(:,1:end-1);
Gb = constraint(:,end);

G = zeros(dim(1)*mpc.Np,mpc.Np*mpc.n_controlled_outputs+1);
for i = 1:mpc.Np
    G((i-1)*dim(1) + 1:i*dim(1),(i-1)*(dim(2)-1) + 1:i*(dim(2)-1)) = Ga;
    G((i-1)*dim(1) + 1:i*dim(1),end) = Gb;
end

mpc.G_output_constraint = G;
