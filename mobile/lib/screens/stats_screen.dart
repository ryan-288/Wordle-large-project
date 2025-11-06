import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _basicStats;
  Map<String, dynamic>? _detailedStats;
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      
      if (userJson == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final user = json.decode(userJson);
      setState(() {
        _user = user;
      });
      final basic = await ApiService.getUserStats(user['id']);
      final detailed = await ApiService.getUserDetailedStats(user['id']);
      
      setState(() {
        _basicStats = basic;
        _detailedStats = detailed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121213),
      appBar: AppBar(
        title: const Text('Statistics', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF121213),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Picture Banner
                      if (_user != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2a),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showStatsDialog(context),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6aaa64),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_user!['firstName']?[0] ?? ''}${_user!['lastName']?[0] ?? ''}'.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _user!['username'] ?? _user!['firstName'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout, color: Colors.red),
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('user');
                                  Navigator.of(context).pushReplacementNamed('/login');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_basicStats != null) ...[
                        _buildStatCard('Games Played', _basicStats!['gamesPlayed']?.toString() ?? '0'),
                        const SizedBox(height: 16),
                        _buildStatCard('Games Won', _basicStats!['gamesWon']?.toString() ?? '0'),
                        const SizedBox(height: 16),
                        _buildStatCard('Win Rate', '${(_basicStats!['winRate'] ?? 0.0).toStringAsFixed(1)}%'),
                        const SizedBox(height: 16),
                        _buildStatCard('Avg Guesses per Win', _basicStats!['averageGuessesPerWin']?.toStringAsFixed(1) ?? '0.0'),
                      ],
                      if (_detailedStats != null) ...[
                        const SizedBox(height: 24),
                        Builder(
                          key: const ValueKey('detailed_stats'),
                          builder: (context) => const Text(
                            'Detailed Statistics',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatCard('Current Streak', _detailedStats!['statistics']?['currentStreak']?.toString() ?? '0'),
                        const SizedBox(height: 16),
                        _buildStatCard('Max Streak', _detailedStats!['statistics']?['maxStreak']?.toString() ?? '0'),
                        const SizedBox(height: 16),
                        _buildStatCard('Games Lost', _detailedStats!['statistics']?['gamesLost']?.toString() ?? '0'),
                        const SizedBox(height: 16),
                        _buildStatCard('Active Games', _detailedStats!['statistics']?['activeGames']?.toString() ?? '0'),
                        const SizedBox(height: 24),
                        if (_detailedStats!['statistics']?['guessDistribution'] != null) ...[
                          const Text(
                            'Guess Distribution',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(6, (index) {
                            final count = _detailedStats!['statistics']?['guessDistribution']?[index] ?? 0;
                            final maxCount = _detailedStats!['statistics']?['guessDistribution']?.reduce((a, b) => a > b ? a : b) ?? 1;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6aaa64),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      width: maxCount > 0 ? (count / maxCount) * MediaQuery.of(context).size.width * 0.7 : 0,
                                      child: count > 0 ? Center(
                                        child: Text(
                                          count.toString(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ) : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF6aaa64),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showStatsDialog(BuildContext context) {
    if (_basicStats == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Statistics', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Games', _basicStats!['gamesPlayed']?.toString() ?? '0'),
                _buildMiniStat('Wins', _basicStats!['gamesWon']?.toString() ?? '0'),
                _buildMiniStat('Win Rate', '${(_basicStats!['winRate'] ?? 0.0).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Avg Guesses/Win: ${_basicStats!['averageGuessesPerWin']?.toStringAsFixed(1) ?? '0.0'}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Scroll to detailed stats section
              Future.delayed(const Duration(milliseconds: 300), () {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent * 0.6, // Approximate position
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6aaa64),
            ),
            child: const Text('View Detailed Stats'),
          ),
        ],
      ),
    );
  }
}

