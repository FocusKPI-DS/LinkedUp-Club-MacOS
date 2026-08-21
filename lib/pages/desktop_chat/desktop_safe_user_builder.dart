import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';

/// On Windows/Linux uses a one-shot user fetch instead of a live Firestore
/// document stream (dozens of concurrent streams crash the native plugin).
class DesktopSafeUserBuilder extends StatelessWidget {
  const DesktopSafeUserBuilder({
    super.key,
    required this.userRef,
    required this.fetchOnce,
    required this.builder,
  });

  final DocumentReference userRef;
  final Future<UsersRecord> Function(DocumentReference ref) fetchOnce;
  final Widget Function(BuildContext context, UsersRecord? user) builder;

  static bool get useOnceFetch =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    if (useOnceFetch) {
      return FutureBuilder<UsersRecord>(
        future: fetchOnce(userRef),
        builder: (context, snapshot) =>
            builder(context, snapshot.data),
      );
    }
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(userRef),
      builder: (context, snapshot) =>
          builder(context, snapshot.data),
    );
  }

  /// Default fetch uses REST on Windows/Linux desktop.
  static Future<UsersRecord> defaultFetchUser(DocumentReference ref) =>
      fsGetUserOnce(ref);
}

/// Like [DesktopSafeUserBuilder] but polls on Windows/Linux so nav badges /
/// online status stay reasonably fresh without Firestore document streams.
class DesktopSafeUserPollBuilder extends StatefulWidget {
  const DesktopSafeUserPollBuilder({
    super.key,
    required this.userRef,
    required this.fetchOnce,
    required this.builder,
    this.pollInterval = const Duration(seconds: 30),
  });

  final DocumentReference userRef;
  final Future<UsersRecord> Function(DocumentReference ref) fetchOnce;
  final Widget Function(BuildContext context, UsersRecord? user) builder;
  final Duration pollInterval;

  @override
  State<DesktopSafeUserPollBuilder> createState() =>
      _DesktopSafeUserPollBuilderState();
}

class _DesktopSafeUserPollBuilderState extends State<DesktopSafeUserPollBuilder> {
  UsersRecord? _user;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (DesktopSafeUserBuilder.useOnceFetch) {
      _load();
      _timer = Timer.periodic(widget.pollInterval, (_) => _load());
    }
  }

  Future<void> _load() async {
    try {
      final user = await widget.fetchOnce(widget.userRef);
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopSafeUserBuilder.useOnceFetch) {
      return widget.builder(context, _user);
    }
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(widget.userRef),
      builder: (context, snapshot) =>
          widget.builder(context, snapshot.data),
    );
  }
}
