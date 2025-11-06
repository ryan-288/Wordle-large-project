import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;
  bool? _filterActive;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      
      if (userJson == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final user = json.decode(userJson);
      final data = await ApiService.getGameHistory(user['id'], limit: 50, active: _filterActive);
      setState(() {
        _history = data['games'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'won':
        return 'Won';
      case 'lost':
        return 'Lost';
      case 'in_progress':
        return 'In Progress';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'won':
        return const Color(0xFF6aaa64);
      case 'lost':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121213),
      appBar: AppBar(
        title: const Text('Game History', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF121213),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterButton('All', null),
                _buildFilterButton('Active', true),
                _buildFilterButton('Completed', false),
              ],
            ),
          ),
          _loading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? Expanded(child: Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.white))))
                  : _history.isEmpty
                      ? const Expanded(
                          child: Center(
                            child: Text('No games found', style: TextStyle(color: Colors.white)),
                          ),
                        )
                      : Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _history.length,
                            itemBuilder: (context, index) {
                              final game = _history[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2a2a2a),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(game['status'] ?? ''),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getStatusText(game['status'] ?? ''),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          '${game['numGuesses'] ?? 0} guesses',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (game['word'] != null)
                                      Text(
                                        'Word: ${game['word']}',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Word Length: ${game['wordLength'] ?? 5}',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    if (game['createdAt'] != null)
                                      Text(
                                        'Started: ${DateTime.parse(game['createdAt']).toString().substring(0, 16)}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, bool? value) {
    final isSelected = _filterActive == value;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _filterActive = value;
          _loading = true;
        });
        _loadHistory();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF6aaa64) : const Color(0xFF2a2a2a),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

