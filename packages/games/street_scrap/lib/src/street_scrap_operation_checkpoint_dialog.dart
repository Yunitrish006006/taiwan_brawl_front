import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'street_scrap_localizations.dart';

/// A graybox interaction surface for one persisted craft checkpoint.
/// The action is scored locally; only its resulting option index is committed
/// to the saved craft operation by the caller.
class StreetScrapOperationCheckpointDialog extends StatefulWidget {
  const StreetScrapOperationCheckpointDialog({
    super.key,
    required this.operationId,
    required this.step,
    required this.prompt,
    required this.options,
    required this.correctOption,
    this.targetWidthMultiplier = 1,
    this.assistedControls = false,
  }) : assert(targetWidthMultiplier >= 1 && targetWidthMultiplier <= 2);

  final String operationId;
  final int step;
  final String prompt;
  final List<String> options;
  final int correctOption;
  final double targetWidthMultiplier;
  final bool assistedControls;

  @override
  State<StreetScrapOperationCheckpointDialog> createState() =>
      _StreetScrapOperationCheckpointDialogState();
}

class _StreetScrapOperationCheckpointDialogState
    extends State<StreetScrapOperationCheckpointDialog> {
  double _sliderValue = 0.5;
  bool _sliderTouched = false;
  bool _actionPerformed = false;
  bool _targetReached = false;
  double? _strokeMinX;
  double? _strokeMaxX;
  bool _strokeBandTouched = false;
  int? _result;

  int get _wrongOption => widget.options.asMap().keys.firstWhere(
    (index) => index != widget.correctOption,
  );

  bool get _usesAngleSlider =>
      widget.operationId == 'align' && widget.step == 1;

  bool get _usesSlider =>
      const {'mix', 'heat', 'filter', 'cook'}.contains(widget.operationId) ||
      _usesAngleSlider ||
      (widget.operationId == 'braid' && widget.step == 2);

  bool get _usesSwipe => const {'wash', 'coat'}.contains(widget.operationId);

  double get _targetValue => _usesAngleSlider ? 0.5 : (widget.step + 1) / 4;

  int? get _sliderDivisions => _usesAngleSlider
      ? 40
      : const {'heat', 'cook'}.contains(widget.operationId)
      ? 100
      : 4;

  double get _targetHalfWidth => _usesAngleSlider
      ? 0.25
      : const {'heat', 'cook'}.contains(widget.operationId)
      ? 0.1 * widget.targetWidthMultiplier
      : 0.1;

  void _finish() {
    final succeeded = _usesSlider
        ? _usesAngleSlider
              ? (_sliderValue - _targetValue).abs() <=
                    0.25 // ±10° on a ±20° scale.
              : const {'heat', 'cook'}.contains(widget.operationId)
              ? (_sliderValue - _targetValue).abs() <= _targetHalfWidth
              : (_sliderValue - _targetValue).abs() < 0.001
        : _targetReached;
    setState(() => _result = succeeded ? widget.correctOption : _wrongOption);
  }

  void _selectAssistTarget(int index) => setState(() {
    _actionPerformed = true;
    _targetReached = index == widget.step;
    if (_usesSlider) {
      _sliderTouched = true;
      _sliderValue = _usesAngleSlider
          ? [0.0, 0.5, 1.0][index]
          : (index + 1) / 4;
    }
  });

  String _zoneLabel(
    StreetScrapLocalizations strings,
    String operationId,
    int index,
  ) => switch (operationId) {
    'braid' => strings.text(
      [
        'checkpoint.canvas.zone.left',
        'checkpoint.canvas.zone.middle',
        'checkpoint.canvas.zone.right',
      ][index],
    ),
    'coat' => strings.text(
      [
        'checkpoint.canvas.zone.coatLeft',
        'checkpoint.canvas.zone.coatMiddle',
        'checkpoint.canvas.zone.coatRight',
      ][index],
    ),
    _ => strings.text(
      'checkpoint.canvas.stain',
      arguments: {'number': '${index + 1}'},
    ),
  };

  String _pointLabel(
    StreetScrapLocalizations strings,
    String operationId,
    int index,
  ) => switch (operationId) {
    'sew' => strings.text(
      'checkpoint.canvas.point.hole',
      arguments: {'number': '${index + 1}'},
    ),
    'cut' => strings.text(
      [
        'checkpoint.canvas.point.start',
        'checkpoint.canvas.point.bend',
        'checkpoint.canvas.point.end',
      ][index],
    ),
    'align' => strings.text(
      [
        'checkpoint.canvas.point.endpoint',
        'checkpoint.canvas.point.seam',
        'checkpoint.canvas.point.anchor',
      ][index],
    ),
    'strike' => strings.text(
      'checkpoint.canvas.point.strike',
      arguments: {'number': '${index + 1}'},
    ),
    _ => strings.text(
      [
        'checkpoint.canvas.point.base',
        'checkpoint.canvas.point.joint',
        'checkpoint.canvas.point.fix',
      ][index],
    ),
  };

  String _assistLabel(StreetScrapLocalizations strings, int index) {
    final number = index + 1;
    return switch (widget.operationId) {
      'sew' => strings.text(
        'checkpoint.assist.sew',
        arguments: {'number': '$number'},
      ),
      'cut' => strings.text(
        [
          'checkpoint.assist.cut.start',
          'checkpoint.assist.cut.bend',
          'checkpoint.assist.cut.end',
        ][index],
      ),
      'align' when _usesAngleSlider => strings.text(
        'checkpoint.assist.align.angle',
        arguments: {
          'degree': const ['−20', '0', '+20'][index],
        },
      ),
      'align' => strings.text(
        [
          'checkpoint.assist.align.endpoint',
          'checkpoint.assist.align.seam',
          'checkpoint.assist.align.anchor',
        ][index],
      ),
      'strike' => strings.text(
        'checkpoint.assist.strike',
        arguments: {'number': '$number'},
      ),
      'assemble' => strings.text(
        [
          'checkpoint.assist.assemble.base',
          'checkpoint.assist.assemble.joint',
          'checkpoint.assist.assemble.fix',
        ][index],
      ),
      'wash' => strings.text(
        'checkpoint.assist.wash',
        arguments: {'number': '$number'},
      ),
      'coat' => strings.text(
        [
          'checkpoint.assist.coat.left',
          'checkpoint.assist.coat.middle',
          'checkpoint.assist.coat.right',
        ][index],
      ),
      'braid' => strings.text(
        widget.step == 2
            ? [
                'checkpoint.assist.braid.tensionLow',
                'checkpoint.assist.braid.tensionTarget',
                'checkpoint.assist.braid.tensionHigh',
              ][index]
            : [
                'checkpoint.assist.braid.left',
                'checkpoint.assist.braid.middle',
                'checkpoint.assist.braid.right',
              ][index],
      ),
      _ => strings.text(
        'checkpoint.assist.target',
        arguments: {'number': '$number'},
      ),
    };
  }

  String _actionInstruction(StreetScrapLocalizations strings) => strings.text(
    _usesSwipe
        ? 'checkpoint.action.swipe'
        : _usesSlider
        ? 'checkpoint.action.slider'
        : 'checkpoint.action.tap',
  );

  String _shortActionLabel(StreetScrapLocalizations strings) => strings.text(
    _usesSwipe
        ? 'checkpoint.action.shortSwipe'
        : _usesSlider
        ? 'checkpoint.action.shortSlider'
        : 'checkpoint.action.shortTap',
  );

  IconData get _actionIcon => _usesSwipe
      ? Icons.gesture_rounded
      : _usesSlider
      ? Icons.tune_rounded
      : Icons.ads_click_rounded;

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final assistedControls =
        widget.assistedControls || MediaQuery.accessibleNavigationOf(context);
    return AlertDialog(
      scrollable: true,
      title: Text(
        strings.text(
          'checkpoint.title',
          arguments: {'step': '${widget.step + 1}'},
        ),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: widget.prompt,
              child: ExcludeSemantics(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_usesSlider)
              _buildSliderControl(context)
            else
              _buildGestureControl(context),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: assistedControls,
              title: Semantics(
                label: strings.text(
                  assistedControls
                      ? 'checkpoint.assist.active'
                      : 'checkpoint.assist.open',
                ),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.accessibility_new_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(strings.text('checkpoint.assist.short')),
                    ],
                  ),
                ),
              ),
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (var index = 0; index < 3; index++)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _result == null
                            ? () => _selectAssistTarget(index)
                            : null,
                        child: Text(_assistLabel(strings, index)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_result != null)
              Semantics(
                label: strings.text(
                  _result == widget.correctOption
                      ? 'checkpoint.result.success'
                      : 'checkpoint.result.miss',
                ),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _result == widget.correctOption
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: _result == widget.correctOption
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.text(
                          _result == widget.correctOption
                              ? 'checkpoint.result.shortSuccess'
                              : 'checkpoint.result.shortMiss',
                        ),
                        style: TextStyle(
                          color: _result == widget.correctOption
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Tooltip(
                message: _actionInstruction(strings),
                child: Semantics(
                  label: _actionInstruction(strings),
                  child: ExcludeSemantics(
                    child: Chip(
                      avatar: Icon(_actionIcon, size: 17),
                      label: Text(_shortActionLabel(strings)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.text('checkpoint.action.later')),
        ),
        FilledButton(
          onPressed:
              (_usesSlider ? _sliderTouched : _actionPerformed) &&
                  _result == null
              ? _finish
              : _result == null
              ? null
              : () => Navigator.pop(context, _result),
          child: Text(
            strings.text(
              _result == null
                  ? 'checkpoint.action.save'
                  : 'checkpoint.action.saveAndContinue',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderControl(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final step = '${widget.step + 1}';
    final label = _usesAngleSlider
        ? strings.text('checkpoint.slider.angle')
        : widget.operationId == 'braid'
        ? strings.text('checkpoint.slider.tension', arguments: {'step': step})
        : widget.operationId == 'cook' || widget.operationId == 'heat'
        ? strings.text(
            widget.targetWidthMultiplier > 1
                ? 'checkpoint.slider.fireExpanded'
                : 'checkpoint.slider.fire',
            arguments: {'step': step},
          )
        : strings.text('checkpoint.slider.generic', arguments: {'step': step});
    return Column(
      children: [
        SizedBox(
          height: 76,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: const [
                        Color(0xff555b61),
                        Color(0xff688b69),
                        Color(0xff688b69),
                        Color(0xff555b61),
                      ],
                      stops: [
                        0,
                        (_targetValue - _targetHalfWidth)
                            .clamp(0, 1)
                            .toDouble(),
                        (_targetValue + _targetHalfWidth)
                            .clamp(0, 1)
                            .toDouble(),
                        1,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * _targetValue - 14,
                  child: const Icon(
                    Icons.track_changes,
                    color: Color(0xffa8e6a8),
                    size: 28,
                  ),
                ),
                Slider(
                  value: _sliderValue,
                  divisions: _sliderDivisions,
                  onChanged: _result == null
                      ? (value) => setState(() {
                          _sliderValue = value;
                          _sliderTouched = true;
                        })
                      : null,
                ),
              ],
            ),
          ),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildGestureControl(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final zoneLabels = List.generate(
      3,
      (index) => _zoneLabel(strings, widget.operationId, index),
    );
    final pointLabels = List.generate(
      3,
      (index) => _pointLabel(strings, widget.operationId, index),
    );
    return Semantics(
      button: true,
      label: strings.text('checkpoint.gesture.label'),
      hint: strings.text(
        _usesSwipe
            ? 'checkpoint.gesture.hint.swipe'
            : 'checkpoint.gesture.hint.tap',
      ),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final target = _targetValue * constraints.maxWidth;
            final toleranceFraction = switch (widget.operationId) {
              'sew' || 'strike' => 0.12,
              'align' => 0.10,
              'assemble' => 0.10,
              _ => 0.10,
            };
            final targetRadius = constraints.maxWidth * toleranceFraction;
            final targetY = constraints.maxHeight * 0.54;
            final cutHitRadius = math.min(
              targetRadius,
              math.min(targetY, constraints.maxHeight - targetY) * 0.98,
            );
            final hasTapTarget = !_usesSwipe && !_usesSlider;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _usesSwipe
                  ? (details) => setState(() {
                      _actionPerformed = true;
                      _targetReached = false;
                      _strokeMinX = details.localPosition.dx;
                      _strokeMaxX = details.localPosition.dx;
                      _strokeBandTouched =
                          (details.localPosition.dy - constraints.maxHeight / 2)
                              .abs() <=
                          constraints.maxHeight * 0.12;
                    })
                  : null,
              onTapUp: _usesSwipe
                  ? null
                  : (details) {
                      final dx = details.localPosition.dx - target;
                      final dy =
                          details.localPosition.dy -
                          constraints.maxHeight * 0.54;
                      final tolerance =
                          constraints.maxWidth * toleranceFraction;
                      setState(() {
                        _actionPerformed = true;
                        _targetReached =
                            dx * dx + dy * dy <= tolerance * tolerance;
                      });
                    },
              onPanUpdate: _usesSwipe
                  ? (details) {
                      final x = details.localPosition.dx;
                      _strokeMinX = math.min(_strokeMinX ?? x, x).toDouble();
                      _strokeMaxX = math.max(_strokeMaxX ?? x, x).toDouble();
                      if ((details.localPosition.dy - constraints.maxHeight / 2)
                              .abs() <=
                          constraints.maxHeight * 0.12) {
                        _strokeBandTouched = true;
                      }
                      final zoneWidth = constraints.maxWidth / 3;
                      final zoneLeft = widget.step * zoneWidth;
                      final zoneRight = zoneLeft + zoneWidth;
                      final overlapStart = math.max(_strokeMinX ?? x, zoneLeft);
                      final overlapEnd = math.min(_strokeMaxX ?? x, zoneRight);
                      final covered = math.max(0.0, overlapEnd - overlapStart);
                      final requiredCoverage = widget.operationId == 'coat'
                          ? 0.8
                          : 1.0;
                      setState(
                        () => _targetReached =
                            _strokeBandTouched &&
                            covered >= zoneWidth * requiredCoverage,
                      );
                    }
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    key: const Key('street-scrap-operation-target'),
                    painter: _OperationTargetPainter(
                      operationId: widget.operationId,
                      step: widget.step,
                      zoneLabels: zoneLabels,
                      pointLabels: pointLabels,
                      targetRadius: targetRadius,
                      reached: _targetReached,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  if (hasTapTarget)
                    Positioned(
                      left: target - cutHitRadius,
                      top: targetY - cutHitRadius,
                      width: cutHitRadius * 2,
                      height: cutHitRadius * 2,
                      child: GestureDetector(
                        key: Key(
                          'street-scrap-${widget.operationId}-target-hit-area',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _actionPerformed = true;
                          _targetReached = true;
                        }),
                        child: Semantics(
                          button: true,
                          label: pointLabels[widget.step],
                          hint: strings.text('checkpoint.gesture.hint.tap'),
                          child: const ExcludeSemantics(
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OperationTargetPainter extends CustomPainter {
  const _OperationTargetPainter({
    required this.operationId,
    required this.step,
    required this.zoneLabels,
    required this.pointLabels,
    required this.targetRadius,
    required this.reached,
    required this.color,
  });

  final String operationId;
  final int step;
  final List<String> zoneLabels;
  final List<String> pointLabels;
  final double targetRadius;
  final bool reached;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xff202426);
    final panel = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(14)),
      background,
    );
    final target = Paint()
      ..color = reached ? const Color(0xff6ecb79) : color.withAlpha(110);
    final outline = Paint()
      ..color = reached ? const Color(0xffb6ffbd) : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (const {'wash', 'coat', 'braid'}.contains(operationId)) {
      final zoneWidth = size.width / 3;
      for (var i = 0; i < 3; i++) {
        final rect = Rect.fromLTWH(
          i * zoneWidth + 4,
          10,
          zoneWidth - 8,
          size.height - 20,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          Paint()..color = i == step ? target.color : const Color(0xff343b3d),
        );
        if (i == step) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            outline,
          );
        }
        _drawLabel(canvas, rect.center, zoneLabels[i]);
      }
      if (_usesSwipe) {
        final path = Path()
          ..moveTo(12, size.height / 2)
          ..lineTo(size.width - 12, size.height / 2);
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xffd7d6c9)
            ..strokeWidth = 4,
        );
      }
      return;
    }

    final y = size.height * 0.54;
    final guide = Paint()
      ..color = const Color(0xff9ba4a1)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.12, y),
      Offset(size.width * 0.88, y),
      guide,
    );
    for (var i = 0; i < 3; i++) {
      final x = size.width * (i + 1) / 4;
      final isTarget = i == step;
      final radius = isTarget ? targetRadius : size.width * 0.045;
      final center = Offset(x, y);
      if (operationId == 'assemble') {
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2.4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()..color = isTarget ? target.color : const Color(0xff454d4e),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          outline,
        );
      } else {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = isTarget ? target.color : const Color(0xff454d4e),
        );
        canvas.drawCircle(center, radius, outline);
        if (operationId == 'strike' && isTarget) {
          canvas.drawCircle(center, radius * 0.42, outline);
        }
      }
      _drawLabel(canvas, Offset(x, y + radius * 2.2), pointLabels[i]);
    }
  }

  bool get _usesSwipe => const {'wash', 'coat'}.contains(operationId);

  void _drawLabel(Canvas canvas, Offset center, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _OperationTargetPainter oldDelegate) =>
      oldDelegate.operationId != operationId ||
      oldDelegate.step != step ||
      oldDelegate.zoneLabels.join() != zoneLabels.join() ||
      oldDelegate.pointLabels.join() != pointLabels.join() ||
      oldDelegate.targetRadius != targetRadius ||
      oldDelegate.reached != reached ||
      oldDelegate.color != color;
}
