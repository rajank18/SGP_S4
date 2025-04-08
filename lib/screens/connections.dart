import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          .select('id, name, email')
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
      .select('id, from_user_id, from_user:from_user_id(name, email)')
      .eq('to_user_id', currentUserId)
      .eq('status', 'pending');

  return requests.map<Map<String, dynamic>>((req) {
    return {
      'id': req['id'],
      'name': req['from_user']['name'],
      'email': req['from_user']['email'],
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

    final result =
        await supabase.rpc('get_friends', params: {'user_id': currentUserId});

    return result.map<Map<String, dynamic>>((user) {
      return {
        'name': user['name'],
        'email': user['email'],
      };
    }).toList();
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
                    CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        searchResult!['name'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
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
                          CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Text(req['name'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.white)),
                          ),
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
                        color: Colors.green[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text(f['name'][0].toUpperCase(),
                                style: TextStyle(color: Colors.green[800])),
                          ),
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
}
