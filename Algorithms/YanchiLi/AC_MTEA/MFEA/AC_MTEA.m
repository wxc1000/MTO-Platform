classdef AC_MTEA < Algorithm

    properties (SetAccess = private)
        pT = 0.3;
        operator_list = ["GA", "DE"];
        GA_mu = 10 % 模拟二进制交叉的染色体长度
        GA_pM = 0.1 % 变异概率
        GA_sigma = 0.02 % 高斯变异的标准差
        DE_F = 0.5
        DE_pCR = 0.9
    end

    methods

        function parameter = getParameter(obj)

            string_format = '%s';

            for o = 2:length(obj.operator_list)
                string_format = [string_format, '/%s'];
            end

            operator_string = sprintf(string_format, obj.operator_list);

            parameter = {'Operator_list GA/DE', operator_string, ...
                        'mu: GA SBX Crossover length', num2str(obj.GA_mu), ...
                        'pM: GA Mutation Probability', num2str(obj.GA_pM), ...
                        'sigma: GA Mutation Sigma', num2str(obj.GA_sigma), ...
                        'F: DE Mutation Factor', num2str(obj.DE_F), ...
                        'pCR: DE Crossover Probability', num2str(obj.DE_pCR)};
        end

        function obj = setParameter(obj, parameter_cell)
            count = 1;
            obj.operator_list = string(split(parameter_cell{count}, '/')); count = count + 1;
            obj.GA_mu = str2num(parameter_cell{count}); count = count + 1;
            obj.GA_pM = str2num(parameter_cell{count}); count = count + 1;
            obj.GA_sigma = str2double(parameter_cell{count}); count = count + 1;
            obj.DE_F = str2double(parameter_cell{count}); count = count + 1;
            obj.DE_pCR = str2double(parameter_cell{count}); count = count + 1;
        end

        function data = run(obj, Tasks, pre_run_list)
            obj.setPreRun(pre_run_list);
            tic
            archive_num = 2 * obj.pop_size; % 存档大小
            no_of_tasks = length(Tasks); % 任务数量

            if mod(obj.pop_size, no_of_tasks) ~= 0
                obj.pop_size = obj.pop_size + no_of_tasks - mod(obj.pop_size, no_of_tasks);
            end

            sub_pop = int32(obj.pop_size / no_of_tasks);
            D = zeros(1, no_of_tasks); % 每个任务解的维数
            population = {};
            archive = {};
            TotalEvaluations = 0;

            % initialize
            for t = 1:no_of_tasks
                D(t) = Tasks(t).dims;

                for i = 1:sub_pop
                    population{t}(i) = Chromosome_AC_MTEA();
                    population{t}(i) = initialize(population{t}(i), D(t));
                    [population{t}(i), calls] = evaluate(population{t}(i), Tasks(t));
                    TotalEvaluations = TotalEvaluations + calls;
                end

                archive{t}(1:sub_pop) = population{t};
                convergence(t, 1) = min([population{t}.fitness]);
            end

            % main loop
            iter = 1;

            while iter < obj.iter_num && TotalEvaluations < obj.eva_num
                iter = iter + 1;

                for t = 1:no_of_tasks

                    switch obj.operator_list(t)
                        case 'GA'
                            child = obj.operator_GA(population{t}, D(t), obj.GA_mu, obj.GA_pM, obj.GA_sigma);
                        case 'DE'
                            child = obj.operator_DE(population{t}, obj.DE_F, obj.DE_pCR);
                    end

                    for i = 1:length(population{t})
                        % 函数值评价
                        [child(i), calls] = evaluate(child(i), Tasks(t));
                        TotalEvaluations = TotalEvaluations + calls;
                    end

                    % transfer individuals
                    % TODO

                    % selection
                    intpopulation(1:length(population{t})) = population{t};
                    intpopulation(length(population{t}) + 1:length(population{t}) + length(child)) = child;
                    [~, y] = sort([population{t}.fitness]);
                    intpopulation = intpopulation(y);
                    convergence(t, iter) = population{t}(1).fitness;
                    population{t} = intpopulation(1:sub_pop);

                    % update archive
                    if iter == 2
                        archive{t}(sub_pop + 1:archive_num) = population{t};
                    else
                        % 随机选取U(1,n/2)个个体更新archive
                        update_pop_idx = randperm(length(population{i}));
                        update_pop_idx = update_idx(1:randi([1, ceil(length(population{i}) / 2)]));
                        update_archive_idx = randperm(length(archive{i}));
                        update_archive_idx = update_archive_idx(1:length(update_pop_idx));
                        archive{t}(update_archive_idx) = population{t}(update_pop_idx);
                    end

                end

                data.clock_time = toc;
            end

        end

        function child = operator_GA(obj, population, D, mu, pM, sigma)
            indorder = randperm(length(population));
            count = 1;

            for i = 1:ceil(length(population) / 2)
                p1 = indorder(i);
                p2 = indorder(i + fix(length(population) / 2));
                child(count) = Chromosome_AC_MTEA();
                child(count + 1) = Chromosome_AC_MTEA();
                u = rand(1, D);
                cf = zeros(1, D);
                cf(u <= 0.5) = (2 * u(u <= 0.5)).^(1 / (mu + 1));
                cf(u > 0.5) = (2 * (1 - u(u > 0.5))).^(-1 / (mu + 1));
                child(count) = crossover(child(count), population(p1), population(p2), cf);
                child(count + 1) = crossover(child(count + 1), population(p2), population(p1), cf);

                if rand(1) < pM
                    child(count) = mutate(child(count), child(count), D, sigma);
                    child(count + 1) = mutate(child(count + 1), child(count + 1), D, sigma);
                end

                count = count + 2;
            end

        end

        function child = operator_DE(obj, population, F, pCR)
            count = 1;

            for i = 1:ceil(length(population))
                x = population(i).rnvec; % 提取个体位置
                A = randperm(sub_pop);

                A(A == i) = []; % 当前个体所排位置腾空（产生变异中间体时当前个体不参与）
                p1 = A(1);
                p2 = A(mod(2 - 1, length(A)) + 1);
                p3 = A(mod(3 - 1, length(A)) + 1);
                % 变异操作 Mutation
                % beta=unifrnd(beta_min,beta_max,VarSize); % 随机产生缩放因子
                y = population(p1).rnvec + F * (population(p2).rnvec - population(p3).rnvec); % 产生中间体
                % 防止中间体越界
                y = max(y, lb);
                y = min(y, ub);

                z = zeros(size(x)); % 初始化一个新个体
                j0 = randi([1, numel(x)]); % 产生一个伪随机数，即选取待交换维度编号

                for j = 1:numel(x) % 遍历每个维度

                    if j == j0 || rand <= pCR % 如果当前维度是待交换维度或者随机概率小于交叉概率
                        z(j) = y(j); % 新个体当前维度值等于中间体对应维度值
                    else
                        z(j) = x(j); % 新个体当前维度值等于当前个体对应维度值
                    end

                end

                child(count) = Chromosome_MFDE();
                child(count).rnvec = z;

                count = count + 1;
            end

        end

    end

end
