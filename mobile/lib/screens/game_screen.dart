import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

const GRID_ROWS = 6;
const GRID_COLS = 5;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  List<List<Map<String, dynamic>>> _grid = List.generate(
    GRID_ROWS,
    (_) => List.generate(GRID_COLS, (_) => {'letter': '', 'state': ''}),
  );
  int _currentRow = 0;
  int _currentCol = 0;
  String? _gameId;
  bool _gameActive = true;
  bool _loading = false;
  String? _message;
  int _wordLength = 5;
  String _currentGuess = '';
  Map<String, String> _keyStates = {}; // Track keyboard key states: 'correct', 'present', 'absent'
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _basicStats;
  final GlobalKey _profilePictureKey = GlobalKey();
  Map<String, AnimationController> _flipControllers = {};
  Map<String, bool> _cellsFlipped = {};

  @override
  void initState() {
    super.initState();
    _initGame();
    _loadUserData();
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in _flipControllers.values) {
      controller.dispose();
    }
    _flipControllers.clear();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final user = json.decode(userJson);
        setState(() {
          _user = user;
        });
        // Load basic stats
        try {
          final stats = await ApiService.getUserStats(user['id']);
          setState(() {
            _basicStats = stats;
          });
        } catch (e) {
          // Stats failed to load, ignore
        }
      }
    } catch (e) {
      // User data failed to load, ignore
    }
  }

  void _resetGame() {
    setState(() {
      _grid = List.generate(
        GRID_ROWS,
        (_) => List.generate(GRID_COLS, (_) => {'letter': '', 'state': ''}),
      );
      _currentRow = 0;
      _currentCol = 0;
      _gameId = null;
      _gameActive = true;
      _message = null;
      _keyStates = {};
      _currentGuess = '';
    });
  }

  Future<void> _initGame() async {
    _resetGame();
    
    setState(() {
      _loading = true;
      _message = null;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      
      if (userJson == null) {
        // Guest mode - allow playing without login
        try {
          const guestId = '000000000000000000000000';
          final result = await ApiService.startGame(guestId);
          setState(() {
            _gameId = result['gameId'];
            _wordLength = result['wordLength'] ?? 5;
            _loading = false;
          });
          return;
        } catch (e) {
          // If guest mode fails, redirect to login
          setState(() {
            _loading = false;
          });
        Navigator.of(context).pushReplacementNamed('/login');
        return;
        }
      }
      
      final user = json.decode(userJson);
      
      if (user['emailVerified'] == false) {
        setState(() {
          _loading = false;
        });
        Navigator.of(context).pushReplacementNamed('/verify');
        return;
      }
      
      try {
        final activeGame = await ApiService.getActiveGame(user['id']);
        if (activeGame['hasActiveGame'] == true && activeGame['gameId'] != null) {
          setState(() {
            _gameId = activeGame['gameId'];
            _wordLength = activeGame['wordLength'] ?? 5;
          });
          
          final gameState = await ApiService.getGameState(activeGame['gameId']);
          _loadGameState(gameState);
          setState(() {
            _loading = false;
          });
          return;
        }
      } catch (e) {
        // No active game
      }

      final result = await ApiService.startGame(user['id']);
      setState(() {
        _gameId = result['gameId'];
        _wordLength = result['wordLength'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
        _loading = false;
      });
    }
  }

  void _loadGameState(Map<String, dynamic> gameState) {
    final newGrid = List.generate(
      GRID_ROWS,
      (_) => List.generate(GRID_COLS, (_) => {'letter': '', 'state': ''}),
    );
    
    final newKeyStates = <String, String>{};
    
    final guesses = gameState['guesses'] as List?;
    if (guesses != null) {
      for (int i = 0; i < guesses.length; i++) {
        final guessData = guesses[i];
        final feedback = guessData['feedback'] as List;
        for (int j = 0; j < feedback.length; j++) {
          final fb = feedback[j];
          final letter = fb['letter'].toString().toUpperCase();
          final status = fb['status'].toString();
          final cellKey = '$i-$j';
          
          newGrid[i][j] = {
            'letter': letter,
            'state': status,
          };
          
          // Mark cells as already flipped when loading saved game
          _cellsFlipped[cellKey] = true;
          
          // Create and set animation controller to finished state
          if (!_flipControllers.containsKey(cellKey)) {
            _flipControllers[cellKey] = AnimationController(
              duration: const Duration(milliseconds: 600),
              vsync: this,
            );
            _flipControllers[cellKey]!.value = 1.0; // Set to fully flipped
          }
          
          // Update keyboard state - keep best state (correct > present > absent)
          final current = newKeyStates[letter];
          if (current == null || 
              status == 'correct' || 
              (status == 'present' && current == 'absent')) {
            newKeyStates[letter] = status;
          }
        }
      }
    }
    
    setState(() {
      _grid = newGrid;
      _currentRow = guesses?.length ?? 0;
      _currentCol = 0;
      _gameActive = gameState['active'] ?? false;
      _currentGuess = '';
      _keyStates = newKeyStates;
    });
  }

  Future<void> _submitGuess() async {
    if (_gameId == null || _loading || !_gameActive || _currentGuess.length != _wordLength) {
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      // Validate word first
      final validation = await ApiService.validateWord(_currentGuess.toLowerCase());
      if (validation['isValid'] != true) {
        setState(() {
          _message = 'Not a valid word';
          _loading = false;
        });
        return;
      }

      final result = await ApiService.submitGuess(_gameId!, _currentGuess.toUpperCase());
      
      final newGrid = List<List<Map<String, dynamic>>>.from(_grid.map((row) => List<Map<String, dynamic>>.from(row)));
      final newKeyStates = Map<String, String>.from(_keyStates);
      final feedback = result['feedback'] as List;
      
      // Update grid immediately with feedback data (so colors show)
      for (int i = 0; i < feedback.length; i++) {
        final cellKey = '${_currentRow}-$i';
        final fb = feedback[i];
        final letter = fb['letter'].toString().toUpperCase();
        final status = fb['status'].toString();
        
        // Update grid immediately
        newGrid[_currentRow][i] = {
          'letter': letter,
          'state': status,
        };
        
        // Create animation controller for this cell if it doesn't exist
        if (!_flipControllers.containsKey(cellKey)) {
          _flipControllers[cellKey] = AnimationController(
            duration: const Duration(milliseconds: 600),
            vsync: this,
          );
        }
        
        // Update keyboard states - keep best state (correct > present > absent)
        final current = newKeyStates[letter];
        if (current == null || 
            status == 'correct' || 
            (status == 'present' && current == 'absent')) {
          newKeyStates[letter] = status;
        }
      }
      
      // Update grid state immediately
      setState(() {
        _grid = newGrid;
        _keyStates = newKeyStates;
      });
      
      // Trigger flip animations with staggered delays
      for (int i = 0; i < feedback.length; i++) {
        final cellKey = '${_currentRow}-$i';
        
        // Start flip animation with delay
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted && _flipControllers.containsKey(cellKey)) {
            _flipControllers[cellKey]!.forward();
          }
      });
      }

      if (result['gameOver'] == true) {
        setState(() {
          _gameActive = false;
        });
        
        if (result['isCorrect'] == true) {
          setState(() {
            _message = 'Congratulations! You won in ${result['totalGuesses']} guesses!';
          });
        } else {
          setState(() {
            _message = 'Game over! The word was: ${result['revealWord']}';
          });
        }
      }

      // Wait for all animations to complete before advancing row
      // Last animation starts at (wordLength - 1) * 100ms and takes 600ms
      final totalAnimationTime = ((_wordLength - 1) * 100) + 600;
      Future.delayed(Duration(milliseconds: totalAnimationTime), () {
        if (mounted) {
      setState(() {
        _currentRow++;
        _currentCol = 0;
        _currentGuess = '';
          });
        }
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _handleKeyPress(String key) {
    if (!_gameActive || _loading || _currentRow >= GRID_ROWS) return;

    if (key == 'ENTER') {
      if (_currentGuess.length == _wordLength) {
        _submitGuess();
      }
      return;
    }

    if (key == 'BACKSPACE') {
      if (_currentGuess.isNotEmpty) {
        setState(() {
          _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
          final newGrid = List<List<Map<String, dynamic>>>.from(_grid.map((row) => List<Map<String, dynamic>>.from(row)));
          newGrid[_currentRow][_currentGuess.length] = {'letter': '', 'state': ''};
          _grid = newGrid;
        });
      }
      return;
    }

    if (key.length == 1 && RegExp(r'[A-Z]').hasMatch(key) && _currentGuess.length < _wordLength) {
      setState(() {
        _currentGuess += key;
        final newGrid = List<List<Map<String, dynamic>>>.from(_grid.map((row) => List<Map<String, dynamic>>.from(row)));
        newGrid[_currentRow][_currentGuess.length - 1] = {'letter': key, 'state': ''};
        _grid = newGrid;
      });
    }
  }

  Color _getCellColor(String state, int row, int col) {
    if (state == 'correct') return const Color(0xFF6aaa64);
    if (state == 'present') return const Color(0xFFc9b458);
    if (state == 'absent') return const Color(0xFF565758);
    if (row == _currentRow && col < _currentGuess.length) {
      return const Color(0xFF565758);
    }
    return const Color(0xFF121213);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = (screenWidth - 100) / GRID_COLS; // Smaller grid

    return Scaffold(
      backgroundColor: const Color(0xFF121213),
      appBar: AppBar(
        title: const Text('Sharedle', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF121213),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.white),
            onPressed: () => Navigator.of(context).pushNamed('/leaderboard'),
          ),
          IconButton(
            icon: const Icon(Icons.people, color: Colors.white),
            onPressed: () => Navigator.of(context).pushNamed('/friends'),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => Navigator.of(context).pushNamed('/history'),
          ),
          // Profile Picture instead of stats icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: GestureDetector(
              onTap: () {
                if (_user != null) {
                  _showStatsDialog(context);
                } else {
                  // Guest mode - show login/register dialog
                  _showGuestDialog(context);
                }
              },
              child: Container(
                key: _profilePictureKey,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6aaa64),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
              child: Text(
                    _user != null
                        ? '${_user!['firstName']?[0] ?? ''}${_user!['lastName']?[0] ?? ''}'.toUpperCase()
                        : 'G',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                  fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 10),
            // Game Grid
            Column(
              mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(GRID_ROWS, (rowIdx) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(GRID_COLS, (colIdx) {
                        final cell = _grid[rowIdx][colIdx];
                        final cellKey = '$rowIdx-$colIdx';
                        final hasState = cell['state'] != '';
                        final isFlipped = _cellsFlipped[cellKey] ?? false;
                        
                        // Get or create animation controller
                        if (!_flipControllers.containsKey(cellKey) && hasState) {
                          _flipControllers[cellKey] = AnimationController(
                            duration: const Duration(milliseconds: 600),
                            vsync: this,
                          );
                          if (isFlipped) {
                            _flipControllers[cellKey]!.value = 1.0;
                          }
                        }
                        
                        final controller = _flipControllers[cellKey];
                        final animation = controller != null
                            ? Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
                              )
                            : null;
                        
                        return AnimatedBuilder(
                          animation: animation ?? const AlwaysStoppedAnimation(0.0),
                          builder: (context, child) {
                            final flipValue = animation?.value ?? 0.0;
                            final isFlipped = flipValue >= 0.5;
                            
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001) // Perspective
                                ..rotateX(flipValue * 3.14159), // 180 degrees
                              child: Container(
                          width: cellSize,
                          height: cellSize,
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                                  color: isFlipped 
                                      ? _getCellColor(cell['state'], rowIdx, colIdx)
                                      : (rowIdx == _currentRow && colIdx == _currentCol 
                                          ? const Color(0xFF565758) 
                                          : const Color(0xFF121213)),
                            border: Border.all(color: const Color(0xFF3a3a3c), width: 2),
                          ),
                          child: Center(
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..rotateX(-flipValue * 3.14159), // Counter-rotate to keep text upright
                            child: Text(
                              cell['letter'] ?? '',
                                      style: TextStyle(
                                        fontSize: cellSize * 0.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    );
                  }),
                ],
              ),
            const Spacer(flex: 1),
            const SizedBox(height: 10),
            // Keyboard
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  _buildKeyboardRow('QWERTYUIOP', screenWidth * 0.08),
                  const SizedBox(height: 6),
                  _buildKeyboardRow('ASDFGHJKL', screenWidth * 0.08),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildKey('ENTER', screenWidth * 0.12, onPressed: () => _handleKeyPress('ENTER')),
                      ...List.generate('ZXCVBNM'.length, (i) {
                        return _buildKey('ZXCVBNM'[i], screenWidth * 0.08);
                      }),
                      _buildKey('⌫', screenWidth * 0.12, onPressed: () => _handleKeyPress('BACKSPACE')),
                    ],
                  ),
                ],
              ),
            ),
            // Next Game Button - only show when game is finished
            if (!_gameActive)
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _loading ? null : _initGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6aaa64),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Next Game',
                          style: TextStyle(
                            color: Colors.white,
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

  Widget _buildKeyboardRow(String keys, double keySize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.split('').map((key) => _buildKey(key, keySize)).toList(),
    );
  }

  Color _getKeyColor(String key) {
    final state = _keyStates[key.toUpperCase()];
    if (state == 'correct') return const Color(0xFF6aaa64);
    if (state == 'present') return const Color(0xFFc9b458);
    if (state == 'absent') return const Color(0xFF565758);
    return const Color(0xFF818384);
  }

  Widget _buildKey(String label, double width, {VoidCallback? onPressed}) {
    return Container(
      width: width,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: onPressed ?? () => _handleKeyPress(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getKeyColor(label),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    if (_basicStats == null) {
      Navigator.of(context).pushNamed('/stats');
      return;
    }
    
    // Get position of profile picture
    final RenderBox? renderBox = _profilePictureKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? position = renderBox?.localToGlobal(Offset.zero);
    final Size? size = renderBox?.size;
    
    final double circleX = position != null && size != null ? position.dx + size.width / 2 : MediaQuery.of(context).size.width - 50;
    final double circleY = position != null ? position.dy + size!.height / 2 : 60.0;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Statistics',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );
        
        return Transform.scale(
          scale: scaleAnimation.value,
          alignment: Alignment.topRight,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final popupWidth = 280.0;
        
        // Position popup so its top-right corner aligns with the circle
        // The circle is at circleX from the left, so popup right should be near circleX
        final desiredRight = screenWidth - circleX;
        
        // Ensure popup doesn't go off screen edges
        final minRight = 16.0;
        final maxRight = screenWidth - popupWidth - 16;
        final finalRight = desiredRight < minRight ? minRight : (desiredRight > maxRight ? maxRight : desiredRight);
        
        return Stack(
          children: [
            Positioned(
              top: circleY + 8,
              right: finalRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with profile picture and name
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF3d3d3e), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Profile Picture
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6aaa64),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              '${_user!['firstName']?[0] ?? ''}${_user!['lastName']?[0] ?? ''}'.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _user!['username'] ?? _user!['firstName'] ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('token');
                            await prefs.remove('userId');
                            Navigator.of(context).pushReplacementNamed('/login');
                          },
                        ),
                      ],
                    ),
                  ),
                  // Stats content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat('Games', _basicStats!['gamesPlayed']?.toString() ?? '0'),
                            _buildMiniStat('Wins', _basicStats!['gamesWon']?.toString() ?? '0'),
                            _buildMiniStat('Win Rate', '${(_basicStats!['winRate'] ?? 0.0).toStringAsFixed(1)}%'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Avg Guesses/Win: ${_basicStats!['averageGuessesPerWin']?.toStringAsFixed(1) ?? '0.0'}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Footer buttons
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF3d3d3e), width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Close', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushNamed('/stats');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6aaa64),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Detailed', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGuestDialog(BuildContext context) {
    // Get position of profile picture
    final RenderBox? renderBox = _profilePictureKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? position = renderBox?.localToGlobal(Offset.zero);
    final Size? size = renderBox?.size;
    
    final double circleX = position != null && size != null ? position.dx + size.width / 2 : MediaQuery.of(context).size.width - 50;
    final double circleY = position != null ? position.dy + size!.height / 2 : 60.0;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Guest Menu',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );
        
        return Transform.scale(
          scale: scaleAnimation.value,
          alignment: Alignment.topRight,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final popupWidth = 280.0;
        
        // Position popup so its top-right corner aligns with the circle
        final desiredRight = screenWidth - circleX;
        
        // Ensure popup doesn't go off screen edges
        final minRight = 16.0;
        final maxRight = screenWidth - popupWidth - 16;
        final finalRight = desiredRight < minRight ? minRight : (desiredRight > maxRight ? maxRight : desiredRight);
        
        return Stack(
          children: [
            Positioned(
              top: circleY + 8,
              right: finalRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with profile picture and "Guest"
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF3d3d3e), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Profile Picture
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6aaa64),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Guest',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Login and Register buttons
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pushReplacementNamed('/login');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6aaa64),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pushReplacementNamed('/register');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D6EFD),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF6aaa64),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

