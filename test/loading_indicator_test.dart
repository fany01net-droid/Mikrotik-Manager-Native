import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fnet/widgets/loading_indicator_m3e.dart';

void main() {
  testWidgets('LoadingIndicatorM3E renders all 4 variants from demo snippet', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Column(
            children: [
              // 1. Uncontained
              const LoadingIndicatorM3E(size: 40),
              // 2. Contained in circle
              Builder(
                builder: (context) => Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: LoadingIndicatorM3E(
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // 3. Custom color
              const LoadingIndicatorM3E(size: 40, color: Colors.amber),
              // 4. In button
              IconButton.outlined(
                onPressed: () {},
                icon: const SizedBox(
                  width: 20,
                  height: 20,
                  child: LoadingIndicatorM3E(size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Initial render
    expect(find.byType(LoadingIndicatorM3E), findsNWidgets(4));

    // Verify it animates frames without throwing errors
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
