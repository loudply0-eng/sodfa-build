import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sodfa/main.dart';
import 'package:sodfa/services/sodfa_changelog_service.dart';

void main() {
  testWidgets('SODFA home and chat navigation render correctly', (tester) async {
    await tester.pumpWidget(const SodfaApp());

    expect(find.text('صدفة'), findsOneWidget);
    expect(find.text('كل تواصلك بمكان واحد'), findsOneWidget);
    expect(find.text('الدردشة'), findsOneWidget);

    await tester.tap(find.text('الدردشة'));
    await tester.pumpAndSettle();

    expect(find.text('المحادثات'), findsOneWidget);
    expect(find.text('أحمد علي'), findsOneWidget);

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('حول صدفة'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('حول صدفة'));
    await tester.pumpAndSettle();

    expect(find.text('ما هي صدفة؟'), findsOneWidget);
    expect(find.text('الموجود في هذه النسخة'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('سجل التغييرات'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('سجل التغييرات'));
    await tester.pumpAndSettle();

    expect(find.text('سجل تغييرات صدفة'), findsOneWidget);
    expect(find.text('الإصدار 0.1.8'), findsOneWidget);
    expect(find.text('الإصدار 0.1.6'), findsOneWidget);
    final entries = await SodfaChangelogService.load();
    expect(entries.map((entry) => entry.version), contains('0.1.5'));
    expect(
      entries
          .firstWhere((entry) => entry.version == '0.1.5')
          .changes,
      contains(
        'إضافة الدردشة العشوائية الصوتية والمرئية إلى خارطة تطوير صدفة؛ الاتصال العشوائي لم يُفعّل بعد.',
      ),
    );
  });
}
