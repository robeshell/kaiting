import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/playback/native_position_gate.dart';

void main() {
  const duration = Duration(minutes: 4);

  test('normalizes positions into the playable range', () {
    final gate = NativePositionGate();

    expect(
      gate.accept(const Duration(milliseconds: -20), duration: duration),
      Duration.zero,
    );
    expect(
      gate.accept(const Duration(minutes: 8), duration: duration),
      duration,
    );
  });

  test('publishes a seek only after native confirmation', () {
    final gate = NativePositionGate();
    gate.beginSeek(const Duration(minutes: 2), duration: duration);

    expect(
      gate.accept(const Duration(seconds: 45), duration: duration),
      isNull,
    );
    expect(
      gate.accept(
        const Duration(minutes: 1, seconds: 59, milliseconds: 861),
        duration: duration,
      ),
      const Duration(minutes: 2),
    );
  });

  test('rejects a late pre-seek callback after forward seek', () {
    final gate = NativePositionGate();
    gate.beginSeek(const Duration(minutes: 2), duration: duration);
    gate.accept(const Duration(minutes: 2), duration: duration);

    expect(
      gate.accept(
        const Duration(minutes: 1, seconds: 59, milliseconds: 861),
        duration: duration,
      ),
      isNull,
    );
    expect(
      gate.accept(const Duration(minutes: 2, seconds: 1), duration: duration),
      const Duration(minutes: 2, seconds: 1),
    );
  });

  test('rejects the old high timestamp after backward seek', () {
    final gate = NativePositionGate();
    gate.beginSeek(const Duration(seconds: 30), duration: duration);
    gate.accept(const Duration(seconds: 30), duration: duration);

    expect(gate.accept(const Duration(minutes: 2), duration: duration), isNull);
    expect(
      gate.accept(const Duration(seconds: 31), duration: duration),
      const Duration(seconds: 31),
    );
  });
}
