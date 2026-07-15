import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/widgets/listing_creation/location_pin_field.dart';

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.initialEpoch,
    required this.initialLabel,
    required this.pinLat,
    required this.pinLon,
  });

  final int initialEpoch;
  final String? initialLabel;
  final double pinLat;
  final double pinLon;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int epoch;
  String? externalLabel;
  late double pinLat;
  late double pinLon;

  @override
  void initState() {
    super.initState();
    epoch = widget.initialEpoch;
    externalLabel = widget.initialLabel;
    pinLat = widget.pinLat;
    pinLon = widget.pinLon;
  }

  void clearExternalLocation() {
    setState(() {
      epoch++;
      externalLabel = null;
    });
  }

  void applyExternalLabel(String label) {
    setState(() {
      epoch++;
      externalLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LocationPinField(
      pinLat: pinLat,
      pinLon: pinLon,
      externalLocationEpoch: epoch,
      externalLocationLabel: externalLabel,
      onPinPlaced: (_, __) {},
    );
  }
}

void main() {
  testWidgets('external epoch clears search and confirmation labels', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_HarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Harness(
            key: harnessKey,
            initialEpoch: 0,
            initialLabel: null,
            pinLat: 53.365,
            pinLon: -6.228,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Clontarf, Dublin 3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Clontarf, Dublin 3'), findsOneWidget);

    harnessKey.currentState!.clearExternalLocation();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Clontarf, Dublin 3'), findsNothing);
    expect(find.textContaining('Location confirmed — Clontarf'), findsNothing);
  });

  testWidgets('external epoch applies resolved GPS label', (tester) async {
    final harnessKey = GlobalKey<_HarnessState>();
    const gpsLabel = 'Main Street, Drumcondra, Dublin 9, D09 X123';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Harness(
            key: harnessKey,
            initialEpoch: 1,
            initialLabel: null,
            pinLat: 53.371,
            pinLon: -6.256,
          ),
        ),
      ),
    );

    harnessKey.currentState!.applyExternalLabel(gpsLabel);
    await tester.pump();

    expect(find.text(gpsLabel), findsOneWidget);
    expect(
      find.text('Location confirmed — $gpsLabel'),
      findsOneWidget,
    );
  });
}
