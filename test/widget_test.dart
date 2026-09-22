import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:notificaciones_esm/models/birthday.dart';
import 'package:notificaciones_esm/widgets/birthday_form.dart';
import 'package:notificaciones_esm/widgets/birthday_list.dart';

void main() {
  setUpAll(() async {
    // `formatBirthDate` usa DateFormat con locale es.
    await initializeDateFormatting('es');
  });

  Widget wrapApp(Widget child) {
    return MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
      home: Scaffold(body: child),
    );
  }

  group('BirthdayForm', () {
    testWidgets('valida que el nombre no esté vacío', (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        wrapApp(
          SingleChildScrollView(
            child: BirthdayForm(
              onSubmit: (name, birthDate) async {
                submissions++;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Guardar y programar aviso'));
      await tester.pump();

      expect(find.text('Escribe el nombre de la persona'), findsOneWidget);
      expect(submissions, 0);
    });

    testWidgets('pide la fecha cuando solo hay nombre', (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        wrapApp(
          SingleChildScrollView(
            child: BirthdayForm(
              onSubmit: (name, birthDate) async {
                submissions++;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Ana');
      await tester.tap(find.text('Guardar y programar aviso'));
      await tester.pump();

      expect(find.text('Selecciona la fecha de nacimiento'), findsOneWidget);
      expect(submissions, 0);
    });

    testWidgets('permite elegir el día y envía nombre + fecha', (tester) async {
      String? sentName;
      DateTime? sentDate;
      await tester.pumpWidget(
        wrapApp(
          SingleChildScrollView(
            child: BirthdayForm(
              onSubmit: (name, birthDate) async {
                sentName = name;
                sentDate = birthDate;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Ana Pérez');
      await tester.tap(find.text('Selecciona una fecha'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar y programar aviso'));
      await tester.pumpAndSettle();

      expect(sentName, 'Ana Pérez');
      expect(sentDate, isNotNull);
    });

    testWidgets('en modo edición precarga los datos', (tester) async {
      final birthday = Birthday(
        id: 1,
        name: 'Luis',
        birthDate: DateTime(1995, 4, 12),
      );
      await tester.pumpWidget(
        wrapApp(
          SingleChildScrollView(
            child: BirthdayForm(
              initialBirthday: birthday,
              onSubmit: (name, birthDate) async {},
            ),
          ),
        ),
      );

      expect(find.text('Editar cumpleaños'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);
      expect(find.text('12 de abril de 1995'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
    });
  });

  group('BirthdaySliverList', () {
    testWidgets('renderiza cada cumpleaños con su próxima edad', (
      tester,
    ) async {
      final today = DateTime(2026, 9, 21);
      final birthdays = [
        Birthday(id: 1, name: 'Ana', birthDate: DateTime(1990, 9, 21)),
        Birthday(id: 2, name: 'Luis', birthDate: DateTime(1996, 1, 15)),
      ];

      await tester.pumpWidget(
        wrapApp(
          CustomScrollView(
            slivers: [
              BirthdaySliverList(
                birthdays: birthdays,
                onDelete: (_) {},
                today: today,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);
      expect(find.textContaining('Hoy cumple 36 años'), findsOneWidget);
      expect(find.textContaining('Cumple 31 años'), findsOneWidget);
    });

    testWidgets('muestra el estado vacío', (tester) async {
      await tester.pumpWidget(
        wrapApp(
          const CustomScrollView(
            slivers: [SliverToBoxAdapter(child: EmptyBirthdayList())],
          ),
        ),
      );

      expect(find.text('Todavía no hay cumpleaños guardados'), findsOneWidget);
    });
  });
}
