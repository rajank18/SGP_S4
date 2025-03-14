import 'package:flutter/material.dart';
import 'package:moneylog/screens/transaction.dart';
import 'package:moneylog/screens/budgetpage.dart';
import 'package:moneylog/screens/analysis.dart';
import 'package:moneylog/screens/userprofile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  List<dynamic> _transactions = [];
  double _balance = 0.0;

  int _selectedIndex = 0; // ✅ For Bottom Navbar

  final List<Widget> _pages = [
    HomePageContent(), // Separate widget for home content
    BudgetPage(),
    AnalyticsPage(),
    UserProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MoneyLog", style: TextStyle(color: Colors.green)),
        centerTitle: true, // ✅ Centered Title
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.green),
      ),
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: "Budget"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Analysis"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "User Profile"),
        ],
      ),
    );
  }
}

// ✅ Extract Home Page Content to Avoid Rebuilding on Navigation
class HomePageContent extends StatefulWidget {
  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final supabase = Supabase.instance.client;
  List<dynamic> _transactions = [];
  double _balance = 0.0;

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
        .select()
        .eq('user_id', user.id)
        .order('date', ascending: false);

    double balance = 0.0;
    for (var transaction in response) {
      double amount = double.tryParse(transaction['amount'].toString()) ?? 0;
      if (transaction['type'] == 'income') {
        balance += amount;
      } else if (transaction['type'] == 'expense') {
        balance -= amount;
      }
    }

    setState(() {
      _transactions = response;
      _balance = balance;
    });
  }

  void _navigateToTransactionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TransactionPage()),
    );

    if (result == true) {
      _fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ✅ Account Balance Section
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                "Account Balance",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                "₹$_balance",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),

        // ✅ Transaction History Section
        Expanded(
          child: _transactions.isEmpty
              ? Center(child: Text("No Transactions Found!", style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    bool isIncome = transaction['type'] == 'income';
                    return ListTile(
                      title: Text(
                        "${isIncome ? 'Income' : 'Expense'} (${transaction['category']}): ₹${transaction['amount']}",
                        style: TextStyle(color: isIncome ? Colors.green : Colors.red),
                      ),
                      subtitle: Text("${transaction['date']}", style: TextStyle(color: Colors.grey)),
                      trailing: Icon(Icons.arrow_forward, color: Colors.green),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
