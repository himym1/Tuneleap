import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';

void main() {
  testWidgets('uses mobile padding and transparent scaffold', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 200,
          child: ResponsivePageScaffold(
            body: SizedBox(
              key: Key('content'),
              width: double.infinity,
              height: 20,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.transparent,
    );
    expect(tester.getSize(find.byKey(const Key('content'))).width, 288);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('constrains wide content without changing desktop padding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 200));
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 1400,
          height: 200,
          child: ResponsiveContent(
            child: SizedBox(
              key: Key('content'),
              width: double.infinity,
              height: 20,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('content'))).width, 1136);
    await tester.binding.setSurfaceSize(null);
  });
}
