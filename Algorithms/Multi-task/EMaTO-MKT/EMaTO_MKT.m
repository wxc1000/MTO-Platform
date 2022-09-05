classdef EMaTO_MKT < Algorithm
    % <Many> <None>

    %------------------------------- Reference --------------------------------
    % @Article{Liang2021EMaTO-MKT,
    %   author   = {Liang, Zhengping and Xu, Xiuju and Liu, Ling and Tu, Yaofeng and Zhu, Zexuan},
    %   journal  = {IEEE Transactions on Evolutionary Computation},
    %   title    = {Evolutionary Many-task Optimization Based on Multi-source Knowledge Transfer},
    %   year     = {2021},
    %   pages    = {1-1},
    %   doi      = {10.1109/TEVC.2021.3101697},
    % }
    %--------------------------------------------------------------------------

    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 Yanchi Li. You are free to use the MTO-Platform for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "MTO-Platform" and cite
    % or footnote "https://github.com/intLyc/MTO-Platform"
    %--------------------------------------------------------------------------

    properties (SetAccess = private)
        mu = 2;
        mum = 5;
        amp0 = 0.9
        sigma = 1;
        K = 10;
        ktn = 5;
    end

    methods
        function Parameter = getParameter(obj)
            Parameter = {'mu: index of Simulated Binary Crossover', num2str(obj.mu), ...
                        'mum: index of polynomial mutation', num2str(obj.mum), ...
                        'amp0: initial amp', num2str(obj.amp0), ...
                        'sigma', num2str(obj.sigma), ...
                        'K: cluster num', num2str(obj.K), ...
                        'ktn: knowledge transfer tasks num', num2str(obj.ktn)};
        end

        function obj = setParameter(obj, Parameter)
            i = 1;
            obj.mu = str2double(Parameter{i}); i = i + 1;
            obj.mum = str2double(Parameter{i}); i = i + 1;
            obj.amp0 = str2double(Parameter{i}); i = i + 1;
            obj.sigma = str2double(Parameter{i}); i = i + 1;
            obj.K = str2double(Parameter{i}); i = i + 1;
            obj.ktn = str2double(Parameter{i}); i = i + 1;
        end

        function data = run(obj, Tasks, RunPara)
            sub_pop = RunPara(1); sub_eva = RunPara(2);
            eva_num = sub_eva * length(Tasks);

            % initialize
            [population, fnceval_calls, bestDec, bestObj] = initializeMT(IndividualMKT, sub_pop, Tasks, max([Tasks.Dim]) * ones(1, length(Tasks)));
            convergeObj(:, 1) = bestObj;

            generation = 1;
            while fnceval_calls < eva_num
                generation = generation + 1;

                % AMP
                if generation < 4
                    amp(1:length(Tasks)) = obj.amp0;
                else
                    temp1 = convergeObj(:, generation - 2)' - convergeObj(:, generation - 1)';
                    temp2 = convergeObj(:, generation - 3)' - convergeObj(:, generation - 2)';
                    amp = temp1 ./ (temp1 + temp2);
                    amp(isnan(amp)) = obj.amp0;
                end

                % calculate MMD
                difference = inf .* ones(length(Tasks));
                for t = 1:length(Tasks) - 1
                    dec_t = reshape([population{t}.Dec], length(population{t}(1).Dec), length(population{t}));
                    for k = t + 1:length(Tasks)
                        dec_k = reshape([population{k}.Dec], length(population{k}(1).Dec), length(population{k}));
                        difference(t, k) = obj.mmd(dec_t, dec_k, obj.sigma);
                        difference(k, t) = difference(t, k);
                    end
                end

                % clustering in LEKT
                [cluster_model, population] = obj.LEKT(population, length(Tasks), difference);

                % generation
                [offspring, calls] = OperatorMKT.generate(population, Tasks, amp, obj.mu, obj.mum, cluster_model);
                fnceval_calls = fnceval_calls + calls;

                % selection
                for t = 1:length(Tasks)
                    population{t} = [population{t}, offspring{t}];
                    [~, rank] = sort([population{t}.Obj]);
                    population{t} = population{t}(rank(1:sub_pop));
                    [bestObj_now, idx] = min([population{t}.Obj]);
                    if bestObj_now < bestObj(t)
                        bestObj(t) = bestObj_now;
                        bestDec{t} = population{t}(idx).Dec;
                    end
                end
                convergeObj(:, generation) = bestObj;
            end
            data.convergeObj = gen2eva(convergeObj);
            data.bestDec = uni2real(bestDec, Tasks);
        end

        function [clusterModel, population] = LEKT(obj, population, task_num, difference)
            clusterModel = struct;
            K = obj.K; %cluster numbers
            knowledge_task_num = obj.ktn; %number of tasks involved in knowledge transfer
            TempPopulation = population;
            dim = length(TempPopulation{1}(1).Dec);
            for i = 1:task_num
                clusterModel(i).Nich_mean = zeros(K, dim);
                clusterModel(i).Nich_std = zeros(K, dim);
                Subpop = TempPopulation{i};
                SubpopRnvec = reshape([Subpop.Dec], length(Subpop(1).Dec), length(Subpop))';
                temp_difference = difference(i, :);
                [~, index] = sort(temp_difference);
                %--------------Generate clusters by k-means--------------------------
                for j = 1:knowledge_task_num
                    Selected_population = population{index(j)};
                    Selected_matrix = reshape([Selected_population.Dec], length(Selected_population(1).Dec), length(Selected_population))';
                    SubpopRnvec = [SubpopRnvec; Selected_matrix];
                end
                [idx, ~] = kmeans(SubpopRnvec, K, 'Distance', 'cityblock', 'MaxIter', 30);
                for ii = 1:length(Subpop)
                    Subpop(ii).cluster_num = idx(ii);
                end
                population{i} = Subpop;
                %Generate mean and std for each cluster
                for k = 1:K
                    k_th_clu = SubpopRnvec(find(idx == k), :);
                    k_th_clu_Mean = mean(k_th_clu);
                    k_th_clu_Std = std(k_th_clu);
                    clusterModel(i).Nich_mean(k, :) = k_th_clu_Mean;
                    clusterModel(i).Nich_std(k, :) = k_th_clu_Std;
                end
            end
        end

        function mmd_XY = mmd(obj, X, Y, sigma)
            % Author：kailugaji
            % Maximum Mean Discrepancy 最大均值差异 越小说明X与Y越相似
            % X与Y数据维度必须一致, X, Y为无标签数据，源域数据，目标域数据
            % mmd_XY=mmd(X, Y, 4)
            % sigma is kernel size, 高斯核的sigma
            [N_X, ~] = size(X);
            [N_Y, ~] = size(Y);
            K = obj.rbf_dot(X, X, sigma); %N_X*N_X
            L = obj.rbf_dot(Y, Y, sigma); %N_Y*N_Y
            KL = obj.rbf_dot(X, Y, sigma); %N_X*N_Y
            c_K = 1 / (N_X^2);
            c_L = 1 / (N_Y^2);
            c_KL = 2 / (N_X * N_Y);
            mmd_XY = sum(sum(c_K .* K)) + sum(sum(c_L .* L)) - sum(sum(c_KL .* KL));
            mmd_XY = sqrt(mmd_XY);
        end

        function H = rbf_dot(obj, X, Y, deg)
            % Author：kailugaji
            % 高斯核函数/径向基函数 K(x, y)=exp(-d^2/sigma), d=(x-y)^2, 假设X与Y维度一样
            % Deg is kernel size,高斯核的sigma
            [N_X, ~] = size(X);
            [N_Y, ~] = size(Y);
            G = sum((X .* X), 2);
            H = sum((Y .* Y), 2);
            Q = repmat(G, 1, N_Y(1));
            R = repmat(H', N_X(1), 1);
            H = Q + R - 2 * X * Y';
            H = exp(-H / 2 / deg^2); %N_X*N_Y
        end
    end
end
