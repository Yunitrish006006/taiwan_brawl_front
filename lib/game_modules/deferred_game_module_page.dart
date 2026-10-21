import 'package:flutter/material.dart';

/// Lazy-loads one game's bundled code without making the shell eager-load it.
class DeferredGameModulePage extends StatefulWidget {
  const DeferredGameModulePage({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;

  @override
  State<DeferredGameModulePage> createState() => _DeferredGameModulePageState();
}

class _DeferredGameModulePageState extends State<DeferredGameModulePage> {
  late final Future<void> _loading = widget.loadLibrary();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(body: Center(child: Text('Failed to load page')));
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return widget.builder(context);
    },
  );
}
