import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final supabase = Supabase.instance.client;
  Map<String, double> categoryExpenses = {};
  double totalExpenses = 0;
  double totalIncome = 0;
  bool isLoading = true;
  String _selectedDuration = 'Weekly'; // Default duration

  final List<String> _durations = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

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
        return now.subtract(Duration(days: 7));
      case 'Monthly':
        return DateTime(now.year, now.month, 1);
      case 'Yearly':
        return DateTime(now.year, 1, 1);
      default:
        return now.subtract(Duration(days: 7));
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
          .select('amount, type, date, category_id, categories(name)')
          .eq('user_id', user.id)
          .gte('date', startDate.toIso8601String())
          .order('date', ascending: false);

      Map<String, double> expensesByCategory = {};
      double income = 0;
      double expenses = 0;

      for (var transaction in response) {
        double amount = double.tryParse(transaction['amount'].toString()) ?? 0;
        final categoryData = transaction['categories'];
        String category = categoryData != null && categoryData['name'] != null
            ? categoryData['name']
            : 'Other';

        if (transaction['type'] == 'expense') {
          expensesByCategory[category] =
              (expensesByCategory[category] ?? 0) + amount;
          expenses += amount;
        } else if (transaction['type'] == 'income') {
          income += amount;
        }
      }

      setState(() {
        categoryExpenses = expensesByCategory;
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

    return categoryExpenses.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final amount = entry.value.value;
      final percentage = (amount / totalExpenses) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: TextStyle(
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
                Text(
                  'Duration:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedDuration,
                    dropdownColor: Colors.black,
                    style: TextStyle(color: Colors.green),
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
                ? Center(child: CircularProgressIndicator())
                : categoryExpenses.isEmpty
                    ? Center(
                        child: Text(
                          'No expenses for ${_getDurationText().toLowerCase()}',
                          style: TextStyle(color: Colors.white, fontSize: 16),
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 20),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total Income: ₹${totalIncome.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Total Expenses: ₹${totalExpenses.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 30),
                              Text(
                                'Expense Distribution',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 20),
                              SizedBox(
                                height: 300,
                                child: PieChart(
                                  PieChartData(
                                    sections: _getSections(),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    startDegreeOffset: -90,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              ...categoryExpenses.entries.map((entry) {
                                final index = categoryExpenses.keys
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        color: colors[index % colors.length],
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '${entry.key}: ₹${entry.value.toStringAsFixed(2)}',
                                        style: TextStyle(
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
