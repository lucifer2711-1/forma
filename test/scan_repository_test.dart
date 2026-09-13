import 'package:flutter_test/flutter_test.dart';

import 'package:forma/core/models/scan.dart';

import 'scan_repository_memory.dart';

void main() {
  test('memory repository honors the ScanRepository contract', () async {
    final repo = MemoryScanRepository();
    final emissions = <List<Scan>>[];
    final subscription = repo.watchAll().listen(emissions.add);

    final scan = Scan(
      id: 's1',
      name: 'Test Mug',
      createdAt: DateTime(2026, 3, 15),
      status: ScanStatus.ready,
    );
    await repo.save(scan);

    final fetched = await repo.byId('s1');
    expect(fetched?.name, 'Test Mug');

    await repo.setFavorite('s1', isFavorite: true);
    expect((await repo.byId('s1'))!.isFavorite, isTrue);

    await repo.delete('s1');
    expect(await repo.byId('s1'), isNull);
    expect(emissions.last, isEmpty);

    await subscription.cancel();
    repo.dispose();
  });
}
