import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SplitDetails extends StatefulWidget {
  final Map<String, dynamic> splitRequest;

  const SplitDetails({Key? key, required this.splitRequest}) : super(key: key);

  @override
  _SplitDetailsState createState() => _SplitDetailsState();
}

class _SplitDetailsState extends State<SplitDetails> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _requesterDetails;
  Map<String, dynamic>? _expenseDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      // Validate required fields
      final requesterId = widget.splitRequest['requester_id'];
      final expenseId = widget.splitRequest['expense_id'];

      if (requesterId == null || expenseId == null) {
        throw Exception('Missing required split request data');
      }

      // Get requester details with error handling
      try {
        final requesterResponse = await supabase
            .from('users')
            .select('name, email')
            .eq('id', requesterId)
            .maybeSingle();

        if (requesterResponse == null) {
          throw Exception('Requester not found');
        }
        _requesterDetails = requesterResponse;
      } catch (e) {
        print('Error fetching requester details: $e');
        throw Exception('Could not load requester information');
      }

      // Get expense details with error handling
      try {
        final expenseResponse = await supabase
            .from('transactions')
            .select('amount, created_at, categories(name)')
            .eq('id', expenseId)
            .maybeSingle();

        if (expenseResponse == null) {
          // If expense is not found, create a fallback expense details object
          _expenseDetails = {
            'amount': widget.splitRequest['amount'],
            'created_at': widget.splitRequest['created_at'] ?? DateTime.now().toIso8601String(),
            'categories': {
              'name': widget.splitRequest['category_name'] ?? 'Unknown'
            }
          };
        } else {
          _expenseDetails = expenseResponse;
        }
      } catch (e) {
        print('Error fetching expense details: $e');
        // Create fallback expense details
        _expenseDetails = {
          'amount': widget.splitRequest['amount'],
          'created_at': widget.splitRequest['created_at'] ?? DateTime.now().toIso8601String(),
          'categories': {
            'name': widget.splitRequest['category_name'] ?? 'Unknown'
          }
        };
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markAsPaid() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Start a transaction (not a real DB transaction, but a series of related operations)
      
      // 1. Update split request status to 'paid'
      await supabase
          .from('split_requests')
          .update({'status': 'paid'})
          .eq('id', widget.splitRequest['id']);

      // 2. Create a new expense transaction for the receiver
      final categoryId = await _getCategoryId(widget.splitRequest['category_name']);
      
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'amount': widget.splitRequest['amount'],
        'type': 'expense',
        'category_id': categoryId,
        'date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'note': 'Split expense with ${_requesterDetails?['name']}',
      });

      // 3. Create split expense log
      await supabase.from('split_expense_logs').insert({
        'split_request_id': widget.splitRequest['id'],
        'original_amount': _expenseDetails?['amount'] ?? 0,
        'split_amount': widget.splitRequest['amount'],
      });

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate payment was made
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment marked as complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking as paid: $e')),
        );
      }
    }
  }

  Future<String?> _getCategoryId(String categoryName) async {
    try {
      // First try to find an existing category
      final response = await supabase
          .from('categories')
          .select('id')
          .eq('name', categoryName)
          .maybeSingle();

      if (response != null) {
        return response['id'];
      }

      // If category doesn't exist, create it
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final newCategory = await supabase
          .from('categories')
          .insert({
            'user_id': user.id,
            'name': categoryName,
          })
          .select()
          .single();

      return newCategory['id'];
    } catch (e) {
      print('Error getting/creating category: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Split Details', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.green),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'Error loading split details',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.red[300]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadDetails();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final formattedDate = DateFormat('MMM d, yyyy').format(
      DateTime.parse(_expenseDetails!['created_at']),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Split Details', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.green),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requested by ${_requesterDetails?['name']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _requesterDetails?['email'] ?? '',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expense Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Total Amount', 
                      '₹${_expenseDetails!['amount']}',
                      Colors.white
                    ),
                    _buildDetailRow('Your Share', 
                      '₹${widget.splitRequest['amount']}',
                      Colors.green
                    ),
                    _buildDetailRow('Category', 
                      _expenseDetails!['categories']['name'],
                      Colors.white
                    ),
                    _buildDetailRow('Date', formattedDate, Colors.white),
                    if (widget.splitRequest['note'] != null)
                      _buildDetailRow('Note', 
                        widget.splitRequest['note'],
                        Colors.white
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.splitRequest['status'] == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _markAsPaid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Mark as Paid',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Paid',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400]),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
