import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

class IOSNativeSearchButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const IOSNativeSearchButton({
    super.key,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                // Liquid Glass effect with semi-transparent background
                color: isActive
                    ? CupertinoColors.systemBlue.withOpacity(0.7)
                    : CupertinoColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isActive
                      ? CupertinoColors.systemBlue.withOpacity(0.8)
                      : CupertinoColors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.search,
                size: 20.0,
                color: isActive
                    ? CupertinoColors.white
                    : CupertinoColors.systemBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}








