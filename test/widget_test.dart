// Neuralis — Widget smoke test di base.
//
// Verifica che l'app si avvii senza eccezioni e che il widget radice
// [NeuralisApp] sia renderizzabile nel framework di test.
//
// ⚠️ Test completi per feature specifiche saranno in test/widget/lcars/
// (Sezione 3) e test/unit/ (Sezione 1 e successive).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neuralis/app.dart';

void main() {
  testWidgets('NeuralisApp smoke test — avvio senza eccezioni', (WidgetTester tester) async {
    // Avvia l'app avvolta in ProviderScope (richiesto da Riverpod 3.x).
    await tester.pumpWidget(
      const ProviderScope(
        child: NeuralisApp(),
      ),
    );

    // Verifica che il titolo LCARS sia presente nella schermata placeholder.
    expect(find.text('NEURALIS'), findsOneWidget);
    expect(find.text('NEURAL LCARS OVERLAY SYSTEM'), findsOneWidget);
    expect(find.text('SISTEMA INIZIALIZZATO'), findsOneWidget);
  });
}
