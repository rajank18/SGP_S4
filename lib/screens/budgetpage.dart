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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("No user logged in");
        return;
      }

      // First check if user exists in users table
      final userCheck = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .single();

      if (userCheck == null) {
        print("User not found in users table");
        return;
      }

      // Fetch categories (predefined ones)
      final response = await supabase
          .from('categories')
          .select('id, name, icon, color')
          .order('name');

      if (response == null || response.isEmpty) {
        print("No categories found in database");
        if (mounted) {
          setState(() {
            _categories = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch budgets for the logged-in user
      final budgetResponse = await supabase
          .from('budgets')
          .select('category_id, amount')
          .eq('user_id', user.id);

      // Convert budgets to a Map for quick lookup
      Map<String, double> budgetMap = {};
      if (budgetResponse != null) {
        for (var b in budgetResponse) {
          budgetMap[b['category_id']] = double.tryParse(b['amount'].toString()) ?? 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _categories = response.map((e) => {
            "id": e['id'],
            "name": e['name'],
            "icon": e['icon'],
            "color": e['color'],
            "budget": budgetMap[e['id']] ?? 0.0
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setBudget(int index) async {
    TextEditingController budgetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            "Set Budget for ${_categories[index]['name']}",
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Enter budget amount",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (budgetController.text.isEmpty) return;
                final newBudget = double.parse(budgetController.text);
                final user = supabase.auth.currentUser;
                if (user == null) return;

                final categoryId = _categories[index]['id'];

                try {
                  // Check if budget already exists
                  final existingBudget = await supabase
                      .from('budgets')
                      .select('id')
                      .eq('category_id', categoryId)
                      .eq('user_id', user.id)
                      .maybeSingle();

                  if (existingBudget == null) {
                    // Insert new budget
                    await supabase.from('budgets').insert({
                      'user_id': user.id,
                      'category_id': categoryId,
                      'amount': newBudget,
                      'start_date': DateTime.now().toIso8601String(),
                      'end_date': DateTime.now()
                          .add(const Duration(days: 30))
                          .toIso8601String(),
                    });
                  } else {
                    // Update existing budget
                    await supabase
                        .from('budgets')
                        .update({'amount': newBudget})
                        .eq('id', existingBudget['id']);
                  }

                  setState(() {
                    _categories[index]['budget'] = newBudget;
                  });

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: const Text("Set", style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            )
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "No Categories Found",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchCategories,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    final budget = _categories[index]['budget'] as double;
                    final Color amountColor = budget == 0 
                        ? Colors.grey 
                        : budget > 0 
                            ? const Color.fromARGB(255, 169, 206, 126)  // Same green as homepage
                            : const Color.fromARGB(255, 216, 113, 112); // Same red as homepage

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        title: Text(
                          _categories[index]['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          "Budget: ₹${_categories[index]['budget']}",
                          style: TextStyle(
                            color: amountColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextButton(
                            onPressed: () => _setBudget(index),
                            child: const Text(
                              "Set Budget",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
