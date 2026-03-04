import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// An adaptive segmented control widget that provides a native iOS-style
/// segmented control with native iOS appearance on all platforms.
///
/// Supports both text labels and SF Symbols.
class AdaptiveSegmentedControl extends StatelessWidget {
  /// List of text labels for the segments.
  /// If provided, this will be used instead of icons.
  final List<String>? labels;

  /// List of SF Symbol names for iOS (only used when labels is empty).
  /// On non-iOS platforms, these will be ignored.
  final List<String>? sfSymbols;

  /// The index of the currently selected segment.
  final int selectedIndex;

  /// Callback function called when a segment is selected.
  /// The index of the selected segment is passed as a parameter.
  final ValueChanged<int>? onValueChanged;

  /// Color for icons (only used when sfSymbols is provided).
  final Color? iconColor;

  /// Background color of the segmented control.
  final Color? backgroundColor;

  /// Color of the selected segment background.
  final Color? selectedColor;

  /// Text color for unselected segments.
  final Color? unselectedTextColor;

  /// Text color for selected segment.
  final Color? selectedTextColor;

  AdaptiveSegmentedControl({
    Key? key,
    this.labels,
    this.sfSymbols,
    required this.selectedIndex,
    this.onValueChanged,
    this.iconColor,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedTextColor,
    this.selectedTextColor,
  })  : assert(
          (labels != null && labels.isNotEmpty) ||
              (sfSymbols != null && sfSymbols.isNotEmpty),
          'Either labels or sfSymbols must be provided',
        ),
        assert(
          labels == null ||
              sfSymbols == null ||
              labels.isEmpty ||
              sfSymbols.isEmpty,
          'Cannot provide both labels and sfSymbols',
        ),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    // Always use iOS-style segmented control (native on iOS, iOS-style on other platforms)
    return _buildIOSSegmentedControl();
  }

  Widget _buildIOSSegmentedControl() {
    final segmentCount = labels?.length ?? sfSymbols!.length;

    return CupertinoSlidingSegmentedControl<int>(
      groupValue: selectedIndex,
      onValueChanged: (value) {
        if (value != null && onValueChanged != null) {
          onValueChanged!(value);
        }
      },
      children: Map.fromIterable(
        List.generate(segmentCount, (index) => index),
        key: (index) => index,
        value: (index) {
          if (labels != null && labels!.isNotEmpty) {
            // Use text labels
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                labels![index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          } else if (sfSymbols != null && sfSymbols!.isNotEmpty) {
            // Use SF Symbols mapped to CupertinoIcons
            final iconData = _mapSFSymbolToCupertinoIcon(sfSymbols![index]);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                iconData,
                size: 20,
                color: iconColor ?? CupertinoColors.systemBlue,
              ),
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }

  IconData _mapSFSymbolToCupertinoIcon(String sfSymbol) {
    // Map SF Symbol names to CupertinoIcons (Flutter's SF Symbol equivalents)
    final iconMap = {
      'house.fill': CupertinoIcons.house_fill,
      'person.fill': CupertinoIcons.person_fill,
      'gear': CupertinoIcons.gear_alt,
      'gearshape.fill': CupertinoIcons.gear_alt_fill,
      'message.fill': CupertinoIcons.chat_bubble_fill,
      'envelope.fill': CupertinoIcons.mail_solid,
      'megaphone.fill': CupertinoIcons.speaker_2_fill,
      'house': CupertinoIcons.house,
      'person': CupertinoIcons.person,
      'message': CupertinoIcons.chat_bubble,
      'envelope': CupertinoIcons.mail,
      'megaphone': CupertinoIcons.speaker_2,
    };

    return iconMap[sfSymbol] ?? CupertinoIcons.circle;
  }
}
