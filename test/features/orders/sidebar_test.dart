import 'dart:async';

import 'package:bayan_desktop/core/localization/locale_cubit.dart';
import 'package:bayan_desktop/core/navigation/app_section.dart';
import 'package:bayan_desktop/core/network/api_client.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/orders/data/repositories/orders_repository.dart';
import 'package:bayan_desktop/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:bayan_desktop/features/orders/presentation/widgets/app_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sidebar collapses to an icon rail and expands again', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.create();
    final bloc = OrdersBloc(repository: OrdersRepository(ApiClient()), preferences: prefs);
    var collapsed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider(create: (_) => LocaleCubit(prefs)),
          ],
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Row(
                children: [
                  AppSidebar(
                    section: AppSection.orders,
                    onSectionChanged: (_) {},
                    collapsed: collapsed,
                    onToggleCollapsed: () => setState(() => collapsed = !collapsed),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    double width() => tester.getSize(find.byType(AppSidebar)).width;
    expect(width(), 220);
    expect(find.text('Live Kanban'), findsOneWidget);

    await tester.tap(find.text('Collapse'));
    await tester.pump(const Duration(milliseconds: 100)); // mid-animation: must not overflow
    await tester.pump(const Duration(milliseconds: 300));
    expect(width(), 68);
    expect(find.text('Live Kanban'), findsNothing);
    expect(find.byTooltip('Live Kanban'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand menu'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(width(), 220);
    expect(find.text('Live Kanban'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
  });
}
