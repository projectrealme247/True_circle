import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/widgets/listing_creation/listing_creation_form.dart';
import 'package:true_circle/widgets/listing_creation/listing_creation_primitives.dart';

List<Object> drainExceptions(WidgetTester tester) {
  final out = <Object>[];
  Object? next;
  while ((next = tester.takeException()) != null) {
    out.add(next!);
  }
  return out;
}

void main() {
  testWidgets('ListingCollapsibleSection + SwitchListTile has no ink warning',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListingCollapsibleSection(
            title: '✨ Optional Enhancements',
            expanded: true,
            onExpandedChanged: (_) {},
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('I live in this property'),
                value: false,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final ex = drainExceptions(tester);
    expect(
      ex.where((e) => e.toString().contains('ink splashes may be invisible')),
      isEmpty,
      reason: ex.toString(),
    );
  });

  testWidgets(
    'resolved address panel CheckboxListTile has no ink warning',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListingCreationForm(
              initialListing: {
                'type': 'Rent',
                'property_sub_type': 'apartment',
                'latitude': 53.412,
                'longitude': -6.418,
                'property_location_identifier': '9 Hollywoodrath Park',
                'listing_area_key': 'dublin15',
                'eircode': 'D15 FT9N',
                // Avoid inherited-location lock so address panel mounts.
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(1);
      await tester.pumpAndSettle();

      // Unlock location if prefill locked (location string alone locks).
      final unlock = find.text('Edit location');
      if (unlock.evaluate().isNotEmpty) {
        await tester.tap(unlock.first);
        await tester.pumpAndSettle();
      }

      expect(
        find.textContaining("I don't want to display the exact address"),
        findsOneWidget,
      );

      final ex = drainExceptions(tester);
      expect(
        ex.where((e) => e.toString().contains('ink splashes may be invisible')),
        isEmpty,
        reason: ex.toString(),
      );
    },
  );
}
