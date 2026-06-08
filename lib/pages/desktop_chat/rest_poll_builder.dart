import 'dart:async';

import 'package:flutter/material.dart';

/// Periodic fetch for Windows/Linux — drop-in for [StreamBuilder] UI builders.
class RestPollBuilder<T> extends StatefulWidget {
  const RestPollBuilder({
    super.key,
    required this.interval,
    required this.fetch,
    required this.builder,
  });

  final Duration interval;
  final Future<T> Function() fetch;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot) builder;

  @override
  State<RestPollBuilder<T>> createState() => _RestPollBuilderState<T>();
}

class _RestPollBuilderState<T> extends State<RestPollBuilder<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.interval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.fetch();
      if (mounted) {
        setState(() {
          _data = result;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  AsyncSnapshot<T> _snapshot() {
    if (_loading && _data == null) {
      return AsyncSnapshot<T>.waiting();
    }
    if (_error != null) {
      return AsyncSnapshot<T>.withError(
        ConnectionState.done,
        _error!,
        StackTrace.current,
      );
    }
    return AsyncSnapshot<T>.withData(ConnectionState.done, _data as T);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _snapshot());
  }
}
