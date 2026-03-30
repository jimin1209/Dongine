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

        // 카테고리 필터
        _CategoryFilter(familyId: familyId, theme: theme),

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

              return _ExpenseList(
                expenses: expenses,
                familyId: familyId,
                theme: theme,
                formatWon: formatWon,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category Filter
// ---------------------------------------------------------------------------
class _CategoryFilter extends ConsumerWidget {
  final String familyId;
  final ThemeData theme;

  const _CategoryFilter({required this.familyId, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(expenseCategoryFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('전체'),
              selected: selectedCategory == null,
              onSelected: (_) =>
                  ref.read(expenseCategoryFilterProvider.notifier).state = null,
            ),
          ),
          ...ExpenseModel.categories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ExpenseModel.categoryIcon(cat),
                      size: 14,
                      color: selectedCategory == cat
                          ? theme.colorScheme.onSecondaryContainer
                          : ExpenseModel.categoryColor(cat),
                    ),
                    const SizedBox(width: 4),
                    Text(cat),
                  ],
                ),
                selected: selectedCategory == cat,
                onSelected: (_) =>
                    ref.read(expenseCategoryFilterProvider.notifier).state =
                        selectedCategory == cat ? null : cat,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expense List (날짜별 그룹핑 + 필터 + 탭 수정 + 스와이프 삭제 확인)
// ---------------------------------------------------------------------------
class _ExpenseList extends ConsumerWidget {
  final List<ExpenseModel> expenses;
  final String familyId;
  final ThemeData theme;
  final String Function(int) formatWon;

  const _ExpenseList({
    required this.expenses,
    required this.familyId,
    required this.theme,
    required this.formatWon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryFilter = ref.watch(expenseCategoryFilterProvider);

    final filtered = categoryFilter == null
        ? expenses
        : expenses.where((e) => e.category == categoryFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          categoryFilter != null
              ? '$categoryFilter 카테고리에 지출이 없어요'
              : '지출 내역이 없어요',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    // 날짜별 그룹핑
    final grouped = <String, List<ExpenseModel>>{};
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    for (final expense in filtered) {
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
                  confirmDismiss: (_) => _confirmDelete(context),
                  onDismissed: (_) {
                    ref
                        .read(expenseRepositoryProvider)
                        .deleteExpense(familyId, expense.id);
                    ref.invalidate(monthlyExpensesProvider(familyId));
                    ref.invalidate(monthlyCategoryTotalsProvider(familyId));
                  },
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            ExpenseModel.categoryColor(expense.category)
                                .withValues(alpha: 0.15),
                        child: Icon(
                          ExpenseModel.categoryIcon(expense.category),
                          color:
                              ExpenseModel.categoryColor(expense.category),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _showEditSheet(context, expense),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('지출 삭제'),
            content: const Text('이 지출 항목을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditSheet(BuildContext context, ExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddExpenseSheet(
        familyId: familyId,
        existingExpense: expense,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit Expense Sheet
// ---------------------------------------------------------------------------
class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String familyId;
  final ExpenseModel? existingExpense;

  const _AddExpenseSheet({
    required this.familyId,
    this.existingExpense,
  });

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String _selectedCategory = '식비';
  late DateTime _selectedDate;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingExpense;
    if (existing != null) {
      _titleController.text = existing.title;
      _amountController.text = existing.amount.toString();
      _memoController.text = existing.memo ?? '';
      _selectedCategory = existing.category;
      _selectedDate = existing.date;
    } else {
      _selectedDate = DateTime.now();
    }
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

    final memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();
    final repo = ref.read(expenseRepositoryProvider);

    if (_isEditing) {
      final updated = widget.existingExpense!.copyWith(
        title: title,
        amount: amount,
        category: _selectedCategory,
        memo: memo,
        date: _selectedDate,
      );
      await repo.updateExpense(widget.familyId, updated);
    } else {
      final expense = ExpenseModel(
        id: '',
        title: title,
        amount: amount,
        category: _selectedCategory,
        memo: memo,
        createdBy: user.uid,
        paidBy: user.uid,
        date: _selectedDate,
        createdAt: DateTime.now(),
      );
      await repo.addExpense(widget.familyId, expense);
    }

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
              _isEditing ? '지출 수정' : '지출 추가',
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_isEditing ? '수정' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
