import 'dart:convert';
import 'package:http/http.dart' as http;

// API base URL - change this to your server IP
const String API_BASE_URL = 'http://129.212.184.28:5000/api';

class ApiService {
  static Future<Map<String, dynamic>> _parseResponse(http.Response response) async {
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body);
    } else {
      Map<String, dynamic> error;
      try {
        error = json.decode(response.body);
      } catch (e) {
        throw Exception('Request failed: ${response.statusCode}');
      }
      
      // Create a custom exception that preserves status code and email
      final exception = ApiException(
        error['error'] ?? 'Request failed',
        statusCode: response.statusCode,
        email: error['email'],
      );
      throw exception;
    }
  }

  // Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );

    return _parseResponse(response);
  }

  // Register
  static Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'password': password,
      }),
    );

    return _parseResponse(response);
  }

  // Start game
  static Future<Map<String, dynamic>> startGame(String userId, {String? wordId}) async {
    final body = {'userId': userId};
    if (wordId != null) {
      body['wordId'] = wordId;
    }

    final response = await http.post(
      Uri.parse('$API_BASE_URL/game/start'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    return _parseResponse(response);
  }

  // Submit guess
  static Future<Map<String, dynamic>> submitGuess(String gameId, String guess) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/game/guess'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'gameId': gameId,
        'guess': guess,
      }),
    );

    return _parseResponse(response);
  }

  // Get game state
  static Future<Map<String, dynamic>> getGameState(String gameId) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/game/$gameId'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Get active game
  static Future<Map<String, dynamic>> getActiveGame(String userId) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/game/active/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 404) {
      return {'hasActiveGame': false};
    }

    return _parseResponse(response);
  }

  // Validate word
  static Future<Map<String, dynamic>> validateWord(String word) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/word/validate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'word': word}),
    );

    return _parseResponse(response);
  }

  // Get user stats
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/user/stats/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Get detailed user stats
  static Future<Map<String, dynamic>> getUserDetailedStats(String userId) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/stats/user/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Get game history
  static Future<Map<String, dynamic>> getGameHistory(String userId, {int limit = 10, bool? active}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (active != null) {
      params['active'] = active.toString();
    }
    final queryString = Uri(queryParameters: params).query;
    
    final response = await http.get(
      Uri.parse('$API_BASE_URL/game/history/$userId?$queryString'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Get leaderboard
  static Future<Map<String, dynamic>> getLeaderboard({int limit = 10, String sortBy = 'wins'}) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'sortBy': sortBy,
    };
    final queryString = Uri(queryParameters: params).query;
    
    final response = await http.get(
      Uri.parse('$API_BASE_URL/stats/leaderboard?$queryString'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Search users
  static Future<Map<String, dynamic>> searchUsers(String query, String currentUserId) async {
    final params = <String, String>{
      'query': query,
      'currentUserId': currentUserId,
    };
    final queryString = Uri(queryParameters: params).query;
    
    final response = await http.get(
      Uri.parse('$API_BASE_URL/users/search?$queryString'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Get friends
  static Future<Map<String, dynamic>> getFriends(String userId) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/friends/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Send friend request
  static Future<Map<String, dynamic>> sendFriendRequest(String userId, String friendId) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/friends/request'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'friendId': friendId,
      }),
    );

    return _parseResponse(response);
  }

  // Remove friend
  static Future<Map<String, dynamic>> removeFriend(String userId, String friendId) async {
    final response = await http.delete(
      Uri.parse('$API_BASE_URL/friends/remove'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'friendId': friendId,
      }),
    );

    return _parseResponse(response);
  }

  // Compare stats
  static Future<Map<String, dynamic>> compareStats(String userId, String friendId) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/stats/compare/$userId/$friendId'),
      headers: {'Content-Type': 'application/json'},
    );

    return _parseResponse(response);
  }

  // Verify email code
  static Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/auth/verify-email-code'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'code': code,
      }),
    );

    return _parseResponse(response);
  }

  // Resend verification code
  static Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/auth/resend-email-code'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );

    // Parse response exactly like web parseJsonSafe
    dynamic data;
    try {
      if (response.body.isEmpty) {
        data = null;
      } else {
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('application/json')) {
          // Try to parse anyway
          data = json.decode(response.body);
        } else {
          data = json.decode(response.body);
        }
      }
    } catch (e) {
      // If parsing fails, return null like web does
      data = null;
    }

    // Check if response is ok (status 200-299) - match web response.ok
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data ?? {};
    }

    // Throw error with message from response (match web behavior exactly)
    final errorMsg = (data is Map && data['error'] != null) 
        ? data['error'] 
        : 'Failed to resend verification code';
    throw Exception(errorMsg);
  }
}

// Custom exception class to preserve status code and email
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? email;

  ApiException(this.message, {this.statusCode, this.email});

  @override
  String toString() => message;
}
