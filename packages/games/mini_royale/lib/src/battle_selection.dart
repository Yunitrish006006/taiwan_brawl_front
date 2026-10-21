import 'package:flutter/painting.dart';

import 'battle_rules.dart' as rules;
import 'arena_drop_target.dart';
import 'arena_targeting.dart';
import 'royale_models.dart';

/// Game-owned selection and affordability decisions for hand-to-battlefield play.
/// The App remains responsible for presenting localized feedback and dispatching
/// accepted actions to its room transport or host simulation.
class MiniRoyaleBattleSelection {
  const MiniRoyaleBattleSelection._();

  static List<RoyaleCard> resolve(
    Iterable<String> selectedIds,
    Iterable<RoyaleCard> hand,
  ) {
    final byId = {for (final card in hand) card.id: card};
    return selectedIds.map((id) => byId[id]).whereType<RoyaleCard>().toList();
  }

  static List<String> reconcile(
    Iterable<String> selectedIds,
    Iterable<RoyaleCard> hand,
  ) {
    final handIds = hand.map((card) => card.id).toSet();
    return selectedIds
        .where(handIds.contains)
        .take(rules.maxComboCards)
        .toList();
  }

  static MiniRoyaleSelectionResult toggle(
    Iterable<String> selectedIds,
    RoyaleCard card,
  ) {
    final selected = selectedIds.toList();
    if (card.isJob && selected.isNotEmpty) {
      return MiniRoyaleSelectionResult(
        selectedIds: selected,
        outcome: MiniRoyaleSelectionOutcome.jobMustBePlayedAlone,
      );
    }
    if (selected.contains(card.id)) {
      selected.remove(card.id);
      return MiniRoyaleSelectionResult(
        selectedIds: selected,
        outcome: MiniRoyaleSelectionOutcome.deselected,
      );
    }
    if (selected.length >= rules.maxComboCards) {
      return MiniRoyaleSelectionResult(
        selectedIds: selected,
        outcome: MiniRoyaleSelectionOutcome.maximumReached,
      );
    }
    selected.add(card.id);
    return MiniRoyaleSelectionResult(
      selectedIds: selected,
      outcome: MiniRoyaleSelectionOutcome.selected,
    );
  }

  static MiniRoyaleCardCosts costs(Iterable<RoyaleCard> cards) {
    var physical = 0;
    var spirit = 0;
    var money = 0;
    for (final card in cards) {
      if (card.usesMoney) {
        money += card.energyCost;
      } else if (card.usesSpiritEnergy) {
        spirit += card.energyCost;
      } else {
        physical += card.energyCost;
      }
    }
    return MiniRoyaleCardCosts(
      physical: physical,
      spirit: spirit,
      money: money,
    );
  }

  static MiniRoyaleComboError? validateCombo(Iterable<RoyaleCard> cards) {
    final combo = cards.toList();
    final hasJob = combo.any((card) => card.isJob);
    if (hasJob && combo.length != 1) {
      return MiniRoyaleComboError.jobMustBePlayedAlone;
    }
    final hasEquipment = combo.any((card) => card.isEquipment);
    final hasUnit = combo.any(
      (card) => card.type != 'equipment' && card.type != 'spell' && !card.isJob,
    );
    if (hasEquipment && !hasUnit) {
      return MiniRoyaleComboError.equipmentRequiresUnit;
    }
    return null;
  }

  static bool isJobOnlyCombo(Iterable<RoyaleCard> cards) {
    final combo = cards.toList();
    return combo.length == 1 && combo.single.isJob;
  }

  static MiniRoyalePlayCommandResult preparePlay({
    required Iterable<RoyaleCard> cards,
    required RoyalePlayerView? player,
    required double dropX,
    required double dropY,
    required String playerSide,
  }) {
    final combo = cards.toList(growable: false);
    if (combo.isEmpty) {
      return const MiniRoyalePlayCommandResult.rejected(
        MiniRoyalePlayRejection.emptyCombo,
      );
    }
    final comboError = validateCombo(combo);
    if (comboError != null) {
      return MiniRoyalePlayCommandResult.rejected(
        MiniRoyalePlayRejection.invalidCombo,
        comboError: comboError,
      );
    }
    final insufficientEnergy = insufficientEnergyType(player, combo);
    if (insufficientEnergy != null) {
      return MiniRoyalePlayCommandResult.rejected(
        MiniRoyalePlayRejection.insufficientEnergy,
        energyType: insufficientEnergy,
      );
    }
    if (!isJobOnlyCombo(combo) &&
        !miniRoyaleIsLegalDeployPoint(Offset(dropX, dropY))) {
      return const MiniRoyalePlayCommandResult.rejected(
        MiniRoyalePlayRejection.invalidDeploymentPoint,
      );
    }
    final lanePosition = miniRoyaleLanePosition(
      playerSide: playerSide,
      normalizedProgress: dropY,
    );
    return MiniRoyalePlayCommandResult.accepted(
      MiniRoyalePlayCommand(
        cards: combo,
        cardIds: combo.map((card) => card.id).toList(growable: false),
        dropX: dropX,
        dropY: dropY,
        lanePosition: lanePosition,
      ),
    );
  }

