-- 2019.12.6
-- Project Tooru
-- Evolutionary game example

{
title = "进化博弈(重复博弈）",
comment = "示例",
game_type = "evo",

-- 进化博弈需要是一个对称博弈，关于非对称博弈，现有deepmind关于博弈分解之文章可供参考
payoffs = {{0,0,-1,0,0,1,1,-1,2}},

-- 对称博弈的收益矩阵是简化的，因为只有一种type。于此同时，如果采用函数表示，那么也只允许一个函数
-- 错误的type与回报配置可能导致不可预测的行为

types = {{"Player", 2, 1, 1}}, -- label players_num action_set/strategy payoff_idx

value_switch = 0,

action_sets = {{"swim", "fire", "shoot"}}, -- label/value for value_switch on;

-- Maybe range will be supported. BTW, continous range will eventurly turn to discreted.

-- After process, all joined strings become arrays.
-- ............., all key pairs become table.

-- 进化博弈论需要一些进化参数（可选）
selection_intensity = 1,
mutations_intensity = 0.0,
init_distri = {swim=0.425, fire=0.425, shoot=0.15},
simulation_population = 100,
}