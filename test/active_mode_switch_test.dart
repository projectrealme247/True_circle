import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/widgets/active_mode/active_mode_switch.dart';

void main() {
  test('applicationsLabel omits count when there are no active applications', () {
    expect(ActiveModeSwitch.applicationsLabel(0), 'Applications');
  });

  test('applicationsLabel includes active application count', () {
    expect(ActiveModeSwitch.applicationsLabel(3), 'Applications (3)');
  });
}
