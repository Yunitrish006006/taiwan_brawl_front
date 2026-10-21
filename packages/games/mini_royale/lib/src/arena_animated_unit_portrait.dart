import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'battle_animation_cache_service.dart';
import 'royale_models.dart';

/// Plays a unit's base and event animations and reads the game-owned asset
/// cache. The caller supplies only the current animation data and fallback.
class MiniRoyaleAnimatedUnitPortrait extends StatefulWidget {
  const MiniRoyaleAnimatedUnitPortrait({
    super.key,
    required this.frames,
    required this.eventFrames,
    required this.eventKey,
    required this.fallbackUrl,
    required this.fallback,
  });

  final List<RoyaleCharacterAsset> frames;
  final List<RoyaleCharacterAsset> eventFrames;
  final String? eventKey;
  final String? fallbackUrl;
  final Widget fallback;

  @override
  State<MiniRoyaleAnimatedUnitPortrait> createState() =>
      _MiniRoyaleAnimatedUnitPortraitState();
}

class _MiniRoyaleAnimatedUnitPortraitState
    extends State<MiniRoyaleAnimatedUnitPortrait> {
  Timer? _timer;
  int _baseFrameIndex = 0;
  int _eventFrameIndex = 0;
  bool _playingEvent = false;
  String? _lastEventKey;

  @override
  void initState() {
    super.initState();
    _startEventIfNeeded();
    _scheduleNextFrame();
  }

  @override
  void didUpdateWidget(covariant MiniRoyaleAnimatedUnitPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    final baseChanged =
        _signature(oldWidget.frames) != _signature(widget.frames);
    final eventFramesChanged =
        _signature(oldWidget.eventFrames) != _signature(widget.eventFrames);
    if (baseChanged) {
      _baseFrameIndex = 0;
    }
    if (_playingEvent &&
        (widget.eventKey == null || widget.eventFrames.isEmpty)) {
      _playingEvent = false;
      _eventFrameIndex = 0;
    }
    if (_startEventIfNeeded() || baseChanged || eventFramesChanged) {
      _scheduleNextFrame();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _signature(List<RoyaleCharacterAsset> frames) => frames
      .map(
        (frame) =>
            '${frame.assetId}:${frame.animation}:${frame.direction}:'
            '${frame.frameIndex}:${frame.imageUrl}:${frame.durationMs}:'
            '${frame.loop}',
      )
      .join('|');

  bool _startEventIfNeeded() {
    final eventKey = widget.eventKey;
    if (eventKey == null ||
        widget.eventFrames.isEmpty ||
        eventKey == _lastEventKey) {
      return false;
    }
    _lastEventKey = eventKey;
    _playingEvent = true;
    _eventFrameIndex = 0;
    return true;
  }

  void _scheduleNextFrame() {
    _timer?.cancel();
    final activeFrames = _playingEvent ? widget.eventFrames : widget.frames;
    if (activeFrames.isEmpty) {
      return;
    }

    final activeIndex = _playingEvent ? _eventFrameIndex : _baseFrameIndex;
    final frame = activeFrames[activeIndex % activeFrames.length];
    if (!_playingEvent && activeFrames.length <= 1) {
      return;
    }
    if (!_playingEvent &&
        !frame.loop &&
        _baseFrameIndex >= activeFrames.length - 1) {
      return;
    }

    _timer = Timer(Duration(milliseconds: frame.durationMs), () {
      if (!mounted) {
        return;
      }
      if (_playingEvent) {
        setState(() {
          final nextIndex = _eventFrameIndex + 1;
          if (nextIndex >= widget.eventFrames.length) {
            _playingEvent = false;
            _eventFrameIndex = 0;
          } else {
            _eventFrameIndex = nextIndex;
          }
        });
        _scheduleNextFrame();
        return;
      }

      setState(() {
        final nextIndex = _baseFrameIndex + 1;
        final shouldLoop = frame.loop || nextIndex < widget.frames.length;
        _baseFrameIndex = shouldLoop
            ? nextIndex % widget.frames.length
            : widget.frames.length - 1;
      });
      _scheduleNextFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeFrames = _playingEvent && widget.eventFrames.isNotEmpty
        ? widget.eventFrames
        : widget.frames;
    final activeIndex = _playingEvent ? _eventFrameIndex : _baseFrameIndex;
    final activeAsset = activeFrames.isEmpty
        ? null
        : activeFrames[activeIndex % activeFrames.length];
    final cachedBytes = context
        .watch<BattleAnimationCacheService>()
        .bytesForAsset(activeAsset);
    if (cachedBytes != null) {
      return Image.memory(
        cachedBytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    }

    final frameUrl = activeAsset?.imageUrl;
    final imageUrl = frameUrl ?? widget.fallbackUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return widget.fallback;
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => widget.fallback,
    );
  }
}
