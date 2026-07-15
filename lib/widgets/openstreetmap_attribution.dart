import 'package:flutter/material.dart';

/// Visible OpenStreetMap attribution (ODbL requirement).
///
/// Shown near location/amenity features and in profile credits footer.
class OpenStreetMapAttribution extends StatelessWidget {
  const OpenStreetMapAttribution({
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final TextStyle? style;
  final TextAlign textAlign;

  static const label = '© OpenStreetMap contributors';

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: textAlign,
      style: style ??
          TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            height: 1.3,
          ),
    );
  }
}
