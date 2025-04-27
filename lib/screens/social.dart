import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneylog/screens/splitdetails.dart';
import 'package:moneylog/screens/homepage.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  Map<String, dynamic>? searchResult;
  bool isSearching = false;
  final Set<String> _hiddenPaidRequests = {};  // Store IDs of hidden paid requests

  // Add expansion state for each section
  bool _splitReceivedExpanded = false;
  bool _splitSentExpanded = false;
  bool _pendingRequestsExpanded = false;
  bool _connectionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Future<List<Map<String, dynamic>>> _getSentSplitRequests() async {
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
        receiver_id,
        receiver:users!split_requests_receiver_id_fkey(
          name,
          profile_image_url
        )
      ''')
      .eq('requester_id', user.id)
      .order('created_at', ascending: false);

  return requests.map<Map<String, dynamic>>((req) {
    return {
      'id': req['id'],
      'amount': req['amount'],
      'status': req['status'],
      'note': req['note'],
      'category_name': req['category_name'],
      'receiver_id': req['receiver_id'],
      'receiver_name': req['receiver']['name'],
      'receiver_profile_image': req['receiver']['profile_image_url'],
    };
  }).toList();
}
  Map<String, bool> _sectionExpanded = {
  'split_received': true,
  'split_sent': true,
  'incoming_requests': true,
  'connections': true,
};

void _toggleSection(String key) {
  setState(() {
    _sectionExpanded[key] = !_sectionExpanded[key]!;
  });
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
    
    // Notify HomePage to update notification dot
    if (mounted) {
      final homePage = context.findAncestorStateOfType<HomePageState>();
      homePage?.checkPendingRequests();
    }
  }

  Future<List<Map<String, dynamic>>> _getAcceptedConnections() async {
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) return [];

  final connections = await supabase
      .from('friend_requests')
      .select('''
        id,
        from_user:users!friend_requests_from_user_id_fkey(
          id,
          name,
          email,
          profile_image_url
        ),
        to_user:users!friend_requests_to_user_id_fkey(
          id,
          name,
          email,
          profile_image_url
        )
      ''')
      .or('from_user_id.eq.$currentUserId,to_user_id.eq.$currentUserId')
      .eq('status', 'accepted');

  final seenFriendIds = <String>{};
  final List<Map<String, dynamic>> uniqueFriends = [];

  for (final connection in connections) {
    final fromUser = connection['from_user'];
    final toUser = connection['to_user'];

    // Determine the friend (the one who is NOT the current user)
    final friend = fromUser['id'] == currentUserId ? toUser : fromUser;

    // Skip if already added
    if (!seenFriendIds.contains(friend['id'])) {
      seenFriendIds.add(friend['id']);
      uniqueFriends.add({
        'name': friend['name'],
        'email': friend['email'],
        'profile_image_url': friend['profile_image_url'],
      });
    }
  }

  return uniqueFriends;
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
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
            ),
            if (isSearching) const CircularProgressIndicator(),
            if (searchResult != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
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
              ),
            // TabBar
            Container(
              color: Colors.black,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.green,
                labelColor: Colors.green,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Splits'),
                  Tab(text: 'Connections'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMergedSplitRequestsTab(),
                  _buildMergedConnectionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergedSplitRequestsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Split Requests (Received)
          Column(
            children: [
              ListTile(
                tileColor: Colors.transparent,
                title: const Text(
                  "Received",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: Icon(_splitReceivedExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.green),
                onTap: () {
                  setState(() {
                    _splitReceivedExpanded = !_splitReceivedExpanded;
                  });
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _splitReceivedExpanded
                    ? FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getSplitRequests(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                          } else if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red));
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("No split requests", style: TextStyle(color: Colors.white70))));
                          }
                          return Column(
                            children: snapshot.data!.map((request) {
                              final isPending = request['status'] == 'pending';
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
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
                                              const SizedBox(width: 8),
                                              Text(
                                                request['requester_name'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPending ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              request['status'].toUpperCase(),
                                              style: TextStyle(
                                                color: isPending ? Colors.orange : Colors.green,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '₹${request['amount']}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (request['note'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          request['note'],
                                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Collapsible Split Requests (Sent)
          Column(
            children: [
              ListTile(
                tileColor: Colors.transparent,
                title: const Text(
                  "Sent",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: Icon(_splitSentExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.green),
                onTap: () {
                  setState(() {
                    _splitSentExpanded = !_splitSentExpanded;
                  });
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _splitSentExpanded
                    ? FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getSentSplitRequests(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                          } else if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red));
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("No sent split requests", style: TextStyle(color: Colors.white70))));
                          }
                          return Column(
                            children: snapshot.data!.map((request) {
                              final isPending = request['status'] == 'pending';
                              final isPaid = request['status'] == 'paid';
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPending ? Colors.orange : isPaid ? Colors.grey : Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            _buildAvatar(
                                              request['receiver_name'],
                                              request['receiver_profile_image'],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              request['receiver_name'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isPending
                                                ? Colors.orange.withOpacity(0.2)
                                                : isPaid
                                                    ? Colors.grey.withOpacity(0.2)
                                                    : Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            request['status'].toUpperCase(),
                                            style: TextStyle(
                                              color: isPending
                                                  ? Colors.orange
                                                  : isPaid
                                                      ? Colors.grey
                                                      : Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹${request['amount']}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (request['note'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        request['note'],
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMergedConnectionsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Pending Friend Requests
          Column(
            children: [
              ListTile(
                tileColor: Colors.transparent,
                title: const Text(
                  "Pending Friend Requests",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: Icon(_pendingRequestsExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.green),
                onTap: () {
                  setState(() {
                    _pendingRequestsExpanded = !_pendingRequestsExpanded;
                  });
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _pendingRequestsExpanded
                    ? FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getIncomingRequests(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                          } else if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red));
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("No incoming requests", style: TextStyle(color: Colors.white70))));
                          }
                          final requests = snapshot.data!;
                          return Column(
                            children: requests.map((req) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.5),
                                    width: 1,
                                  ),
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
                                              style: const TextStyle(
                                                  color: Colors.white, fontSize: 16)),
                                          Text(req['email'],
                                              style: const TextStyle(
                                                  color: Colors.white70, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check, color: Colors.green),
                                          onPressed: () => _respondToRequest(req['id'], 'accepted'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.red),
                                          onPressed: () => _respondToRequest(req['id'], 'rejected'),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          // Minimize gap between sections
          const SizedBox(height: 4),
          // Collapsible Your Connections
          Column(
            children: [
              ListTile(
                tileColor: Colors.transparent,
                title: const Text(
                  "Your Friends",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: Icon(_connectionsExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.green),
                onTap: () {
                  setState(() {
                    _connectionsExpanded = !_connectionsExpanded;
                  });
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _connectionsExpanded
                    ? FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getAcceptedConnections(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                          } else if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red));
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("No connections yet", style: TextStyle(color: Colors.white70))));
                          }
                          final friends = snapshot.data!;
                          return Column(
                            children: friends.map((f) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildAvatar(f['name'], f['profile_image_url']),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f['name'],
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 16)),
                                        Text(f['email'],
                                            style: const TextStyle(
                                                color: Colors.white70, fontSize: 14)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
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
        title: const Text(
          'Delete Paid Split Requests',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will hide all paid split requests from your view. They will still exist in the database. Continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
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
                const SnackBar(
                  content: Text('Paid split requests hidden'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSplitRequest(String requestId, String action) async {
    await supabase
        .from('split_requests')
        .update({'status': action}).eq('id', requestId);
    setState(() {}); // refresh UI
    
    // Notify HomePage to update notification dot
    if (mounted) {
      final homePage = context.findAncestorStateOfType<HomePageState>();
      homePage?.checkPendingRequests();
    }
  }
}
