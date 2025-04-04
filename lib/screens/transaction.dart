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
  String _selectedCategory = 'Salary'; // Default category
  final List<String> _incomeCategories = ['Salary', 'Gift', 'Freelance'];
  final List<String> _expenseCategories = [
    'Food',
    'Beauty',
    'Entertainment',
    'Medicine'
  ];

  // ✅ Function to store transaction in Supabase
  Future<void> _addTransaction() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in!")),
      );
      return;
    }

    try {
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'category_id': null, // Update with actual category ID if needed
        'amount': double.parse(_amountController.text),
        'type': _selectedType,
        'note': null,
        'date': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transaction Added Successfully! ✅")),
      );

      Navigator.pop(
          context, true); // ✅ Return `true` to trigger refresh in homepage
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ✅ Build Number Pad for Amount Entry
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

  // ✅ Create Buttons for Number Pad
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
              keyboardType: TextInputType.none, // Disable normal keyboard
              style: TextStyle(fontSize: 24, color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 20),
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
                  _selectedCategory = _selectedType == 'income'
                      ? _incomeCategories.first
                      : _expenseCategories
                          .first; // ✅ Reset category to a valid default
                });
              },
            ),

            SizedBox(height: 20),
            Text("Select Category:",
                style: TextStyle(fontSize: 18, color: Colors.white)),
            DropdownButton<String>(
              value: _selectedCategory,
              dropdownColor: Colors.black,
              items: (_selectedType == 'income'
                      ? _incomeCategories
                      : _expenseCategories)
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: TextStyle(color: Colors.green)),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            SizedBox(height: 20),
            Expanded(
                child: _buildNumberPad()), // ✅ Wrap GridView inside Expanded
          ],
        ),
      ),
    );
  }
}
