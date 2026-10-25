import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';

void main() {
  group('sameGymName', () {
    test('ignores case and repeated or edge whitespace', () {
      expect(
        sameGymName(
          Gym(name: '  Main   Gym ', description: '  Downtown  '),
          Gym(name: 'main gym', description: 'downtown'),
        ),
        isTrue,
      );
    });

    test('requires matching descriptions', () {
      expect(
        sameGymName(
          Gym(name: 'Main Gym', description: 'Downtown'),
          Gym(name: 'Main Gym', description: 'Uptown'),
        ),
        isFalse,
      );
    });

    test('treats missing and empty descriptions as equivalent', () {
      expect(
        sameGymName(
          Gym(name: 'Main Gym'),
          Gym(name: 'Main Gym', description: ''),
        ),
        isTrue,
      );
    });
  });
}
