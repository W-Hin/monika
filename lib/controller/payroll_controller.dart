import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../connection/payroll_service.dart';
import '../model/models.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class PayrollController extends ChangeNotifier {
  PayrollSummary? myCurrentMonth;
  List<PayrollSummary> myHistory = [];
  List<PayrollSummary> allForMonth = []; // HR
  DateTime hrSelectedMonth = DateTime.now();
  bool loading = false;
  bool generating = false;
  String? errorMessage;

  static final _monthLabel = DateFormat('MMMM yyyy');

  PayrollSummary _mapRow(Map<String, dynamic> row) {
    final joinedName = (row['profiles'] as Map<String, dynamic>?)?['name'] as String?;
    final itemsRaw = row['payroll_deduction_items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map((i) => PayrollDeductionItem(label: i['label'] as String, amount: (i['amount'] as num).toDouble()))
        .toList();
    final payMonth = DateTime.parse(row['pay_month'] as String);
    return PayrollSummary(
      dbId: row['id'] as int,
      userUuid: row['user_id'] as String,
      month: _monthLabel.format(payMonth),
      baseSalary: (row['base_salary'] as num).toDouble(),
      deductions: (row['deductions'] as num).toDouble(),
      netPay: (row['net_pay'] as num).toDouble(),
      items: items,
      employeeName: joinedName ?? '',
    );
  }

  Future<void> loadMy() async {
    loading = true;
    notifyListeners();
    final currentRow = await PayrollService.fetchMyCurrentMonth();
    myCurrentMonth = currentRow != null ? _mapRow(currentRow) : null;
    final historyRows = await PayrollService.fetchMyHistory();
    myHistory = historyRows.map(_mapRow).toList();
    loading = false;
    notifyListeners();
  }

  Future<void> loadAllForHr({DateTime? month}) async {
    if (month != null) hrSelectedMonth = month;
    loading = true;
    notifyListeners();
    final rows = await PayrollService.fetchAllForMonth(hrSelectedMonth);
    allForMonth = rows.map(_mapRow).toList();
    loading = false;
    notifyListeners();
  }

  /// Returns true on success. On failure, sets errorMessage and returns
  /// false rather than throwing, since this is a bulk operation the
  /// caller shouldn't need to wrap in try/catch.
  Future<bool> generateForMonth(DateTime month) async {
    errorMessage = null;
    generating = true;
    notifyListeners();
    try {
      await PayrollService.generateForMonth(month);
      await loadAllForHr(month: month);
      generating = false;
      notifyListeners();
      return true;
    } catch (e) {
      generating = false;
      errorMessage = 'Could not generate payroll: $e';
      notifyListeners();
      return false;
    }
  }
}

final payrollController = PayrollController();
