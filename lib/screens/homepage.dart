import 'package:flutter/material.dart';
import 'package:moneylog/screens/transaction.dart';
import 'package:moneylog/screens/budgetpage.dart';
import 'package:moneylog/screens/analysis.dart';
import 'package:moneylog/screens/userprofile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePageContent(),
    BudgetPage(),
    AnalyticsPage(),
    UserProfile(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text("MoneyLog", style: TextStyle(color: Colors.green)),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.green),
      ),
      backgroundColor: Colors.black,
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TransactionPage()),
          );
          if (result == true) {
            setState(() {
              _pages[0] = HomePageContent(); // Refresh
            });
          }
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: Colors.black),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Iconsax.wallet), label: "Budget"),
          BottomNavigationBarItem(icon: Icon(Iconsax.chart_2), label: "Analysis"),
          BottomNavigationBarItem(icon: Icon(Iconsax.profile_circle), label: "Profile"),
        ],
      ),
    );
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final supabase = Supabase.instance.client;
  List<dynamic> _transactions = [];
  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('transactions')
        .select('id, amount, type, date, created_at, note, categories(name)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    double income = 0.0;
    double expense = 0.0;

    for (var transaction in response) {
      double amount = double.tryParse(transaction['amount'].toString()) ?? 0;
      if (transaction['type'] == 'income') {
        income += amount;
      } else if (transaction['type'] == 'expense') {
        expense += amount;
      }
    }

    setState(() {
      _transactions = response;
      _totalIncome = income;
      _totalExpense = expense;
      _balance = income - expense;
    });
  }

  Future<void> _deleteTransaction(String transactionId) async {
    try {
      await supabase.from('transactions').delete().eq('id', transactionId);

      setState(() {
        _transactions.removeWhere((tx) => tx['id'] == transactionId);
        _totalIncome = _transactions.where((tx) => tx['type'] == 'income').fold(
            0.0, (sum, tx) => sum + double.tryParse(tx['amount'].toString())!);
        _totalExpense = _transactions
            .where((tx) => tx['type'] == 'expense')
            .fold(0.0,
                (sum, tx) => sum + double.tryParse(tx['amount'].toString())!);
        _balance = _totalIncome - _totalExpense;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transaction deleted.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    }
  }

  void _confirmDelete(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Transaction"),
        content: Text("Are you sure you want to delete this transaction?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTransaction(transactionId);
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(
      String title, double amount, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 6),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            SizedBox(height: 8),
            Text("₹${amount.abs().toStringAsFixed(2)}",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDeficit = _totalExpense > _totalIncome;

    return Column(
      children: [
        SizedBox(height: 16),
        Row(
          children: [
            _buildInfoBox(
                "Income", _totalIncome, Colors.green.shade700, Colors.white),
            _buildInfoBox(
                "Expense", _totalExpense, Colors.red.shade700, Colors.white),
            _buildInfoBox("Balance", _balance, Colors.grey.shade800,
                isDeficit ? Colors.red : Colors.white),
          ],
        ),
        SizedBox(height: 16),
        Expanded(
          child: _transactions.isEmpty
              ? Center(
                  child: Text("No Transactions Found!",
                      style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: _transactions.length,
                  padding: EdgeInsets.only(
                      bottom: 80), // 👈 adds space below last item
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    bool isIncome = tx['type'] == 'income';
                    String categoryOrNote = isIncome
                        ? (tx['note'] ?? 'Other')
                        : (tx['categories']?['name'] ?? 'Other');

                    return ListTile(
                      title: Text(
                        "${isIncome ? 'Income' : 'Expense'} ($categoryOrNote): ₹${tx['amount']}",
                        style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red),
                      ),
                      subtitle: Text(
                        '${DateFormat('yyyy-MM-dd').format(DateTime.parse(tx['created_at']).toLocal())} '
                        '              ${DateFormat('h:mm a').format(DateTime.parse(tx['created_at']).toLocal())}',
                        style: TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(tx['id']),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}