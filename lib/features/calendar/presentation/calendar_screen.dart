import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/calendar/presentation/google_calendar_settings.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:dongine/shared/models/family_model.dart';

part 'calendar_presentation_helpers.dart';
part 'calendar_tab_calendar.dart';
part 'calendar_tab_todo.dart';
part 'calendar_tab_planner.dart';
part 'calendar_sheet_create_event.dart';
part 'calendar_sheet_create_todo.dart';
part 'calendar_sheet_create_planner.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  String _selectedCategory = '전체';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return familyAsync.when(
      data: (family) {
        if (family == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('캘린더')),
            body: const Center(child: Text('가족을 먼저 생성해주세요')),
          );
        }
        return _buildMainScaffold(family);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('캘린더')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('캘린더')),
        body: Center(child: Text('오류: $e')),
      ),
    );
  }

  Widget _buildMainScaffold(FamilyModel family) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Google Calendar 설정',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const GoogleCalendarSettings(),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '캘린더'),
            Tab(text: 'TODO'),
            Tab(text: '플래너'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CalendarTab(
            familyId: family.id,
            calendarFormat: _calendarFormat,
            focusedDay: _focusedDay,
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onFocusedDayChanged: (day) => setState(() => _focusedDay = day),
          ),
          _TodoTab(
            familyId: family.id,
            selectedCategory: _selectedCategory,
            onCategoryChanged: (cat) =>
                setState(() => _selectedCategory = cat),
          ),
          _PlannerTab(familyId: family.id),
        ],
      ),
      floatingActionButton: _buildFab(family.id),
    );
  }

  Widget _buildFab(String familyId) {
    return FloatingActionButton(
      onPressed: () {
        switch (_tabController.index) {
          case 0:
            _showCreateEventSheet(context, familyId);
            break;
          case 1:
            _showCreateTodoDialog(context, familyId);
            break;
          case 2:
            _showCreatePlannerSheet(context, familyId);
            break;
        }
      },
      child: const Icon(Icons.add),
    );
  }

  void _showCreateEventSheet(BuildContext context, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateEventSheet(familyId: familyId),
    );
  }

  void _showCreateTodoDialog(BuildContext context, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateTodoSheet(familyId: familyId),
    );
  }

  void _showCreatePlannerSheet(BuildContext context, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreatePlannerSheet(familyId: familyId),
    );
  }
}
