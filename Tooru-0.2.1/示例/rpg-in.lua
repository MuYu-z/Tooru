# 2019.4.17
# Project Tooru
# Evolutionary game example

title: 重复博弈
comment: 示例
game_type: rpg

# 进化博弈需要是一个对称博弈，关于非对称博弈，现有deepmind关于博弈分解之文章可供参考
payoffs:
  - [0,0,-1,0,0,1,1,-1,2]

# 对称博弈的收益矩阵是简化的，因为只有一种type。于此同时，如果采用函数表示，那么也只允许一个函数
# 错误的type与回报配置可能导致不可预测的行为

types: 
  - [Player, 2, 1, 1] # label players_num action_set payoff_idx

value_switch: 0

action_sets: 
  - [1, 2, 3] # label/value for value_switch on;

# Maybe range will be supported. BTW, continous range will eventurly turn to discreted.

stop: 1000
# 重复博弈扩展、策略部分以函数（string）的方式表达
strategies: 
# label mem function
  - tit for tat
  - bit=trust # useless for this example
  - |
    ret = 'coop'
    if bit ~= 'trust' then
      ret = 'def'
    end
    if COUNTER[#COUNTER]=='coop' then
      bit = 'trust'
    else
      bit = 'betray'
    end
    return ret

player_strategies:
  ["tit for tat", "tit for tat"]

# After process, all joined strings become arrays.
# ............., all key pairs become table.
