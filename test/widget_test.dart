import 'package:flutter_test/flutter_test.dart';

import 'package:furshed/main.dart';

void main() {
  testWidgets('shows schedule search screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ScheduleApp());

    expect(find.text('Расписание ФА'), findsOneWidget);
    expect(find.text('Группы'), findsOneWidget);
    expect(find.text('Преподаватели'), findsOneWidget);
  });
}
