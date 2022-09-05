classdef OperatorMKT < Operator

    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 Yanchi Li. You are free to use the MTO-Platform for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "MTO-Platform" and cite
    % or footnote "https://github.com/intLyc/MTO-Platform"
    %--------------------------------------------------------------------------

    methods (Static)
        function [offspring, calls] = generate(population, Tasks, amp, mu, mum, cluster_model)
            Individual_class = class(population{1}(1));
            offspring = {};
            for t = 1:length(Tasks)
                indorder = randperm(length(population{t}));
                count = 1;
                for i = 1:ceil(length(population{t}) / 2)
                    p1 = indorder(i);
                    p2 = indorder(i + fix(length(population{t}) / 2));
                    offspring{t}(count) = feval(Individual_class);
                    offspring{t}(count + 1) = feval(Individual_class);

                    u = rand(1, max([Tasks.Dim]));
                    cf = zeros(1, max([Tasks.Dim]));
                    cf(u <= 0.5) = (2 * u(u <= 0.5)).^(1 / (mu + 1));
                    cf(u > 0.5) = (2 * (1 - u(u > 0.5))).^(-1 / (mu + 1));

                    if rand < amp(t)
                        offspring{t}(count) = OperatorMKT.crossover(offspring{t}(count), population{t}(p1), population{t}(p2), cf);
                        offspring{t}(count + 1) = OperatorMKT.crossover(offspring{t}(count + 1), population{t}(p2), population{t}(p1), cf);
                        offspring{t}(count) = OperatorMKT.mutate(offspring{t}(count), max([Tasks.Dim]), mum);
                        offspring{t}(count + 1) = OperatorMKT.mutate(offspring{t}(count + 1), max([Tasks.Dim]), mum);
                    else
                        % knowledge tansfer
                        current_mean = cluster_model(t).Nich_mean(population{t}(p1).cluster_num, :);
                        current_std = cluster_model(t).Nich_std(population{t}(p1).cluster_num, :);
                        offspring{t}(count).Dec = normrnd(current_mean, current_std);
                        offspring{t}(count + 1).Dec = normrnd(current_mean, current_std);
                    end

                    for x = count:count + 1
                        offspring{t}(x).Dec(offspring{t}(x).Dec > 1) = 1;
                        offspring{t}(x).Dec(offspring{t}(x).Dec < 0) = 0;
                    end
                    count = count + 2;
                end
            end
            calls = 0;
            for t = 1:length(Tasks)
                [offspring{t}, cal] = evaluate(offspring{t}, Tasks(t), 1);
                calls = calls + cal;
            end
        end

        function object = crossover(object, p1, p2, cf)
            % SBX - Simulated binary crossover
            object.Dec = 0.5 * ((1 + cf) .* p1.Dec + (1 - cf) .* p2.Dec);
        end

        function object = mutate(object, dim, mum)
            % Polynomial mutation
            Dec_temp = object.Dec;
            for i = 1:dim
                if rand(1) < 1 / dim
                    u = rand(1);
                    if u <= 0.5
                        del = (2 * u)^(1 / (1 + mum)) - 1;
                        Dec_temp(i) = object.Dec(i) + del * (object.Dec(i));
                    else
                        del = 1 - (2 * (1 - u))^(1 / (1 + mum));
                        Dec_temp(i) = object.Dec(i) + del * (1 - object.Dec(i));
                    end
                end
            end
            object.Dec = Dec_temp;
        end
    end
end
