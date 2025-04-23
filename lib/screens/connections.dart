import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneylog/screens/splitdetails.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? searchResult;
  bool isSearching = false;
  Set<String> _hiddenPaidRequests = {};  // Store IDs of hidden paid requests

  Future<void> _searchByEmail() async {
    final queryEmail = _searchController.text.trim();
    if (queryEmail.isEmpty) return;

    setState(() {
      isSearching = true;
      searchResult = null;
    });

    final currentUser = supabase.auth.currentUser;

    try {
      final response = await supabase
          .from('users')
          .select('id, name, email, profile_image_url')
          .eq('email', queryEmail)
          .single();

      if (response['id'] != currentUser?.id) {
        setState(() {
          searchResult = response;
        });
      } else {
        setState(() {
          searchResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can't add yourself.")),
        );
      }
    } catch (e) {
      setState(() {
        searchResult = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No user found with this email.")),
      );
    } finally {
      setState(() {
        isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    final fromUserId = supabase.auth.currentUser?.id;
    if (fromUserId == null) return;

    try {
      await supabase.from('friend_requests').insert({
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend request sent.")),
      );

      setState(() {
        searchResult = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending request: $e")),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getIncomingRequests() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    final requests = await supabase
        .from('friend_requests')
        .select('''
          id,
          from_user:users!friend_requests_from_user_id_fkey(
            name,
            email,
            profile_image_url
          )
        ''')
        .eq('to_user_id', currentUserId)
        .eq('status', 'pending');

    return requests.map<Map<String, dynamic>>((req) {
      return {
        'id': req['id'],
        'name': req['from_user']['name'],
        'email': req['from_user']['email'],
        'profile_image_url': req['from_user']['profile_image_url'],
      };
    }).toList();
  }

  Future<void> _respondToRequest(String requestId, String action) async {
    await supabase
        .from('friend_requests')
        .update({'status': action}).eq('id', requestId);
    setState(() {}); // refresh UI
  }

  Future<List<Map<String, dynamic>>> _getAcceptedConnections() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // First get friend connections
    final connections = await supabase
        .from('friend_requests')
        .select('''
          id,
          from_user:users!friend_requests_from_user_id_fkey(
            name,
            email,
            profile_image_url
          ),
          to_user:users!friend_requests_to_user_id_fkey(
            name,
            email,
            profile_image_url
          )
        ''')
        .or('from_user_id.eq.$currentUserId,to_user_id.eq.$currentUserId')
        .eq('status', 'accepted');

    // Transform the data to get a list of friends
    return connections.map<Map<String, dynamic>>((connection) {
      final isSender = connection['from_user']['id'] == currentUserId;
      final friend = isSender ? connection['to_user'] : connection['from_user'];
      
      return {
        'name': friend['name'],
        'email': friend['email'],
        'profile_image_url': friend['profile_image_url'],
      };
    }).toList();
  }

  Widget _buildAvatar(String name, String? profileImageUrl) {
    return CircleAvatar(
      backgroundColor: Colors.green,
      backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
      child: profileImageUrl == null
          ? Text(
              name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by email...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.green),
                  onPressed: _searchByEmail,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _searchByEmail(),
            ),
            const SizedBox(height: 20),
            if (isSearching) const CircularProgressIndicator(),
            if (searchResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildAvatar(searchResult!['name'], searchResult!['profile_image_url']),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(searchResult!['name'],
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white)),
                          Text(searchResult!['email'],
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendFriendRequest(searchResult!['id']),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text("Add"),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Split Requests",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getSplitRequests(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return SizedBox.shrink();
                    }
                    
                    final paidRequests = snapshot.data!
                        .where((req) => req['status'] == 'paid')
                        .toList();

                    if (paidRequests.isEmpty) {
                      return SizedBox.shrink();
                    }

                    return IconButton(
                      icon: Icon(Icons.delete_sweep, color: Colors.red[300]),
                      onPressed: () => _showDeleteConfirmation(paidRequests),
                      tooltip: 'Hide paid split requests',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getSplitRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}",
                      style: TextStyle(color: Colors.red));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No split requests",
                      style: TextStyle(color: Colors.white70));
                }

                return Column(
                  children: snapshot.data!.map((request) {
                    final isPending = request['status'] == 'pending';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPending ? Colors.orange : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SplitDetails(splitRequest: request),
                          ),
                        ).then((value) {
                          if (value == true) {
                            setState(() {}); // Refresh the page
                          }
                        }),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildAvatar(
                                      request['requester_name'],
                                      request['requester_profile_image']
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      request['requester_name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? Colors.orange.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    request['status'].toUpperCase(),
                                    style: TextStyle(
                                      color: isPending ? Colors.orange : Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${request['amount']}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (request['note'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                request['note'],
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Incoming Requests",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getIncomingRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}",
                      style: TextStyle(color: Colors.red));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No incoming requests",
                      style: TextStyle(color: Colors.white70));
                }

                final requests = snapshot.data!;
                return Column(
                  children: requests.map((req) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(req['name'], req['profile_image_url']),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(req['name'],
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16)),
                                Text(req['email'],
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                onPressed: () =>
                                    _respondToRequest(req['id'], 'accepted'),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                onPressed: () =>
                                    _respondToRequest(req['id'], 'rejected'),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Your Connections",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getAcceptedConnections(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}",
                      style: TextStyle(color: Colors.red));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No connections yet",
                      style: TextStyle(color: Colors.white70));
                }

                final friends = snapshot.data!;
                return Column(
                  children: friends.map((f) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 0, 0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(f['name'], f['profile_image_url']),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f['name'],
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16)),
                              Text(f['email'],
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getSplitRequests() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final requests = await supabase
        .from('split_requests')
        .select('''
          id,
          amount,
          status,
          note,
          category_name,
          expense_id,
          requester_id,
          requester:users!split_requests_requester_id_fkey(
            name,
            profile_image_url
          )
        ''')
        .eq('receiver_id', user.id)
        .order('created_at', ascending: false);

    return requests
        .where((req) => !_hiddenPaidRequests.contains(req['id'].toString()))
        .map<Map<String, dynamic>>((req) {
      return {
        'id': req['id'],
        'amount': req['amount'],
        'status': req['status'],
        'note': req['note'],
        'category_name': req['category_name'],
        'expense_id': req['expense_id'],
        'requester_id': req['requester_id'],
        'requester_name': req['requester']['name'],
        'requester_profile_image': req['requester']['profile_image_url'],
      };
    }).toList();
  }

  void _showDeleteConfirmation(List<Map<String, dynamic>> paidRequests) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Delete Paid Split Requests',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will hide all paid split requests from your view. They will still exist in the database. Continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'No',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _hiddenPaidRequests.addAll(
                  paidRequests
                      .where((req) => req['status'] == 'paid')
                      .map((req) => req['id'].toString())
                );
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Paid split requests hidden'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(
              'Yes',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
