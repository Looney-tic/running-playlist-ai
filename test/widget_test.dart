import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/app/app.dart';

void main() {
  testWidgets('App renders home screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: App()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Running Playlist AI'), findsOneWidget);
    expect(find.text('Home Screen'), findsOneWidget);
  });
}
