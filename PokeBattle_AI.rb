# Classe base da IA
class PokeBattle_AI

  # Init
  def initialize(battle)
    @battle = battle
  end
  
  # Função para decidir se deve trocar ou atacar. Tambem executa essas ações
  def pbDefaultChooseEnemyCommand(idxBattler)
      return if pbEnemyShouldWithdraw?(idxBattler)
      pbChooseMoves(idxBattler)
    end
  end
  