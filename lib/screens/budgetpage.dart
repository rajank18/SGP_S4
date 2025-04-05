import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

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

  // Fetch categories (predefined ones)
  final response = await supabase
      .from('categories')
      .select('id, name, icon, color');

  if (response.isEmpty) {
    print("No categories found.");
  }

  // Fetch budgets for the logged-in user
  final budgetResponse = await supabase
      .from('budgets')
      .select('category_id, amount')
      .eq('user_id', user.id);

  // Convert budgets to a Map for quick lookup
  Map<String, double> budgetMap = {};
  for (var b in budgetResponse) {
    budgetMap[b['category_id']] = b['amount'];
  }

  // Update categories with budgets
  setState(() {
    _categories = response.map((e) => {
      "id": e['id'],
      "name": e['name'],
      "icon": e['icon'],
      "color": e['color'],
      "budget": budgetMap[e['id']] ?? 0.0 // Default to 0 if no budget found
    }).toList();
  });

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
              final user = supabase.auth.currentUser;
              if (user == null) return;

              final categoryId = _categories[index]['id'];

              // Check if budget already exists
              final existingBudget = await supabase
                  .from('budgets')
                  .select('id')
                  .eq('category_id', categoryId)
                  .eq('user_id', user.id)
                  .maybeSingle();

              if (existingBudget == null) {
                // Insert a new budget if not exists
                await supabase.from('budgets').insert({
                  'user_id': user.id,
                  'category_id': categoryId,
                  'amount': newBudget,
                  'start_date': DateTime.now().toIso8601String(),
                  'end_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
                });
              } else {
                // Update existing budget
                await supabase.from('budgets').update({
                  'amount': newBudget,
                }).eq('id', existingBudget['id']);
              }

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
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
