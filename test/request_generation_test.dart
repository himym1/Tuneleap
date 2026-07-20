import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/utils/request_generation.dart';

void main() {
  test('only the latest request generation stays current', () {
    final requests = RequestGeneration();
    final first = requests.begin();
    final second = requests.begin();

    expect(requests.isCurrent(first), isFalse);
    expect(requests.isCurrent(second), isTrue);

    requests.invalidate();
    expect(requests.isCurrent(second), isFalse);
  });
}
