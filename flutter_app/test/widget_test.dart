import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/app/studydesk_app.dart';

void main() {
  testWidgets('renders StudyDesk shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudyDeskApp()));
    await tester.pumpAndSettle();

    expect(find.text('StudyDesk'), findsOneWidget);
    expect(find.text('Build Focus'), findsOneWidget);
  });
}
