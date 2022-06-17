# Classe base da IA
class PokeBattle_AI

  # Init
  def initialize(battle)
    @battle = battle
  end

  # Função que retorna um número aleatório, onde 0 <= número < x
  def pbAIRandom(x); return rand(x); end

  # ???
  def pbStdDev(choices)
    sum = 0
    n   = 0
    choices.each do |c|
      sum += c[1]
      n   += 1
    end
    return 0 if n<2
    mean = sum.to_f/n.to_f
    varianceTimesN = 0
    choices.each do |c|
      next if c[1]<=0
      deviation = c[1].to_f-mean
      varianceTimesN += deviation*deviation
    end
    # Using population standard deviation
    # [(n-1) makes it a sample std dev, would be 0 with only 1 sample]
    return Math.sqrt(varianceTimesN/n)
  end
  
  # Função para decidir se deve trocar ou atacar. Tambem executa essas ações
  def pbDefaultChooseEnemyCommand(idxBattler)
      return if pbEnemyShouldWithdraw?(idxBattler)
      pbChooseMoves(idxBattler)
    end
  end
  