% Set input rate constraint matrix
function mpc = set_const_input_rate_constraint(mpc,constraint)

dim = size(constraint);

if dim(2) ~= mpc.n_inputs + 1
    error("Width of constraint matrix should be n_inputs + 1")
end

% Extract submatrices for gradient and offset parts
Da = constraint(:,1:end-1);
Db = constraint(:,end);

D = zeros(dim(1)*mpc.Nc,mpc.Nc*mpc.n_inputs+1);
for i = 1:mpc.Nc
    D((i-1)*dim(1) + 1:i*dim(1),(i-1)*(dim(2)-1) + 1:i*(dim(2)-1)) = Da;
    D((i-1)*dim(1) + 1:i*dim(1),end) = Db;
end

mpc.D_input_rate_constraint = D;