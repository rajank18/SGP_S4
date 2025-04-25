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
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final List<Map<String, dynamic>> _splitRequests = [];
  final List<Map<String, dynamic>> _friends = [];
  Map<String, dynamic>? _selectedFriend;
  double _remainingAmount = 0;
  late Map<String, dynamic> _transaction;
  late double _totalAmount;
  late String _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

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
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final response = await supabase
          .from('friend_requests')
          .select(
            '''
            from_user_id,
            to_user_id,
            from_user:users!friend_requests_from_user_id_fkey(id, email, name),
            to_user:users!friend_requests_to_user_id_fkey(id, email, name)
            '''
          )
          .or('from_user_id.eq.${currentUser.id},to_user_id.eq.${currentUser.id}')
          .eq('status', 'accepted');

      final seenFriendIds = <String>{};
      final List<Map<String, dynamic>> uniqueFriends = [];

      for (final item in response) {
        final fromUser = item['from_user'];
        final toUser = item['to_user'];

        // Determine the friend — the one who's NOT the current user
        final friend = fromUser['id'] == currentUser.id ? toUser : fromUser;

        // Skip duplicates
        if (!seenFriendIds.contains(friend['id'])) {
          seenFriendIds.add(friend['id']);
          uniqueFriends.add(friend);
        }
      }

      setState(() {
        _friends.clear();
        _friends.addAll(uniqueFriends);
      });
    } catch (e) {
      debugPrint('Error fetching friends: $e');
    }
  }

  void _selectFriend(Map<String, dynamic> friend) {
    setState(() {
      _selectedFriend = friend;
    });
  }

  void _addSplitRequest() async {
    if (_selectedFriend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a friend first')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final note = _noteController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount > _remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount cannot exceed remaining amount')),
      );
      return;
    }

    setState(() {
      _splitRequests.add({
        'receiver_id': _selectedFriend!['id'],
        'receiver_email': _selectedFriend!['email'],
        'receiver_name': _selectedFriend!['name'],
        'amount': amount,
        'note': note,
      });
      _recalculateRemaining();
      _selectedFriend = null;
    });

    _noteController.clear();
    _amountController.clear();
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

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Update the original transaction amount to your share
      await supabase
          .from('transactions')
          .update({'amount': _remainingAmount})
          .eq('id', _transaction['id']);

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
        Navigator.pop(context, true); // Pass true to indicate refresh needed
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₹${_totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your Share',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₹${_remainingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _remainingAmount == 0 ? Colors.green : Colors.red,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_friends.isNotEmpty) ...[
                  const Text(
                    'Select Friend',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: ListView.builder(
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        final friend = _friends[index];
                        final isSelected = _selectedFriend?['id'] == friend['id'];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.green : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(friend['name'], style: const TextStyle(color: Colors.white)),
                            subtitle: Text(friend['email'], style: TextStyle(color: Colors.grey[400])),
                            trailing: IconButton(
                              icon: const Icon(Icons.add, color: Colors.green),
                              onPressed: () => _selectFriend(friend),
                            ),
                            onTap: () => _selectFriend(friend),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _amountController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount to Split',
                            labelStyle: const TextStyle(color: Colors.green),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.green, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[850],
                            prefixIcon: const Icon(Icons.currency_rupee, color: Colors.green),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                            if (amount > _remainingAmount) {
                              return 'Amount cannot exceed remaining amount';
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.green, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[850],
                            prefixIcon: const Icon(Icons.note, color: Colors.green),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _addSplitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 107, 138, 218),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Add Split Request', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_splitRequests.isNotEmpty) ...[
                  ..._splitRequests.asMap().entries.map((entry) {
                    final index = entry.key;
                    final request = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Text(
                                request['receiver_name'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request['receiver_name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    request['receiver_email'],
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              '₹${request['amount'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (request['note'] != null && request['note'].isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                request['note'],
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeSplitRequest(index),
                        ),
                      ),
                    );
                  }).toList(),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        "No Split Requests Added",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _saveSplitRequests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text(
                    'Send Split Requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 