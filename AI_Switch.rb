class PokeBattle_AI
  # Função que retorna true se deve-se trocar de Pokemon. Também chama a função de troca
  def pbEnemyShouldWithdraw?(idxBattler)
    switchScore = 0
    battler = @battle.battlers[idxBattler]

    # Calcular se há um caso extremo e o pokemon deve ser trocado
    shouldSwitch = forceSwitchSituation(idxBattler)

    # Calcular a pontuação de troca se não for um caso extremo
    if !shouldSwitch
      switchScore = calcSwitchScore(idxBattler)
    end

    # Se o score final tiver sido positivo ou deve haver troca forçada, trocar de pokemon
    if shouldSwitch || switchScore < 0
        return makeSwitch(idxBattler)
    end

    # Se chegou aqui, é porque a troca não deve ser feita
    return false
  end

  # Função que retorna true se deve haver uma troca forçada (situações extremas)
  def forceSwitchSituation(idxBattler)
    battler = @battle.battlers[idxBattler]
    # Se não puder usar nenhum ataque, trocar
    if !@battle.pbCanChooseAnyMove?(idxBattler)
      return true
    end

    # Se o pokemon for morrer para o Perish Song
    if battler.effects[PBEffects::PerishSong]==1
      return true
    end

    # Se nenhuma dessas situações ocorrer, não é um caso extremo
    return false
  end

  # Função para calcular o score do switch
  def calcSwitchScore(idxBattler)
    battler = @battle.battlers[idxBattler]
    switchScore = 0
    # Se estiver sob efeito de Poison ou Toxic (Toxic é um Poison que aumenta a cada rodada)
    if battler.status == :POISON && battler.statusCount > 0
      toxicHP = battler.totalhp/16
      nextToxicHP = toxicHP*(battler.effects[PBEffects::Toxic]+1)
      if battler.hp<=nextToxicHP && battler.hp>toxicHP*2
        switchScore -= 4
      end
    end

    # Se estiver sob efeito de Encore com um ataque ruim
    if battler.effects[PBEffects::Encore]>0
      idxEncoredMove = battler.pbEncoredMoveIndex
      if idxEncoredMove>=0
        scoreSum   = 0
        scoreCount = 0
        battler.eachOpposing do |b|
          scoreSum += getMoveScore(battler.moves[idxEncoredMove],battler,b)
          scoreCount += 1
        end
        if scoreCount>0 && scoreSum/scoreCount<=20
          switchScore -= 12
        end
      end
    end

    # Se o pokemon adversário não poder atacar na próxima rodada
    if @battle.pbSideSize(battler.index+1)==1 &&
        !battler.pbDirectOpposing.fainted?
      opp = battler.pbDirectOpposing
      if opp.effects[PBEffects::HyperBeam]>0 ||
          (opp.hasActiveAbility?(:TRUANT) && opp.effects[PBEffects::Truant])
        switchScore += 10
      end
    end

    # Se o pokemon adversário for de um tipo super efetivo
    typeTarget = battler.pbDirectOpposing(true).pbTypes();
    myType = battler.pbTypes()
    if Effectiveness.super_effective_type?(typeTarget[0],myType[0],myType[1])
      switchScore -= 5
    end
    if Effectiveness.super_effective_type?(typeTarget[1],myType[0],myType[1])
      switchScore -= 5
    end

    # Se o nosso pokemon tiver pelo menos 1 ataque super efetivo ao tipo do adversário
    numResist = 0
    battler.eachMoveWithIndex do |u,i|
      move = battler.moves[i]
      if Effectiveness.super_effective_type?(move.type,typeTarget[0],typeTarget[1]) && move.baseDamage > 0 # Caso de ter ataque super efetivo
        switchScore += 5
        if Effectiveness.super_effective_type?(move.type,typeTarget[0]) &&
          Effectiveness.super_effective_type?(move.type,typeTarget[1]) # Caso de ter um ataque 4x efetivo
          switchScore += 10
        end
        break
      end
      if Effectiveness.resistant_type?(move.type,typeTarget[0],typeTarget[1]) || move.baseDamage <= 0
        numResist += 1
      end
    end
    if numResist >= battler.moves.length # Caso de todos os ataques serem resistidos pelo adversário
      switchScore -= 15
    end

    return switchScore
  end
  
  # Função para fazer a troca de pokemon
  def makeSwitch(idxBattler)
    battler = @battle.battlers[idxBattler]
    list = []
    # Verificar quais pokemons podem trocar
    @battle.pbParty(idxBattler).each_with_index do |pkmn,i|
      next if !@battle.pbCanSwitch?(idxBattler,i)
      list.push(i)
    end

    if list.length > 0 # Quer dizer que há pokemons que podem entrar
      newPkmn = calcBestPkmn(idxBattler,list)
      return @battle.pbRegisterSwitch(idxBattler,newPkmn)
    end

    # Se chegou aqui, quer dizer que a troca não pode ser efetuada
    return false
  end

  # Função que calcula, dentre os pokemons que podem entrar em batalha, qual é o melhor nesse momento
  def calcBestPkmn(idxBattler, pkmns)
    if pkmns.length == 1
      return pkmns[0]
    end

    battler = @battle.battlers[idxBattler]
    scores = []
    pkmns.each_with_index do |p,i|
      scores.push(0)
      pkmnTypes = @battle.pbParty(idxBattler)[p].types
      typeTarget = battler.pbDirectOpposing(true).pbTypes();

      # Se o pokemon é super efetivo no adversário
      if Effectiveness.super_effective_type?(pkmnTypes[0],typeTarget[0],typeTarget[1])
        scores[i] += 1
      end
      if Effectiveness.super_effective_type?(pkmnTypes[1],typeTarget[0],typeTarget[1])
        scores[i] += 1
      end

      # Se o pokemon resiste o adversário
      if Effectiveness.resistant_type?(pkmnTypes[0],typeTarget[0],typeTarget[1])
        scores[i] += 1
      end
      if Effectiveness.resistant_type?(pkmnTypes[1],typeTarget[0],typeTarget[1])
        scores[i] += 1
      end

      # Se adversário é super efetivo no pokemon
      if Effectiveness.super_effective_type?(typeTarget[0],pkmnTypes[0],pkmnTypes[1])
        scores[i] -= 1
      end
      if Effectiveness.super_effective_type?(typeTarget[1],pkmnTypes[0],pkmnTypes[1])
        scores[i] -= 1
      end

      # Se o adversário resiste o pokemon
      if Effectiveness.resistant_type?(typeTarget[0],pkmnTypes[0],pkmnTypes[1])
        scores[i] -= 1
      end
      if Effectiveness.resistant_type?(typeTarget[1],pkmnTypes[0],pkmnTypes[1])
        scores[i] -= 1
      end
    end
    iMax = scores.each_with_index.max[1]
    return pkmns[iMax]
  end
end
  