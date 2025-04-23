import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({Key? key}) : super(key: key);

  @override
  _SplitScreenState createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _noteController = TextEditingController();
  final List<Map<String, dynamic>> _splitRequests = [];
  double _remainingAmount = 0;
  late Map<String, dynamic> _transaction;
  late double _totalAmount;
  late String _category;
  late DateTime _date;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _transaction = args['transaction'];
    _totalAmount = double.parse(args['amount'].toString());
    _remainingAmount = _totalAmount;
    _category = args['category'];
    _date = DateTime.parse(args['date']);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _searchUser(String email) async {
    try {
      final response = await supabase
          .from('users')
          .select('id, email, name')
          .eq('email', email)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  void _addSplitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final amount = _remainingAmount;
    final note = _noteController.text.trim();

    // Search for user by email
    final user = await _searchUser(email);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    // Check if user is trying to split with themselves
    final currentUser = supabase.auth.currentUser;
    if (user['id'] == currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot split with yourself')),
      );
      return;
    }

    setState(() {
      _splitRequests.add({
        'receiver_id': user['id'],
        'receiver_email': user['email'],
        'receiver_name': user['name'],
        'amount': amount,
        'note': note,
      });
      _recalculateRemaining();
    });

    _emailController.clear();
    _noteController.clear();
  }

  void _updateAmount(int index, String value) {
    final newAmount = double.tryParse(value) ?? 0;
    setState(() {
      _splitRequests[index]['amount'] = newAmount;
      _recalculateRemaining();
    });
  }

  void _recalculateRemaining() {
    double total = _splitRequests.fold(0, (sum, request) => sum + (request['amount'] as double));
    setState(() {
      _remainingAmount = _totalAmount - total;
    });
  }

  void _removeSplitRequest(int index) {
    setState(() {
      _splitRequests.removeAt(index);
      _recalculateRemaining();
    });
  }

  Future<void> _saveSplitRequests() async {
    if (_splitRequests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one person to split with')),
      );
      return;
    }

    if (_remainingAmount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allocate the entire amount')),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Create split requests for each person
      for (var request in _splitRequests) {
        await supabase
            .from('split_requests')
            .insert({
              'expense_id': _transaction['id'],
              'requester_id': user.id,
              'receiver_id': request['receiver_id'],
              'amount': request['amount'],
              'status': 'pending',
              'note': request['note'],
              'category_name': _category,
            });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split requests sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving split requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Split Expense', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.green),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Total Amount: ₹${_totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Remaining: ₹${_remainingAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _remainingAmount == 0 ? Colors.green : Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Friend\'s Email',
                      labelStyle: const TextStyle(color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      labelStyle: const TextStyle(color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _addSplitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Add Split Request', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _splitRequests.length,
                itemBuilder: (context, index) {
                  final request = _splitRequests[index];
                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(
                        request['receiver_name'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['receiver_email'],
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          TextFormField(
                            initialValue: request['amount'].toString(),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              labelStyle: const TextStyle(color: Colors.green),
                              prefixText: '₹',
                              prefixStyle: const TextStyle(color: Colors.green),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[700]!),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.green),
                              ),
                            ),
                            onChanged: (value) => _updateAmount(index, value),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeSplitRequest(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveSplitRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Send Split Requests',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 