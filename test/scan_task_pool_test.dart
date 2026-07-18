import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/scanning/scan_task_pool.dart';

void main() {
  test('bounds concurrent scan work and preserves input order', () async {
    var active = 0;
    var peak = 0;
    final gates = <Completer<void>>[];

    final future = mapScanTasks<int, int>(
      <int>[1, 2, 3, 4, 5],
      maxConcurrency: 2,
      task: (value) async {
        active++;
        if (active > peak) peak = active;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        active--;
        return value * 10;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(gates, hasLength(2));
    gates[1].complete();
    await Future<void>.delayed(Duration.zero);
    expect(gates, hasLength(3));
    gates[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(gates, hasLength(4));
    gates[2].complete();
    gates[3].complete();
    await Future<void>.delayed(Duration.zero);
    expect(gates, hasLength(5));
    gates[4].complete();

    expect(await future, <int>[10, 20, 30, 40, 50]);
    expect(peak, 2);
  });

  test('rejects an invalid concurrency limit', () async {
    await expectLater(
      mapScanTasks<int, int>(
        <int>[1],
        maxConcurrency: 0,
        task: (value) async => value,
      ),
      throwsArgumentError,
    );
  });
}
