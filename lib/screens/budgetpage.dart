import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneylog/screens/analysis.dart';
import 'package:moneylog/screens/homepage.dart';
import 'package:moneylog/screens/userprofile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetPage extends StatefulWidget {
  @override
  _BudgetPageState createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('categories')
        .select('id, name')
        .eq('user_id', user.id);

    setState(() {
      _categories = response.map((e) => {"id": e['id'], "name": e['name'], "budget": 0.0}).toList();
    });

    // Fetch budgets and update categories
    for (var category in _categories) {
      final budgetResponse = await supabase
          .from('budgets')
          .select('amount')
          .eq('category_id', category['id'])
          .maybeSingle();

      if (budgetResponse != null) {
        setState(() {
          category['budget'] = budgetResponse['amount'];
        });
      }
    }
  }

  Future<void> _addNewCategory() async {
    TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add New Category"),
          content: TextField(
            controller: categoryController,
            decoration: InputDecoration(hintText: "Enter category name"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            TextButton(
              onPressed: () async {
                final user = supabase.auth.currentUser;
                if (user == null || categoryController.text.isEmpty) return;

                final response = await supabase.from('categories').insert({
                  'user_id': user.id,
                  'name': categoryController.text,
                }).select('id').maybeSingle();

                if (response != null) {
                  final categoryId = response['id'];

                  // Insert initial budget as 0
                  await supabase.from('budgets').insert({
                    'user_id': user.id,
                    'category_id': categoryId,
                    'amount': 0,
                    'start_date': DateTime.now().toIso8601String(),
                    'end_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
                  });

                  _fetchCategories();
                }
                Navigator.pop(context);
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setBudget(int index) async {
  TextEditingController budgetController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Set Budget for ${_categories[index]['name']}"),
        content: TextField(
          controller: budgetController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          decoration: InputDecoration(hintText: "Enter budget amount"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (budgetController.text.isEmpty) return;
              final newBudget = double.parse(budgetController.text);

              await supabase.from('budgets').update({'amount': newBudget}).match({
                'category_id': _categories[index]['id'],
                'user_id': supabase.auth.currentUser!.id,
              });

              setState(() {
                _categories[index]['budget'] = newBudget;
              });

              Navigator.pop(context);
            },
            child: Text("Set"),
          ),
        ],
      );
    },
  );
}

  Future<void> _deleteCategory(int index) async {
    await supabase.from('categories').delete().match({'id': _categories[index]['id']});
    _fetchCategories(); // Refresh UI after deletion
  }
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate to the corresponding page based on the selected index
    switch (index) {
      case 0: // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
        break;
      case 1: // Budget
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BudgetPage()),
        );
        break;
      case 2: // Stats
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AnalyticsPage()),
        );
        break;
      case 3: // Profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => UserProfile()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _categories.isEmpty
          ? Center(child: Text("No Categories Added"))
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(_categories[index]['name']),
                    subtitle: Text("Budget: ₹${_categories[index]['budget']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _setBudget(index),
                          child: Text("Set Budget", style: TextStyle(color: Colors.blue)),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCategory(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCategory,
        child: Icon(Icons.add),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: "Budget"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Stats"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
