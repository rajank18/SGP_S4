import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:iconsax/iconsax.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final supabase = Supabase.instance.client;
  Map<String, double> categoryData = {};
  double totalExpenses = 0;
  double totalIncome = 0;
  bool isLoading = true;
  String _selectedDuration = 'Daily';
  String _selectedType = 'expense'; // Default to expense
  final List<String> _durations = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _types = ['expense', 'income'];

  @override
  void initState() {
    super.initState();
    _fetchTransactionData();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedDuration) {
      case 'Daily':
        return DateTime(now.year, now.month, now.day);
      case 'Weekly':
        return now.subtract(const Duration(days: 7));
      case 'Monthly':
        return DateTime(now.year, now.month, 1);
      case 'Yearly':
        return DateTime(now.year, 1, 1);
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  String _getDurationText() {
    switch (_selectedDuration) {
      case 'Daily':
        return "Today's";
      case 'Weekly':
        return 'Last 7 Days';
      case 'Monthly':
        return 'This Month';
      case 'Yearly':
        return 'This Year';
      default:
        return '';
    }
  }

  Future<void> _fetchTransactionData() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final startDate = _getStartDate();

    try {
      final response = await supabase
          .from('transactions')
          .select('amount, type, date, category_id, categories(name), note')
          .eq('user_id', user.id)
          .gte('date', startDate.toIso8601String())
          .order('date', ascending: false);

      Map<String, double> dataByCategory = {};
      double income = 0;
      double expenses = 0;

      for (var transaction in response) {
        double amount = double.tryParse(transaction['amount'].toString()) ?? 0;
        String category;

        if (transaction['type'] == 'expense') {
          final categoryData = transaction['categories'];
          category = categoryData != null && categoryData['name'] != null
              ? categoryData['name']
              : 'Other';
          expenses += amount;
        } else {
          category = transaction['note'] ?? 'Other';
          income += amount;
        }

        if (transaction['type'] == _selectedType) {
          dataByCategory[category] = (dataByCategory[category] ?? 0) + amount;
        }
      }

      // If no data for selected type but other type has data, switch to that type
      if (dataByCategory.isEmpty) {
        if (_selectedType == 'expense' && income > 0) {
          _selectedType = 'income';
          // Recalculate data for income
          dataByCategory.clear();
          for (var transaction in response) {
            if (transaction['type'] == 'income') {
              double amount =
                  double.tryParse(transaction['amount'].toString()) ?? 0;
              String category = transaction['note'] ?? 'Other';
              dataByCategory[category] =
                  (dataByCategory[category] ?? 0) + amount;
            }
          }
        } else if (_selectedType == 'income' && expenses > 0) {
          _selectedType = 'expense';
          // Recalculate data for expenses
          dataByCategory.clear();
          for (var transaction in response) {
            if (transaction['type'] == 'expense') {
              double amount =
                  double.tryParse(transaction['amount'].toString()) ?? 0;
              final categoryData = transaction['categories'];
              String category =
                  categoryData != null && categoryData['name'] != null
                      ? categoryData['name']
                      : 'Other';
              dataByCategory[category] =
                  (dataByCategory[category] ?? 0) + amount;
            }
          }
        }
      }

      setState(() {
        categoryData = dataByCategory;
        totalExpenses = expenses;
        totalIncome = income;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching transaction data: $e');
      setState(() => isLoading = false);
    }
  }

  List<PieChartSectionData> _getSections() {
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    return categoryData.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final amount = entry.value.value;
      final total = _selectedType == 'expense' ? totalExpenses : totalIncome;
      final percentage = (amount / total) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Duration:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedDuration,
                    dropdownColor: Colors.black,
                    style: const TextStyle(color: Colors.green),
                    underline: Container(),
                    items: _durations.map((String duration) {
                      return DropdownMenuItem<String>(
                        value: duration,
                        child: Text(duration),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedDuration = newValue;
                        });
                        _fetchTransactionData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (totalIncome == 0 && totalExpenses == 0)
                    ? Center(
                        child: Text(
                          'No transactions for ${_getDurationText().toLowerCase()}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      )
                    : categoryData.isEmpty
                        ? Center(
                            child: Text(
                              'No ${_selectedType}s for ${_getDurationText().toLowerCase()}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_getDurationText()} Summary',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                minHeight: 120),
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                        255, 66, 66, 66)
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Text(
                                                    'Total Income',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  FittedBox(
                                                    child: Text(
                                                      '₹${totalIncome.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                minHeight: 120),
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                        255, 66, 66, 66)
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Text(
                                                    'Total Expense',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  FittedBox(
                                                    child: Text(
                                                      '₹${totalExpenses.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isSmall =
                                          constraints.maxWidth < 350;
                                      return isSmall
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'Expense Distribution',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 10),
                                                Center(
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child:
                                                        DropdownButton<String>(
                                                      value: _selectedType,
                                                      dropdownColor:
                                                          Colors.black,
                                                      style: const TextStyle(
                                                          color: Colors.green),
                                                      underline: Container(),
                                                      items: _types
                                                          .map((String type) {
                                                        return DropdownMenuItem<
                                                            String>(
                                                          value: type,
                                                          child: Text(
                                                              type == 'expense'
                                                                  ? 'Expenses'
                                                                  : 'Income'),
                                                        );
                                                      }).toList(),
                                                      onChanged:
                                                          (String? newValue) {
                                                        if (newValue != null) {
                                                          setState(() {
                                                            _selectedType =
                                                                newValue;
                                                          });
                                                          _fetchTransactionData();
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Expense Distribution',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: _selectedType,
                                                    dropdownColor: Colors.black,
                                                    style: const TextStyle(
                                                        color: Colors.green),
                                                    underline: Container(),
                                                    items: _types
                                                        .map((String type) {
                                                      return DropdownMenuItem<
                                                          String>(
                                                        value: type,
                                                        child: Text(
                                                            type == 'expense'
                                                                ? 'Expenses'
                                                                : 'Income'),
                                                      );
                                                    }).toList(),
                                                    onChanged:
                                                        (String? newValue) {
                                                      if (newValue != null) {
                                                        setState(() {
                                                          _selectedType =
                                                              newValue;
                                                        });
                                                        _fetchTransactionData();
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 300,
                                    child: PieChart(
                                      PieChartData(
                                        sections: _getSections(),
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 30,
                                        startDegreeOffset: -90,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ...categoryData.entries.map((entry) {
                                    final index = categoryData.keys
                                        .toList()
                                        .indexOf(entry.key);
                                    final colors = [
                                      Colors.blue,
                                      Colors.red,
                                      Colors.green,
                                      Colors.yellow,
                                      Colors.purple,
                                      Colors.orange,
                                      Colors.pink,
                                      Colors.teal,
                                    ];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 16,
                                            color:
                                                colors[index % colors.length],
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${entry.key}: ₹${entry.value.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
