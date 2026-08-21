import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:io';

// ─────────────────────────────────────────────
// Core Shimmer Animation
// ─────────────────────────────────────────────

class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFFFFFFF),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: [
                0.0,
                _controller.value - 0.15,
                _controller.value,
                _controller.value + 0.15,
                1.0,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────
// Skeleton Primitives
// ─────────────────────────────────────────────

class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLine({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonRect extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonRect({
    super.key,
    this.width,
    this.height = 80,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MinimumDuration wrapper
// Ensures skeleton shows for at least 300ms
// ─────────────────────────────────────────────

class SkeletonGuard extends StatefulWidget {
  /// The actual content widget builder (called when data is ready)
  final Widget? child;

  /// The skeleton to show while loading
  final Widget skeleton;

  /// Whether data is still loading
  final bool isLoading;

  /// Minimum time to show skeleton (ms)
  final int minimumMs;

  /// Timeout before showing network diagnostic prompt (ms)
  final int networkTimeoutMs;

  const SkeletonGuard({
    super.key,
    required this.child,
    required this.skeleton,
    required this.isLoading,
    this.minimumMs = 300,
    this.networkTimeoutMs = 20000,
  });

  @override
  State<SkeletonGuard> createState() => _SkeletonGuardState();
}

class _SkeletonGuardState extends State<SkeletonGuard> {
  bool _minTimeElapsed = false;
  Timer? _networkTimeoutTimer;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _startMinTimer();
    if (widget.isLoading) {
      _startNetworkTimeout();
    }
  }

  @override
  void didUpdateWidget(covariant SkeletonGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && oldWidget.isLoading) {
      // Loading finished — cancel timeout
      _networkTimeoutTimer?.cancel();
      _networkTimeoutTimer = null;
    } else if (widget.isLoading && !oldWidget.isLoading) {
      // Started loading again — restart timeout
      _dialogShown = false;
      _startNetworkTimeout();
    }
  }

  void _startMinTimer() async {
    await Future.delayed(Duration(milliseconds: widget.minimumMs));
    if (mounted) {
      setState(() => _minTimeElapsed = true);
    }
  }

  void _startNetworkTimeout() {
    _networkTimeoutTimer?.cancel();
    _networkTimeoutTimer = Timer(Duration(milliseconds: widget.networkTimeoutMs), () {
      if (mounted && widget.isLoading && !_dialogShown) {
        _dialogShown = true;
        _showNetworkPrompt();
      }
    });
  }

  void _showNetworkPrompt() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Loading is taking longer than expected'),
        content: const Text(
          'This may be caused by a slow or unstable network connection. Would you like to run a network diagnostic?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Run Diagnostic'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showNetworkDiagnostic();
            },
          ),
        ],
      ),
    );
  }

  void _showNetworkDiagnostic() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NetworkDiagnosticDialog(),
    );
  }

  @override
  void dispose() {
    _networkTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSkeleton = widget.isLoading || !_minTimeElapsed;
    return showSkeleton ? widget.skeleton : (widget.child ?? const SizedBox.shrink());
  }
}

// ─────────────────────────────────────────────
// Network Diagnostic Dialog
// ─────────────────────────────────────────────

class _NetworkDiagnosticDialog extends StatefulWidget {
  @override
  State<_NetworkDiagnosticDialog> createState() => _NetworkDiagnosticDialogState();
}

class _NetworkDiagnosticDialogState extends State<_NetworkDiagnosticDialog> {
  bool _running = true;
  final List<_DiagResult> _results = [];

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    // 1. DNS Resolution
    await _checkDns('google.com', 'DNS Resolution (google.com)');

    // 2. Firebase / Firestore
    await _checkDns('firestore.googleapis.com', 'Firestore Connectivity');

    // 3. General Internet (HTTP)
    await _checkHttp('https://www.google.com', 'Internet Access (HTTP)');

    // 4. Firebase Auth
    await _checkDns('identitytoolkit.googleapis.com', 'Firebase Auth');

    // 5. Firebase Storage
    await _checkDns('firebasestorage.googleapis.com', 'Firebase Storage');

    if (mounted) {
      setState(() => _running = false);
    }
  }

  Future<void> _checkDns(String host, String label) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _results.add(_DiagResult(
            label: label,
            success: result.isNotEmpty,
            detail: result.isNotEmpty
                ? 'Resolved: ${result.first.address}'
                : 'No addresses found',
          ));
        });
      }
    } on SocketException catch (e) {
      if (mounted) {
        setState(() {
          _results.add(_DiagResult(
            label: label,
            success: false,
            detail: 'DNS failed: ${e.message}',
          ));
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _results.add(_DiagResult(
            label: label,
            success: false,
            detail: 'Timed out (5s)',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results.add(_DiagResult(
            label: label,
            success: false,
            detail: 'Error: $e',
          ));
        });
      }
    }
  }

  Future<void> _checkHttp(String url, String label) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      final response = await request.close()
          .timeout(const Duration(seconds: 8));
      client.close();
      if (mounted) {
        setState(() {
          _results.add(_DiagResult(
            label: label,
            success: response.statusCode >= 200 && response.statusCode < 400,
            detail: 'HTTP ${response.statusCode}',
          ));
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _results.add(_DiagResult(
            label: label,
            success: false,
            detail: 'Request timed out',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results.add(_DiagResult(
            label: label,
            success: false,
            detail: 'Error: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}',
          ));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPassed = _results.isNotEmpty && _results.every((r) => r.success);
    final anyFailed = _results.any((r) => !r.success);

    return CupertinoAlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_running)
            const CupertinoActivityIndicator(radius: 10)
          else
            Icon(
              allPassed ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
              color: allPassed ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
              size: 20,
            ),
          const SizedBox(width: 8),
          Text(_running ? 'Running Diagnostics...' : (allPassed ? 'All Checks Passed' : 'Issues Detected')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ..._results.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  r.success ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
                  color: r.success ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.label,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        r.detail,
                        style: TextStyle(
                          fontSize: 11,
                          color: r.success ? CupertinoColors.systemGrey : CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
          if (_running && _results.length < 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const CupertinoActivityIndicator(radius: 8),
                  const SizedBox(width: 8),
                  Text(
                    'Checking... (${_results.length + 1}/5)',
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),
          if (!_running && anyFailed) ...[
            const SizedBox(height: 12),
            const Text(
              'Some services are unreachable. Please check your internet connection, VPN, or firewall settings.',
              style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
              textAlign: TextAlign.left,
            ),
          ],
        ],
      ),
      actions: [
        if (!_running)
          CupertinoDialogAction(
            child: const Text('Re-run'),
            onPressed: () {
              setState(() {
                _results.clear();
                _running = true;
              });
              _runDiagnostics();
            },
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _DiagResult {
  final String label;
  final bool success;
  final String detail;
  const _DiagResult({required this.label, required this.success, required this.detail});
}
