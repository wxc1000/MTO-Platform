classdef LSHADE44 < Algorithm
    % <Single> <Constrained>

    %------------------------------- Reference --------------------------------
    % @InProceedings{Polakova2017LSHADE44,
    %   title     = {L-shade with Competing Strategies Applied to Constrained Optimization},
    %   author    = {Poláková, Radka},
    %   booktitle = {2017 IEEE Congress on Evolutionary Computation (CEC)},
    %   year      = {2017},
    %   pages     = {1683-1689},
    %   doi       = {10.1109/CEC.2017.7969504},
    % }
    %--------------------------------------------------------------------------

    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 Yanchi Li. You are free to use the MTO-Platform for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "MTO-Platform" and cite
    % or footnote "https://github.com/intLyc/MTO-Platform"
    %--------------------------------------------------------------------------

    properties (SetAccess = private)
        p = 0.2
        H = 10
        arc_rate = 1
    end

    methods
        function Parameter = getParameter(obj)
            Parameter = {'p: 100p% top as pbest', num2str(obj.p), ...
                        'H: success memory size', num2str(obj.H), ...
                        'arc_rate: arcive size rate', num2str(obj.arc_rate)};
        end

        function obj = setParameter(obj, Parameter)
            i = 1;
            obj.p = str2double(Parameter{i}); i = i + 1;
            obj.H = str2double(Parameter{i}); i = i + 1;
            obj.arc_rate = str2double(Parameter{i}); i = i + 1;
        end

        function [res, p_min] = roulete(obj, cutpoints)
            % returns an integer from [1, length(cutpoints)] with probability proportional
            % to cutpoints(i)/ summa cutpoints
            st_num = length(cutpoints);
            ss = sum(cutpoints);
            p_min = min(cutpoints) / ss;
            cp(1) = cutpoints(1);
            for i = 2:st_num
                cp(i) = cp(i - 1) + cutpoints(i);
            end
            cp = cp / ss;
            res = 1 + fix(sum(cp < rand(1)));
        end

        function data = run(obj, Tasks, RunPara)
            sub_pop = RunPara(1); sub_eva = RunPara(2);
            convergeObj = {}; convergeCV = {}; eva_gen = {}; bestDec = {};

            for sub_task = 1:length(Tasks)
                Task = Tasks(sub_task);

                % initialize
                pop_init = sub_pop;
                pop_min = 4;
                [population, fnceval_calls, bestDec_temp, bestObj, bestCV] = initialize(IndividualLSHADE44, pop_init, Task, Task.Dim);
                convergeObj_temp(1) = bestObj;
                convergeCV_temp(1) = bestCV;
                eva_gen_temp(1) = fnceval_calls;

                % initialize Parameter
                st_num = 4;
                n0 = 2;
                delta = 1 / (5 * st_num);
                ni = zeros(1, st_num) + n0;

                is_used = zeros(1, st_num);
                for k = 1:st_num
                    H_idx{k} = 1;
                    MF{k} = 0.5 .* ones(obj.H, 1);
                    MCR{k} = 0.5 .* ones(obj.H, 1);
                end
                arc = IndividualLSHADE44.empty();

                generation = 1;
                while fnceval_calls < sub_eva
                    generation = generation + 1;

                    % Linear Population Size Reduction
                    pop_size = round((pop_min - pop_init) ./ sub_eva .* fnceval_calls + pop_init);

                    % calculate individual F and CR
                    for i = 1:length(population)
                        [st, pmin] = obj.roulete(ni);
                        if pmin < delta
                            ni = zeros(1, st_num) + n0;
                        end
                        idx = randi(obj.H);
                        uF = MF{st}(idx);
                        population(i).st = st;
                        population(i).F = uF + 0.1 * tan(pi * (rand - 0.5));
                        while (population(i).F <= 0)
                            population(i).F = uF + 0.1 * tan(pi * (rand - 0.5));
                        end
                        uCR = MCR{st}(idx);
                        population(i).F(population(i).F > 1) = 1;
                        population(i).CR = normrnd(uCR, 0.1);
                        population(i).CR(population(i).CR > 1) = 1;
                        population(i).CR(population(i).CR < 0) = 0;
                    end

                    % generation
                    union = [population, arc];
                    [offspring, calls] = OperatorLSHADE44.generate(Task, population, union, obj.p);
                    fnceval_calls = fnceval_calls + calls;

                    % selection
                    replace_cv = [population.CV] > [offspring.CV];
                    equal_cv = [population.CV] <= 0 & [offspring.CV] <= 0;
                    replace_obj = [population.Obj] > [offspring.Obj];
                    replace = (equal_cv & replace_obj) | replace_cv;

                    % calculate SF SCR
                    is_used = hist([population(replace).st], 1:st_num);
                    ni = ni + is_used;
                    for k = 1:st_num
                        k_idx = [population.st] == k;
                        SF = [population(replace & k_idx).F];
                        SCR = [population(replace & k_idx).CR];
                        dif = [population(replace & k_idx).CV] - [offspring(replace & k_idx).CV];
                        dif_obj = [population(replace & k_idx).Obj] - [offspring(replace & k_idx).Obj];
                        dif_obj(dif_obj < 0) = 0;
                        dif(dif <= 0) = dif_obj(dif <= 0);
                        dif = dif ./ sum(dif);
                        % update MF MCR
                        if ~isempty(SF)
                            MF{k}(H_idx{k}) = sum(dif .* (SF.^2)) / sum(dif .* SF);
                            MCR{k}(H_idx{k}) = sum(dif .* SCR);
                        else
                            MF{k}(H_idx{k}) = MF{k}(mod(H_idx{k} + obj.H - 2, obj.H) + 1);
                            MCR{k}(H_idx{k}) = MCR{k}(mod(H_idx{k} + obj.H - 2, obj.H) + 1);
                        end
                        H_idx{k} = mod(H_idx{k}, obj.H) + 1;
                    end

                    % update archive
                    arc = [arc, population(replace)];
                    if length(arc) > round(pop_size * obj.arc_rate)
                        arc = arc(randperm(length(arc), round(pop_size * obj.arc_rate)));
                    end

                    population(replace) = offspring(replace);

                    % Linear Population Size Reduction
                    [~, rank] = sortrows([[population.CV]', [population.Obj]'], [1, 2]);
                    population = population(rank(1:pop_size));

                    [bestObj_now, bestCV_now, best_idx] = min_FP([offspring.Obj], [offspring.CV]);
                    if bestCV_now < bestCV || (bestCV_now == bestCV && bestObj_now < bestObj)
                        bestObj = bestObj_now;
                        bestCV = bestCV_now;
                        bestDec_temp = offspring(best_idx).Dec;
                    end
                    convergeObj_temp(generation) = bestObj;
                    convergeCV_temp(generation) = bestCV;
                    eva_gen_temp(generation) = fnceval_calls;
                end
                convergeObj{sub_task} = convergeObj_temp;
                convergeCV{sub_task} = convergeCV_temp;
                eva_gen{sub_task} = eva_gen_temp;
                bestDec{sub_task} = bestDec_temp;
            end
            data.convergeObj = gen2eva(cell2matrix(convergeObj), cell2matrix(eva_gen));
            data.convergeCV = gen2eva(cell2matrix(convergeCV), cell2matrix(eva_gen));
            data.bestDec = uni2real(bestDec, Tasks);
        end
    end
end
