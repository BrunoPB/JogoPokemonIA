# Função para iniciar as variáveis de time como 0
def startGame
  for i in 27..33
    $game_variables[i] = 0
  end
end

# Função que adicionar um Pokemon na equipe adversária
def colocarNaEquipeAdversaria(pkmn)
  for i in 27..33
    if $game_variables[i] == 0
      $game_variables[i] = pkmn
      pbMessage(_INTL("Pokemon adicionado com sucesso."))
      break
    end
    if i == 32
      pbMessage(_INTL("A equipe adversária já está cheia."))
    end
  end
end

# Função para exluir toda a equipe adversária
def excluirEquipeAdversaria
  for i in 27..33
    $game_variables[i] = 0
  end
  pbMessage(_INTL("Equipe adversária excluída."))
end

# Função para criação dos times e iniciar batalha
def pbTrainerBattleCore(*args)
  outcomeVar = 1
  Events.onStartBattle.trigger(nil)

  # Criação do time do adversário
  foeTrainers    = []
  foeItems       = []
  foeEndSpeeches = []
  foeParty       = []
  foePartyStarts = []
  for arg in args
      trainer = pbLoadTrainer(arg[0],arg[1],arg[2])
      Events.onTrainerPartyLoad.trigger(nil,trainer)
      foeTrainers.push(trainer)
      foePartyStarts.push(foeParty.length)
      for i in 27..33 do
        if $game_variables[i] != 0
          foeParty.push(Pokemon.new($game_variables[27],100))
        end
      end
      foeEndSpeeches.push(arg[3] || trainer.lose_text)
  end

  # Criação do time do player
  playerTrainers    = [$Trainer]
  playerParty       = $Trainer.party
  playerPartyStarts = [0]

  # Criando cena de batalha
  scene = pbNewBattleScene
  battle = PokeBattle_Battle.new(scene,playerParty,foeParty,playerTrainers,foeTrainers)
  battle.party1starts = playerPartyStarts
  battle.party2starts = foePartyStarts
  battle.items        = foeItems
  battle.endSpeeches  = foeEndSpeeches
  pbPrepareBattle(battle)
  $PokemonTemp.clearBattleRules
  Audio.me_stop
  decision = 0

  # Iniciando batalha
  pbBattleAnimation(pbGetTrainerBattleBGM(foeTrainers),(battle.singleBattle?) ? 1 : 3,foeTrainers) {
    pbSceneStandby {
      decision = battle.pbStartBattle
    }
    pbAfterBattle(decision,false)
  }

  # Retornando resultado da batalha (1 se tiver ganhado, 2 se tiver perdido)
  Input.update
  pbSet(outcomeVar,decision)
  return decision
end