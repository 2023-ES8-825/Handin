function mpc = set_output_constraint(mpc, lowerbounds, upperbounds)
    Np = mpc.Np;
    Nz = mpc.n_controlled_outputs;
    
    G = zeros(Np*Nz*2, Np*Nz +1);

    for i = 1:Np
        for j = 1:Nz
            outputGain = [-1 0; 0 1]*[1; 1];
            for k = 1:2
                G((i-1)*Nz*2 + j*2-2 + k, (i-1)*Nz + j) = outputGain(k);
                switch k
                    case 1
                        G((i-1)*Nz*2 + j*2-2 + (k), end) = lowerbounds(i,j);
                    case 2
                        G((i-1)*Nz*2 + j*2-2 + (k), end) = -upperbounds(i,j);
                    otherwise
                end

            end
        end
    end
    mpc.G_output_constraint = G;
end