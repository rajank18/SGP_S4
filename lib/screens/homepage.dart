import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moneylog/screens/transaction.dart';
import 'package:moneylog/screens/budgetpage.dart';
import 'package:moneylog/screens/analysis.dart';
import 'package:moneylog/screens/userprofile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:moneylog/screens/connections.dart';
import 'package:moneylog/screens/split_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final GlobalKey<_HomePageContentState> _homePageKey = GlobalKey<_HomePageContentState>();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePageContent(key: _homePageKey),
      BudgetPage(),
      AnalyticsPage(),
      ConnectionsPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _refreshHomePage() {
    _homePageKey.currentState?._fetchTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "MoneyLog",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
          textAlign: TextAlign.left,
        ),
        automaticallyImplyLeading: false,
        centerTitle: false,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.green),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person,
              size: 36,
            ),
            color: const Color.fromARGB(255, 255, 255, 255),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserProfile()),
              );
            },
          )
        ],
      ),
      backgroundColor: Colors.black,
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TransactionPage()),
          );
          if (result == true) {
            _refreshHomePage();
          }
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Iconsax.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Iconsax.wallet), label: "Budget"),
          BottomNavigationBarItem(
              icon: Icon(Iconsax.chart_2), label: "Analysis"),
          BottomNavigationBarItem(
              icon: Icon(Iconsax.people), label: "Connections"),
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
  List<dynamic> _filteredTransactions = [];
  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // First get all transactions that have split requests
      final splitRequestsResponse = await supabase
          .from('split_requests')
          .select('expense_id')
          .eq('requester_id', user.id);

      // Create a set of transaction IDs that have been split
      final splitTransactionIds = splitRequestsResponse
          .map((req) => req['expense_id'].toString())
          .toSet();

      // Now fetch all transactions
      final response = await supabase
          .from('transactions')
          .select('''
            id,
            amount,
            type,
            date,
            created_at,
            note,
            categories(name)
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Add a flag to each transaction indicating if it's been split
      final transactionsWithSplitFlag = response.map((tx) {
        tx['is_split'] = splitTransactionIds.contains(tx['id'].toString());
        return tx;
      }).toList();

      double income = 0.0;
      double expense = 0.0;

      for (var transaction in transactionsWithSplitFlag) {
        double amount = double.tryParse(transaction['amount'].toString()) ?? 0;
        if (transaction['type'] == 'income') {
          income += amount;
        } else if (transaction['type'] == 'expense') {
          expense += amount;
        }
      }

      setState(() {
        _transactions = transactionsWithSplitFlag;
        _totalIncome = income;
        _totalExpense = expense;
        _balance = income - expense;
        _filterTransactions();
      });
    } catch (e) {
      print('Error fetching transactions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading transactions: $e')),
      );
    }
  }

  void _filterTransactions() {
    final startOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    final endOfMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    setState(() {
      _filteredTransactions = _transactions.where((tx) {
        final txDate = DateTime.parse(tx['created_at']).toLocal();
        return txDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
            txDate.isBefore(endOfMonth.add(Duration(days: 1)));
      }).toList();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + delta, 1);
      _filterTransactions();
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
        const SnackBar(content: Text("Transaction deleted.")),
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
        title: const Text("Delete Transaction"),
        content:
            const Text("Are you sure you want to delete this transaction?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTransaction(transactionId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(
    String title, double amount, Color bgColor, Color textColor) {
  return Expanded(
    child: Container(
      height: 100, // ✅ Fixed height
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox( // ✅ Ensures the amount fits in one line
            child: Text(
              "₹${amount.abs().toStringAsFixed(1)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildMonthNavigator() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.green),
            onPressed: () => _changeMonth(-1),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('MMMM yyyy').format(_currentDate),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: Colors.green),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  bool _isTransactionSplit(dynamic transaction) {
    return transaction['is_split'] == true;
  }

  void _showAlreadySplitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This expense has already been split'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDeficit = _totalExpense > _totalIncome;

    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            _buildInfoBox("Income", _totalIncome,
                const Color.fromARGB(255, 161, 204, 112), Colors.white),
            _buildInfoBox("Expense", _totalExpense,
                const Color.fromARGB(255, 216, 113, 112), Colors.white),
            _buildInfoBox("Balance", _balance, Colors.grey.shade800,
                isDeficit ? const Color.fromARGB(255, 216, 113, 112) : Colors.white),
          ],
        ),
        _buildMonthNavigator(),
        Expanded(
          child: _filteredTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No Transactions Found!",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "for ${DateFormat('MMMM yyyy').format(_currentDate)}",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredTransactions.length,
                  padding: EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    final tx = _filteredTransactions[index];
                    bool isIncome = tx['type'] == 'income';
                    String categoryOrNote = isIncome
                        ? (tx['note'] ?? 'Other')
                        : (tx['categories']?['name'] ?? 'Other');
                    bool isAlreadySplit = _isTransactionSplit(tx);

                    return ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      title: Row(
                        children: [
                          Text(
                            "${isIncome ? 'Income' : 'Expense'}: ",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          Text(
                            "₹${tx['amount']}",
                            style: TextStyle(
                              color: isIncome
                                  ? const Color.fromARGB(255, 169, 206, 126)
                                  : const Color.fromARGB(255, 216, 113, 112),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryOrNote,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${DateFormat('d MMM').format(DateTime.parse(tx['created_at']).toLocal())}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: !isIncome ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.group,
                              color: isAlreadySplit ? Colors.grey : Colors.green,
                            ),
                            onPressed: isAlreadySplit
                                ? () => _showAlreadySplitMessage()
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SplitScreen(),
                                        settings: RouteSettings(
                                          arguments: {
                                            'transaction': tx,
                                            'amount': tx['amount'],
                                            'category': categoryOrNote,
                                            'date': tx['created_at'],
                                          },
                                        ),
                                      ),
                                    );
                                  },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red[300]),
                            onPressed: () => _confirmDelete(tx['id']),
                          ),
                        ],
                      ) : IconButton(
                        icon: Icon(Icons.delete, color: Colors.red[300]),
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
