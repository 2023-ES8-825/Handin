function [Ay, Byu, Bydu] = generate_mpc_matrices(A,B,C,Nc,Np,opts)
% Lifts the recursive linear MPC formulation into set of large matrices

arguments
    A; B; C; Nc; Np;
    opts.sys_args = []
    opts.ts = []
end

% Ensure if A is a function, that Aargs is the right length
Aisfunc = class(A) == "function_handle";
Bisfunc = class(B) == "function_handle";
Cisfunc = class(C) == "function_handle";

if Aisfunc; Nx = size(A(ones(100,1)),1); else; Nx = size(A,1); end % Number of states
if Bisfunc; Nu = size(B(ones(100,1)),2); else; Nu = size(B,2); end % Number of inputs

% Handle case for identity C
if C == 'I'
    C = eye(Nx);
end

if Cisfunc; Ny = size(C(ones(100,1)),1); else; Ny = size(C,1); end % Number of outputs

% Check that if A and B take arguments, that sys_args is the right length
if Aisfunc && size(opts.sys_args,1) < Nc || Bisfunc && size(opts.sys_args,1) < Nc 
   error("A or B is a function, but sys_args is not the right size. " + ...
       "Expected %d rows got %d",Nc,size(opts.sys_args,1))
end

% Extend Aargs to entire prediction horizon
if Aisfunc && size(opts.sys_args,1) < Np
    for i = Nc+1:Np
        opts.sys_args(i,:) = opts.sys_args(Nc,:);
    end
end

% If A is a function, initialize as optimization expressions
if ( Aisfunc || Bisfunc ) && class(opts.sys_args) == "optim.problemdef.OptimizationExpression"
    Ax = optimexpr(Np*Nx,Nx);
    Bxu = optimexpr(Np*Nx,Nu);
    Bxdu = optimexpr(Np*Nx,Nc*Nu);
    Cdiag = optimexpr(Ny*Np,Nx*Np);
else 
    Ax = zeros(Np*Nx,Nx);
    Bxu = zeros(Np*Nx,Nu);
    Bxdu = zeros(Np*Nx,Nc*Nu);
    Cdiag = zeros(Ny*Np,Nx*Np);
end

% Generate A nd Bu matrices
for i = 1:Np

    if Aisfunc; Ai = A(opts.sys_args(i,:)); else; Ai = A; end
    if Bisfunc; Bi = B(opts.sys_args(i,:)); else; Bi = B; end
    if Cisfunc; Ci = C(opts.sys_args(i,:)); else; Ci = C; end

    if Aisfunc || Bisfunc

        sys = c2d(ss(Ai,Bi,Ci,0),opts.ts);
        Ai = sys.A;
        Bi = sys.B;
        Ci = sys.C;
    end

    % Generate A matrix
    if i == 1
        Ax(i*Nx-(Nx-1):i*Nx ,:) = Ai;
    else
        Ax(i*Nx-(Nx-1):i*Nx ,:) = Ai*Ax((i-1)*Nx-(Nx-1):(i-1)*Nx ,:);
    end

    % Generate Bu matrix
    if i == 1
        Bxu(i*Nx-(Nx-1):i*Nx ,:) = Bi;
    else
        Bxu(i*Nx-(Nx-1):i*Nx ,:) = Ai*Bxu((i-1)*Nx-(Nx-1):(i-1)*Nx ,:) + Bi;
    end

    % Generate Bdu matrix
    for j = 1:Nc
        if i == j
            Bxdu(i*Nx-(Nx-1):i*Nx ,j*Nu-(Nu-1):j*Nu) = Bi;
        elseif i > j
            Bxdu(i*Nx-(Nx-1):i*Nx ,j*Nu-(Nu-1):j*Nu) = Ai*Bxdu((i-1)*Nx-(Nx-1):(i-1)*Nx ,j*Nu-(Nu-1):j*Nu) + Bi;
        end
    end

    % Generate Cdiag entry
    Cdiag(i*Ny-(Ny-1):i*Ny ,i*Nx-(Nx-1):i*Nx) = Ci;
end

% Multiply with diagonal C matrix
Ay = Cdiag*Ax;
Byu = Cdiag*Bxu;
Bydu = Cdiag*Bxdu;