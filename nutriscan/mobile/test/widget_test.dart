import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';

void main() {
  testWidgets('theme builds with Material 3', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Text('NutriScan')),
    ));
    expect(find.text('NutriScan'), findsOneWidget);
  });

  test('grade colors cover all five grades', () {
    expect(AppTheme.gradeColors.keys, containsAll(['a', 'b', 'c', 'd', 'e']));
  });
}
