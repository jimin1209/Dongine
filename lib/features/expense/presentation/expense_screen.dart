import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/expense/domain/expense_provider.dart';
import 'package:dongine/shared/models/expense_model.dart';

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  final _wonFormat = NumberFormat('#,###');

  String _formatWon(int amount) {
    return '${_wonFormat.format(amount)}원';
  }

  void _goToPreviousMonth() {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(current.year, current.month - 1);
  }

  void _goToNextMonth() {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(current.year, current.month + 1);
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('가계부'),
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('가족 그룹에 참여해주세요'));
          }
          return _ExpenseBody(
            familyId: family.id,
            theme: theme,
            wonFormat: _wonFormat,
            formatWon: _formatWon,
            onPreviousMonth: _goToPreviousMonth,
            onNextMonth: _goToNextMonth,
          );
        },
      ),
      floatingActionButton: familyAsync.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () => _showAddExpenseSheet(
                context,
                familyAsync.valueOrNull!.id,
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddExpenseSheet(BuildContext context, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddExpenseSheet(familyId: familyId),
    );
  }
}

class _ExpenseBody extends ConsumerWidget {
  final String familyId;
  final ThemeData theme;
  final NumberFormat wonFormat;
  final String Function(int) formatWon;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _ExpenseBody({
    required this.familyId,
    required this.theme,
    required this.wonFormat,
    required this.formatWon,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final expensesAsync = ref.watch(monthlyExpensesProvider(familyId));
    final categoryTotalsAsync =
        ref.watch(monthlyCategoryTotalsProvider(familyId));

    return Column(
      children: [
        // 월 선택기
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${selectedMonth.year}년 ${selectedMonth.month}월',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        // 월간 총액
        expensesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (expenses) {
            int total = 0;
            for (final e in expenses) {
              total += e.amount;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                formatWon(total),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 카테고리 분석
        categoryTotalsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (categoryTotals) {
            if (categoryTotals.isEmpty) return const SizedBox.shrink();
            int grandTotal = 0;
            for (final v in categoryTotals.values) {
              grandTotal += v;
            }
            if (grandTotal == 0) return const SizedBox.shrink();

            final sorted = categoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: sorted.map((entry) {
                  final percent = entry.value / grandTotal;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          ExpenseModel.categoryIcon(entry.key),
                          size: 18,
                          color: ExpenseModel.categoryColor(entry.key),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          child: Text(
                            entry.key,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 12,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: ExpenseModel.categoryColor(entry.key),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(percent * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 80,
                          child: Text(
                            formatWon(entry.value),
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Divider(),

        // 지출 목록
        Expanded(
          child: expensesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (expenses) {
              if (expenses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '이번 달 지출 내역이 없어요',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // 날짜별 그룹핑
              final grouped = <String, List<ExpenseModel>>{};
              const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
              for (final expense in expenses) {
                final d = expense.date;
                final wd = weekdays[d.weekday - 1];
                final key = '${d.month}월 ${d.day}일 ($wd)';
                grouped.putIfAbsent(key, () => []).add(expense);
              }
              final groupKeys = grouped.keys.toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groupKeys.length,
                itemBuilder: (context, index) {
                  final dateKey = groupKeys[index];
                  final items = grouped[dateKey]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          dateKey,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      ...items.map((expense) => Dismissible(
                            key: ValueKey(expense.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: theme.colorScheme.error,
                              child: Icon(
                                Icons.delete,
                                color: theme.colorScheme.onError,
                              ),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(expenseRepositoryProvider)
                                  .deleteExpense(familyId, expense.id);
                              // 새로고침
                              ref.invalidate(
                                  monthlyExpensesProvider(familyId));
                              ref.invalidate(
                                  monthlyCategoryTotalsProvider(familyId));
                            },
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: ExpenseModel.categoryColor(
                                          expense.category)
                                      .withValues(alpha: 0.15),
                                  child: Icon(
                                    ExpenseModel.categoryIcon(
                                        expense.category),
                                    color: ExpenseModel.categoryColor(
                                        expense.category),
                                    size: 20,
                                  ),
                                ),
                                title: Text(expense.title),
                                subtitle: expense.memo != null &&
                                        expense.memo!.isNotEmpty
                                    ? Text(
                                        expense.memo!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: Text(
                                  formatWon(expense.amount),
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String familyId;
  const _AddExpenseSheet({required this.familyId});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String _selectedCategory = '식비';
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim().replaceAll(',', '');
    if (title.isEmpty || amountText.isEmpty) return;

    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    final authState = ref.read(authStateProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    final expense = ExpenseModel(
      id: '',
      title: title,
      amount: amount,
      category: _selectedCategory,
      memo: _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim(),
      createdBy: user.uid,
      paidBy: user.uid,
      date: _selectedDate,
      createdAt: DateTime.now(),
    );

    await ref
        .read(expenseRepositoryProvider)
        .addExpense(widget.familyId, expense);

    // 새로고침
    ref.invalidate(monthlyExpensesProvider(widget.familyId));
    ref.invalidate(monthlyCategoryTotalsProvider(widget.familyId));

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy년 M월 d일');

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '지출 추가',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 제목
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '지출 내용을 입력하세요',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // 금액
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '금액',
                hintText: '금액을 입력하세요',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // 카테고리
            Text(
              '카테고리',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseModel.categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ExpenseModel.categoryIcon(cat),
                        size: 16,
                        color: isSelected
                            ? theme.colorScheme.onSecondaryContainer
                            : ExpenseModel.categoryColor(cat),
                      ),
                      const SizedBox(width: 4),
                      Text(cat),
                    ],
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 날짜
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(dateFormat.format(_selectedDate)),
            ),
            const SizedBox(height: 12),

            // 메모
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '메모를 입력하세요',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // 저장
            FilledButton(
              onPressed: _submit,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