  static bool canAffordCard(RoyalePlayerView? player, RoyaleCard card) {
    if (player == null) return false;
    final available = card.usesMoney
        ? player.money.current
        : card.usesSpiritEnergy
        ? player.spiritEnergy.current
        : player.physicalEnergy.current;
    return available + 1e-6 >= card.energyCost;
  }

  static bool canAffordCards(
    RoyalePlayerView? player,
    Iterable<RoyaleCard> cards,
  ) {
    if (player == null) return false;
    final total = costs(cards);
    return player.physicalEnergy.current + 1e-6 >= total.physical &&
        player.spiritEnergy.current + 1e-6 >= total.spirit &&
        player.money.current + 1e-6 >= total.money;
  }

  static String? insufficientEnergyType(
    RoyalePlayerView? player,
    Iterable<RoyaleCard> cards,
  ) {
    if (player == null) return 'physical';
    final total = costs(cards);
    if (player.physicalEnergy.current + 1e-6 < total.physical) {
      return 'physical';
    }
    if (player.spiritEnergy.current + 1e-6 < total.spirit) return 'spirit';
    if (player.money.current + 1e-6 < total.money) return 'money';
    return null;
  }

  static MiniRoyaleCardDragPayload dragPayload(
    Iterable<String> selectedIds,
    Iterable<RoyaleCard> hand,
    RoyaleCard draggedCard,
  ) {
    final selected = resolve(selectedIds, hand);
    final useCombo =
        selected.length > 1 &&
        selected.any((card) => card.id == draggedCard.id);
    return MiniRoyaleCardDragPayload(
      cards: useCombo ? selected : [draggedCard],
      draggedCard: draggedCard,
      canDeploy: !draggedCard.isJob,
    );
  }
}

/// Mutable game-owned selection state for a battle hand. The host owns widget
/// lifecycle and transport effects; it does not own the selected-card domain
/// state or its reconciliation with authoritative hand snapshots.
class MiniRoyaleBattleSelectionState {
  final List<String> _selectedIds = [];

  List<String> get selectedIds => List.unmodifiable(_selectedIds);
  bool get isEmpty => _selectedIds.isEmpty;
  bool get isNotEmpty => _selectedIds.isNotEmpty;

  void clear() => _selectedIds.clear();

  void reconcileWithHand(Iterable<RoyaleCard> hand) {
    final reconciled = MiniRoyaleBattleSelection.reconcile(_selectedIds, hand);
    _selectedIds
      ..clear()
      ..addAll(reconciled);
  }

  MiniRoyaleSelectionResult toggle(RoyaleCard card) {
    final result = MiniRoyaleBattleSelection.toggle(_selectedIds, card);
    if (result.outcome == MiniRoyaleSelectionOutcome.selected ||
        result.outcome == MiniRoyaleSelectionOutcome.deselected) {
      _selectedIds
        ..clear()
        ..addAll(result.selectedIds);
    }
    return result;
  }

  List<RoyaleCard> resolve(Iterable<RoyaleCard> hand) =>
      MiniRoyaleBattleSelection.resolve(_selectedIds, hand);

  MiniRoyaleCardDragPayload dragPayload(
    Iterable<RoyaleCard> hand,
    RoyaleCard draggedCard,
  ) => MiniRoyaleBattleSelection.dragPayload(_selectedIds, hand, draggedCard);

  void remove(String cardId) => _selectedIds.remove(cardId);
}

enum MiniRoyaleSelectionOutcome {
  selected,
  deselected,
  maximumReached,
  jobMustBePlayedAlone,
}

enum MiniRoyaleComboError { jobMustBePlayedAlone, equipmentRequiresUnit }

enum MiniRoyalePlayRejection {
  emptyCombo,
  invalidCombo,
  insufficientEnergy,
  invalidDeploymentPoint,
}

class MiniRoyalePlayCommand {
  const MiniRoyalePlayCommand({
    required this.cards,
    required this.cardIds,
    required this.dropX,
    required this.dropY,
    required this.lanePosition,
  });

  final List<RoyaleCard> cards;
  final List<String> cardIds;
  final double dropX;
  final double dropY;
  final double lanePosition;
}

class MiniRoyalePlayCommandResult {
  const MiniRoyalePlayCommandResult._({
    this.command,
    this.rejection,
    this.comboError,
    this.energyType,
  });

  const MiniRoyalePlayCommandResult.accepted(MiniRoyalePlayCommand command)
    : this._(command: command);

  const MiniRoyalePlayCommandResult.rejected(
    MiniRoyalePlayRejection rejection, {
    MiniRoyaleComboError? comboError,
    String? energyType,
  }) : this._(
         rejection: rejection,
         comboError: comboError,
         energyType: energyType,
       );

  final MiniRoyalePlayCommand? command;
  final MiniRoyalePlayRejection? rejection;
  final MiniRoyaleComboError? comboError;
  final String? energyType;

  bool get isAccepted => command != null;
}

class MiniRoyaleSelectionResult {
  const MiniRoyaleSelectionResult({
    required this.selectedIds,
    required this.outcome,
  });

  final List<String> selectedIds;
  final MiniRoyaleSelectionOutcome outcome;
}

class MiniRoyaleCardCosts {
  const MiniRoyaleCardCosts({
    required this.physical,
    required this.spirit,
    required this.money,
  });

  final int physical;
  final int spirit;
  final int money;
}
