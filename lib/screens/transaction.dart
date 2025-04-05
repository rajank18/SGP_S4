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
  String _selectedType = 'income'; // Default type
  String? _selectedCategory; // Updated to handle fetched categories
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await supabase.from('categories').select('name').filter('user_id', 'is', null);
      setState(() {
        _categories = response.map<String>((cat) => cat['name'] as String).toList();
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

  Future<void> _addTransaction() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in!")),
      );
      return;
    }

    final amount = double.parse(_amountController.text);
    
    try {
      // First get the category ID
      final categoryResponse = await supabase
          .from('categories')
          .select('id')
          .eq('name', _selectedCategory ?? '')
          .single();
      
      // Now add the transaction with both category_id and category_name
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'category_id': categoryResponse['id'], // Keep the category ID
        'category_name': _selectedCategory, // Add the category name directly
        'amount': amount,
        'type': _selectedType,
        'note': null,
        'date': DateTime.now().toIso8601String(),
      });
      
      if (_selectedType == 'expense') {
        await _updateBudget(user.id, amount);
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

  Future<void> _updateBudget(String userId, double amount) async {
    try {
      final response = await supabase
          .from('budgets')
          .select('id, amount')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        final newAmount = response['amount'] - amount;
        await supabase.from('budgets').update({'amount': newAmount}).eq('id', response['id']);
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
      children: [
        ...List.generate(9, (index) => _buildNumberButton("${index + 1}")),
        _buildNumberButton("."),
        _buildNumberButton("0"),
        _buildNumberButton("C", isClear: true),
        ElevatedButton(
          onPressed: _addTransaction,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: Text("Enter", style: TextStyle(fontSize: 18)),
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
        margin: EdgeInsets.all(4),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isClear ? Colors.red : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 20, color: Colors.white),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            Text("Select Category:",
                style: TextStyle(fontSize: 18, color: Colors.white)),
            DropdownButton<String>(
              value: _selectedCategory,
              dropdownColor: Colors.black,
              items: _categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: TextStyle(color: Colors.green)),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            SizedBox(height: 20),
            Expanded(child: _buildNumberPad()),
          ],
        ),
      ),
    );
  }
}
