import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/modern_textfield.dart';

void main() {
  group('ModernTextField Widget Tests', () {
    testWidgets('renders text field with label and hint', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernTextField(
              label: 'Username',
              hint: 'Enter your username',
            ),
          ),
        ),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Enter your username'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('accepts user input and triggers onChanged', (WidgetTester tester) async {
      String inputValue = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernTextField(
              onChanged: (val) {
                inputValue = val;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'HelloWorld');
      expect(inputValue, 'HelloWorld');
    });

    testWidgets('renders password field and toggles visibility', (WidgetTester tester) async {
      bool isPasswordVisible = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return MaterialApp(
              home: Scaffold(
                body: ModernTextField(
                  isPassword: !isPasswordVisible,
                  suffixIcon: isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  onSuffixTap: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap suffix icon to toggle visibility
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('renders prefix icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernTextField(
              prefixIcon: Icons.email,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('displays error when validation fails', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: ModernTextField(
                validator: (val) => val == null || val.isEmpty ? 'Field required' : null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Field required'), findsNothing);

      // Trigger validation
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Field required'), findsOneWidget);
    });

    testWidgets('supports dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ModernTextField(
              label: 'Dark Mode Label',
            ),
          ),
        ),
      );

      expect(find.text('Dark Mode Label'), findsOneWidget);
      // No errors should be thrown, basic dark mode render success
    });
  });
}
