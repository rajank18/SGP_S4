import 'package:flutter/material.dart';
import 'package:moneylog/screens/transaction.dart';
import 'package:moneylog/screens/budgetpage.dart';
import 'package:moneylog/screens/analysis.dart';
import 'package:moneylog/screens/userprofile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final List<dynamic> _transactions = [];
  final double _balance = 0.0;

  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePageContent(),
    BudgetPage(),
    AnalyticsPage(),
    UserProfile(),
  ];

  @override
  void initState() {
    super.initState();
  }

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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TransactionPage()),
          );
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: const Color.fromARGB(255, 0, 0, 0)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: const Color.fromARGB(255, 9, 59, 10),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: "Budget"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Analysis"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
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
        .select('''
          *,
          categories (
            name
          )
        ''')
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(12),
          child: Column(
            children: [
              Text("Account Balance",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 8),
              Text("₹$_balance",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),
        Expanded(
          child: _transactions.isEmpty
              ? Center(
                  child: Text("No Transactions Found!",
                      style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    bool isIncome = transaction['type'] == 'income';
                    String categoryName = transaction['category_name'] ?? 'Other';
                    
                    return ListTile(
                      title: Text(
                        "${isIncome ? 'Income' : 'Expense'} ($categoryName): ₹${transaction['amount']}",
                        style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red),
                      ),
                      subtitle: Text(
                        DateTime.parse(transaction['date']).toString().split('.')[0],
                        style: TextStyle(color: Colors.grey)
                      ),
                      trailing: Icon(Icons.arrow_forward, color: Colors.green),
                    );
                  },
                ),
        ),
      ],
    );
  }
}