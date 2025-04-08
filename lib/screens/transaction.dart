import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedType = 'income';
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('categories')
          .select('name')
          .or('user_id.is.null,user_id.eq.${user.id}');

      setState(() {
        _categories =
            response.map<String>((cat) => cat['name'] as String).toList();
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching categories: $e")),
      );
    }
  }

  Future<double> _getBudgetForCategory(String categoryName) async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0.0;

    final categoryRes = await supabase
        .from('categories')
        .select('id')
        .eq('name', categoryName)
        .maybeSingle();

    if (categoryRes == null) return 0.0;

    final categoryId = categoryRes['id'];

    final budgetRes = await supabase
        .from('budgets')
        .select('amount')
        .eq('category_id', categoryId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (budgetRes == null) return 0.0;
    return double.tryParse(budgetRes['amount'].toString()) ?? 0.0;
  }

  Future<void> _addTransaction() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in!")),
      );
      return;
    }

    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final note = _selectedType == 'income' ? _noteController.text : null;

    String? categoryId;

    if (_selectedType == 'expense') {
      final budget = await _getBudgetForCategory(_selectedCategory!);
      if (enteredAmount > budget) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Budget Exceeded"),
            content: Text(
                "Your expense exceeds the budget for $_selectedCategory. Please update the budget."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      final categoryResponse = await supabase
          .from('categories')
          .select('id')
          .eq('name', _selectedCategory ?? '')
          .maybeSingle();

      if (categoryResponse != null) {
        categoryId = categoryResponse['id'];
      }
    }

    try {
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'category_id': categoryId,
        'amount': enteredAmount,
        'type': _selectedType,
        'note': note,
        'date': DateTime.now().toIso8601String(),
      });

      if (_selectedType == 'expense') {
        await _updateBudget(user.id, categoryId!, enteredAmount);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transaction Added Successfully! ✅")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _updateBudget(String userId, String categoryId, double amount) async {
    try {
      final response = await supabase
          .from('budgets')
          .select('id, amount')
          .eq('user_id', userId)
          .eq('category_id', categoryId)
          .maybeSingle();

      if (response != null) {
        final newAmount = (response['amount'] as num).toDouble() - amount;
        await supabase
            .from('budgets')
            .update({'amount': newAmount}).eq('id', response['id']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating budget: $e")),
      );
    }
  }

  Widget _buildNumberPad() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: [
        ...List.generate(9, (index) => _buildNumberButton("${index + 1}")),
        _buildNumberButton("."),
        _buildNumberButton("0"),
        _buildNumberButton("C", isClear: true),
        ElevatedButton(
          onPressed: _addTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text("Enter", style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildNumberButton(String text, {bool isClear = false}) {
    return GestureDetector(
      onTap: () {
        if (isClear) {
          _amountController.clear();
        } else {
          _amountController.text += text;
        }
      },
      child: Container(
        margin: EdgeInsets.all(2),
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isClear ? Colors.red : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Add Transaction", style: TextStyle(color: Colors.green)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.green),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter Amount:",
                style: TextStyle(fontSize: 18, color: Colors.white)),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.none,
              style: TextStyle(fontSize: 20, color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 18),
            Text("Select Type:",
                style: TextStyle(fontSize: 18, color: Colors.white)),
            DropdownButton<String>(
              value: _selectedType,
              dropdownColor: Colors.black,
              items: ['income', 'expense']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.toUpperCase(),
                            style: TextStyle(color: Colors.green)),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val!;
                });
              },
            ),
            SizedBox(height: 20),
            if (_selectedType == 'expense') ...[
              Text("Select Category:",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
              DropdownButton<String>(
                value: _selectedCategory,
                dropdownColor: Colors.black,
                items: _categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child:
                              Text(cat, style: TextStyle(color: Colors.green)),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedCategory = val!),
              ),
            ] else ...[
              Text("Add Note (Optional):",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
              TextField(
                controller: _noteController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "e.g. Salary, freelance work",
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
            SizedBox(height: 20),
            Expanded(child: _buildNumberPad()),
          ],
        ),
      ),
    );
  }
}
