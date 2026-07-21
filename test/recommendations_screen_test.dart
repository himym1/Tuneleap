import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/ui/screens/recommendations/recommendations_screen.dart';

void main() {
  test('RecommendationsScreen is a public widget type', () {
    expect(RecommendationsScreen, isNotNull);
    const widget = RecommendationsScreen();
    expect(widget, isA<RecommendationsScreen>());
  });
}
