import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/providers/search_provider.dart';
import 'package:navidrome_player/ui/screens/shell/app_shell.dart';

void main() {
  testWidgets('space reaches focused text fields', (tester) async {
    var invoked = false;
    final controller = TextEditingController(text: 'bad');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CallbackShortcuts(
          bindings: {const PlaybackSpaceActivator(): () => invoked = true},
          child: Scaffold(
            body: TextField(controller: controller, autofocus: true),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(invoked, isFalse);
    await tester.enterText(find.byType(TextField), 'bad boy');

    expect(controller.text, 'bad boy');
  });

  testWidgets('space remains a shortcut outside text fields', (tester) async {
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CallbackShortcuts(
          bindings: {const PlaybackSpaceActivator(): () => invoked = true},
          child: const Focus(autofocus: true, child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(invoked, isTrue);
  });

  test(
    'search error classification recognizes wrapped upstream rate limits',
    () {
      final request = RequestOptions(path: '/v1/music/search');
      final error = DioException.badResponse(
        statusCode: 502,
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 502,
          data: {'detail': 'upstream API error: 429'},
        ),
      );

      expect(classifySearchFailure(error), SearchFailure.rateLimited);
      expect(
        classifySearchFailure(
          DioException.badResponse(
            statusCode: 502,
            requestOptions: request,
            response: Response<dynamic>(
              requestOptions: request,
              statusCode: 502,
              data: {'detail': 'upstream API error: 503'},
            ),
          ),
        ),
        SearchFailure.unavailable,
      );
    },
  );
}
