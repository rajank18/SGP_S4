import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:moneylog/config/env_config.dart';

class AIModelPage extends StatefulWidget {
  const AIModelPage({super.key});

  @override
  State<AIModelPage> createState() => _AIModelPageState();
}

class _AIModelPageState extends State<AIModelPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = false;
  String? aiSuggestion;
  
  // Get API key from environment variables
  String get openRouterApiKey => EnvConfig.openRouterApiKey;
  
  @override
  void initState() {
    super.initState();
    _loadSavedSuggestions();
  }

  Future<void> _loadSavedSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSuggestion = prefs.getString('ai_suggestion');
    
    if (savedSuggestion != null) {
      setState(() {
        aiSuggestion = savedSuggestion;
      });
    } else {
      // Only fetch new suggestions if we don't have any saved
      _getAISuggestions();
    }
  }

  Future<void> _saveSuggestions(String suggestions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_suggestion', suggestions);
  }

  Future<List<Map<String, dynamic>>> _fetchTransactionData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await supabase
          .from('transactions')
          .select('''
            amount,
            type,
            date,
            created_at,
            note,
            categories(name)
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  Future<String> _analyzeTransactions(List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) {
      return "No transaction data available for analysis.";
    }

    // Calculate some basic statistics
    double totalExpense = 0;
    double totalIncome = 0;
    Map<String, double> categoryExpenses = {};
    
    for (var tx in transactions) {
      double amount = double.tryParse(tx['amount'].toString()) ?? 0;
      if (tx['type'] == 'expense') {
        totalExpense += amount;
        String category = tx['categories']?['name'] ?? 'Other';
        categoryExpenses[category] = (categoryExpenses[category] ?? 0) + amount;
      } else {
        totalIncome += amount;
      }
    }

    // Format numbers with proper Indian currency format
    final indianCurrency = NumberFormat.currency(
      symbol: '₹',
      locale: 'en_IN',
      decimalDigits: 0,
    );

    // Prepare the prompt for the AI
    String transactionSummary = '''
    Total Income: ${indianCurrency.format(totalIncome)}
    Total Expenses: ${indianCurrency.format(totalExpense)}
    
    Expense Breakdown by Category:
    ${categoryExpenses.entries.map((e) => "${e.key}: ${e.value}").join("\n")}
    ''';

    String prompt = '''
    As a friendly financial advisor from INDIA, analyze this spending data and give simple money-saving tips.
    
    $transactionSummary
    
    Please give advice in these areas:
    1. Simple observations about spending habits
    2. Easy tips to cut down expenses
    3. Where money can be saved
    4. How much to save each month
    
    Rules for your response:
    - Do not use any currency symbol like dollor or rupees just use number as it is.
    - Use very simple, everyday language like talking to a friend
    - Avoid calculations or formulas
    - Give practical, realistic suggestions for Indian lifestyle
    - Keep each point short and clear
    
    
    Start your response with "Here's my simple advice:" and then list your suggestions.
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $openRouterApiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'android-app://com.example.moneylog',
        },
        body: jsonEncode({
          'model': 'mistralai/mistral-7b-instruct',
          'messages': [
            {
              'role': 'system',
              'content': 'You are India based friendly financial advisor who speaks in simple, clear language. You must have to use only numbers no currency behind or above it (example - 1000 instead of 1000 dollor or ruppes). Avoid complex terms and mathematical expressions.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String aiResponse = jsonResponse['choices'][0]['message']['content'];
        
        // Enhanced cleanup of the response
        
        
        return aiResponse;
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling OpenRouter API: $e');
      return "Sorry, I couldn't generate advice right now. Please try again later.";
    }
  }

  Future<void> _getAISuggestions() async {
    if (isLoading) return; // Prevent multiple simultaneous calls
    
    setState(() {
      isLoading = true;
    });

    try {
      final transactions = await _fetchTransactionData();
      final aiResponse = await _analyzeTransactions(transactions);
      
      // Save the new suggestions
      await _saveSuggestions(aiResponse);
      
      setState(() {
        aiSuggestion = aiResponse;
      });
    } catch (e) {
      setState(() {
        aiSuggestion = "Unable to generate suggestions at the moment. Please try again later.";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AI Insights",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            // const SizedBox(height: 20),
            // Container(
            //   padding: const EdgeInsets.all(16),
            //   decoration: BoxDecoration(
            //     color: Colors.green.withOpacity(0.1),
            //     borderRadius: BorderRadius.circular(12),
            //     border: Border.all(color: Colors.green.withOpacity(0.3)),
            //   ),
            //   child: Row(
            //     children: [
            //       Icon(
            //         Iconsax.gemini1,
            //         color: Colors.green[400],
            //         size: 32,
            //       ),
            //       const SizedBox(width: 16),
            //       const Expanded(
            //         child: Text(
            //           "Our AI analyzes your spending patterns to provide personalized savings recommendations",
            //           style: TextStyle(
            //             color: Colors.white,
            //             fontSize: 16,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 30),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.green,
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Savings Recommendations",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              aiSuggestion ?? "No suggestions available",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _getAISuggestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Refresh Insights",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 