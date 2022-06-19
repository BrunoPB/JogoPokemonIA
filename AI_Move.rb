class PokeBattle_AI
  # Função para escolher e usar o melhor ataque possível
  def pbChooseMoves(idxBattler)
    user        = @battle.battlers[idxBattler]

    # Escolhe os ataques bons
    choices     = [] # Array de arrays, onde, para cada array interno 0: Index do ataque, 1: Score do ataque, 2: Alvo do ataque
    user.eachMoveWithIndex do |u,i|
      next if !@battle.pbCanChooseMove?(idxBattler,i,false)
      moveValue = calcMove(user,i)
      choices.push(moveValue)
    end

    # Seleciona e usa o melhor ataque dentre os que podem ser usados nessa situação
    bestMove = []
    choices.each_with_index do |c,i|
      next if !@battle.pbCanChooseMove?(idxBattler,i,false)
      if bestMove.length == 0 || c[1] > bestMove[1]
        bestMove = c
      end
    end
    if bestMove.length > 0
      useMove(idxBattler,bestMove[0],bestMove[2])
      return true
    end

    # Se chegar aqui, nenhum ataque pode ser usado por algum bloqueio ou limitação, nesse caso, deve-se usar Struggle
    @battle.pbAutoChooseMove(user.index)
    return false
  end

  # Função para usar um ataque
  def useMove(idxBattler,idxMove,target)
    @battle.pbRegisterMove(idxBattler,idxMove,false)
    @battle.pbRegisterTarget(idxBattler,target) if target >= 0
  end

  # Calcula o score de cada ataque e retorna um array com os ataques que tiveram um score positivo
  def calcMove(user,idxMove)
    moveValue = []
    move = user.moves[idxMove]
    target_data = move.pbTarget(user)

    if target_data.num_targets == 0 # Se o ataque afeta o próprio usuário ou a arena (altera o calculo de dano na função seguinte)
      score = getMoveScore(move,user,user)
      moveValue = [idxMove,score,-1]
    else # Se o ataque tem o oponente como alvo
      score = 0
      @battle.eachBattler do |b|
        next if !@battle.pbMoveCanTarget?(user.index,b.index,target_data)
        score += getMoveScore(move,user,b)
      end
      moveValue = [idxMove,score,-1]
    end

    return moveValue
  end

  # Função que calcula o score de um ataque baseado em diversas situações
  def getMoveScore(move,user,target)
    # Utiliza uma função padrão da biblioteca que retorna um score se faz algum sentido usar o ataque no momento
    score = pbGetMoveScoreFunctionCode(100,move,user,target,100)

    # Se o ataque for Last Resort e não pode ser usado (por algum motivo a função pbGetMoveScoreFunctionCode não lida com isso)
    if move.id === :LASTRESORT
      hasThisMove = false; hasOtherMoves = false; hasUnusedMoves = false
      user.eachMove do |m|
        hasThisMove    = true if m.id==@id
        hasOtherMoves  = true if m.id!=@id
        hasUnusedMoves = true if m.id!=@id && !user.movesUsed.include?(m.id)
      end
      if !hasThisMove || !hasOtherMoves || hasUnusedMoves
        score -= 80
      end
    end

    # Aumenta a score se o ataque der dano em alguns casos (não tem como ganhar se não der dano)
    if @battle.pbAbleNonActiveCount(user.idxOwnSide)==0 && user.hp < user.totalhp*3/4
      if !(@battle.pbAbleNonActiveCount(target.idxOwnSide)>0)
        if move.statusMove?
          score /= 1.5 if score > 0
          score *= 1.5 if score < 0
        elsif target.hp<=target.totalhp/2 # O alvo está com vida baixa
          score *= 1.5 if score > 0
          score /= 1.5 if score < 0
        end
      end
    end

    # Se o alvo estiver invunerável ou semi-invunerável
    if move.accuracy>0 &&
        (target.semiInvulnerable? || target.effects[PBEffects::SkyDrop]>=0)
      miss = true
      # Situações onde é possível acertar o alvo semi-invunerável
      miss = false if user.hasActiveAbility?(:NOGUARD) || target.hasActiveAbility?(:NOGUARD)
      if miss && pbRoughStat(user,:SPEED,skill)>pbRoughStat(target,:SPEED,skill)
        if target.effects[PBEffects::SkyDrop]>=0
          miss = false if move.hitsFlyingTargets?
        else
          if target.inTwoTurnAttack?("0C9","0CC","0CE")   # Fly, Bounce, Sky Drop
            miss = false if move.hitsFlyingTargets?
          elsif target.inTwoTurnAttack?("0CA")          # Dig
            miss = false if move.hitsDiggingTargets?
          elsif target.inTwoTurnAttack?("0CB")          # Dive
            miss = false if move.hitsDivingTargets?
          end
        end
      end
      score -= 80 if miss
    end

    # Se o pokemon estiver dormindo, tentar usar ataques que possam ser usados durante isso (Sleep Talk)
    if user.status == :SLEEP && !move.usableWhenAsleep?
      user.eachMove do |m|
        next unless m.usableWhenAsleep? # Sleep Talk
        score -= 60
        break
      end
    end

    # Se estiver congelado, usar ataque que descongelam
    if user.status == :FROZEN
      if move.thawsUser?
        score += 40
      else
        user.eachMove do |m|
          next unless m.thawsUser?
          score -= 60
          break
        end
      end
    end

    # Se o alvo estiver congelado, não usar ataque que descongelem-o
    if target.status == :FROZEN
      user.eachMove do |m|
        next if m.thawsUser?
        score -= 60
        break
      end
    end

    # Alterando score baseado no dano causado pelo ataque
    if move.damagingMove?
      score = getMoveScoreByDamage(score,move,user,target)
    else # Para ataques de status (que não causam dano)
      # Levar a accuracy em conta (função padrão da biblioteca)
      accuracy = pbRoughAccuracy(move,user,target,100)
      score *= accuracy/100.0 if score > 0
      score /= accuracy/100.0 if score < 0
    end

    score = score.to_i
    return score
  end

  # Função para calcular o score baseado no dano do ataque
  def getMoveScoreByDamage(score,move,user,target)
    # Se o alvo for imune ao ataque (geralmente por tipagem)
    if pbCheckMoveImmunity(score,move,user,target,100)
      score -= 80
    end

    # Usando funções padrão da biblioteca para calcular o dano e a accuracy aproximados
    baseDmg = pbMoveBaseDamage(move,user,target,100)
    realDamage = pbRoughDamage(move,user,target,100,baseDmg)
    accuracy = pbRoughAccuracy(move,user,target,100)
    realDamage *= accuracy/100.0

    # Diminuindo o dano se o ataque tomar mais de 1 turno para ser executado
    if move.chargingTurnMove? || move.function=="0C2"
      realDamage *= 2/3
    end

    # Calcular em relação a porcentagem de HP do alvo (faz mais sentido que calcular o dano absoluto)
    damagePercentage = realDamage*100.0/target.hp
    
    # Dando preferência para ataques letais (em caso de cura do pokemon adversário)
    damagePercentage += 40 if damagePercentage > 100

    score += damagePercentage.to_i
    return score
  end
end