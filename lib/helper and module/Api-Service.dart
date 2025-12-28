import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Hardcoded base URL
  final String baseUrl = "https://super-duper-carnival.onrender.com";

  /// Registration function
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final Uri url = Uri.parse("$baseUrl/api/auth/register?name=$name&email=$email&password=$password");

    try {
      final response = await http.post(url);

      final Map<String, dynamic> data = jsonDecode(response.body);
      print("Registration API Response: $data");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        if (data.containsKey("userId")) {
          await prefs.setInt("userId", data["userId"]);
        }
        if (data.containsKey("token")) {
          await prefs.setString("token", data["token"]);
        }
        // Save email
        await prefs.setString("email", email);
        return {
          "success": true,
          "data": data,
          "message": data["message"] ?? "Registration successful"
        };
      } else {
        return {
          "success": false,
          "data": data,
          "message": data["message"] ?? "Registration failed"
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// Login function
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final Uri url = Uri.parse(
        "$baseUrl/api/auth/login?email=$email&password=$password");

    try {
      final response = await http.post(url);
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Save userId, token, and email locally
        final prefs = await SharedPreferences.getInstance();
        if (data.containsKey("userId")) {
          await prefs.setInt("userId", data["userId"]);
        }
        if (data.containsKey("token")) {
          await prefs.setString("token", data["token"]);
        }
        // Save email
        await prefs.setString("email", email);

        return {
          "success": true,
          "data": data,
          "message": data["message"] ?? "Login successful"
        };
      } else {
        return {
          "success": false,
          "data": data,
          "message": data["message"] ?? "Login failed"
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }



  /// 1️⃣ Create a new shared list
  Future<Map<String, dynamic>> createSharedList({
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("userId")?.toString();
    final Uri url = Uri.parse('$baseUrl/api/shared/create');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'name': name}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create list: ${response.statusCode} – ${response.body}');
    }
  }

  /// 2️⃣ Join a shared list
  Future<Map<String, dynamic>> joinSharedList({
    required String shareCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("userId")?.toString();
    final Uri url = Uri.parse('$baseUrl/api/shared/join');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'shareCode': shareCode}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to join list: ${response.statusCode} – ${response.body}');
    }
  }

  /// 3️⃣ Add expense to a shared list
  Future<Map<String, dynamic>> addSharedExpense({
    required String shareCode,
    required String description,
    required double amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("userId")?.toString();
    final Uri url = Uri.parse('$baseUrl/api/shared/expense');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'shareCode': shareCode,
        'description': description,
        'amount': amount,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to add expense: ${response.statusCode} – ${response.body}');
    }
  }

  /// Update expense
  Future<Map<String, dynamic>> updateSharedExpense({
    required int id,
    required String description,
    required double amount,
    required String shareCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("userId")?.toString();
    final response = await http.put(
      Uri.parse("$baseUrl/api/shared/expense"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": id,
        "description": description,
        "amount": amount,
        "userId": userId,
        "shareCode": shareCode,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to update expense: ${response.body}");
    }
  }

  /// Delete expense
  Future<void> deleteSharedExpense({
    required int id,
    required String shareCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("userId")?.toString();
    final response = await http.delete(
      Uri.parse("$baseUrl/api/shared/expense?id=$id&userId=$userId&shareCode=$shareCode"),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to delete expense: ${response.body}");
    }
  }

  /// 4️⃣ Get expenses for a shared list
  Future<List<dynamic>>getSharedExpenses({
    required String shareCode,
  }) async {
    final Uri url = Uri.parse('$baseUrl/api/shared/expenses?shareCode=$shareCode');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to fetch expenses: ${response.statusCode} – ${response.body}');
    }
  }

  /// 5️⃣ Get all lists for a user
  Future<Map<String, dynamic>> getUserLists() async {
final prefs = await SharedPreferences.getInstance();
final userId = prefs.getInt("userId")?.toString();
    final Uri url = Uri.parse('$baseUrl/api/shared/user?userId=$userId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch user lists: ${response.statusCode} – ${response.body}');
    }
  }

  /// Delete a shared list (ownership-safe)
  Future<Map<String, dynamic>> deleteSharedList({
    required String id,
  }) async {
final prefs = await SharedPreferences.getInstance();
final userId = prefs.getInt("userId")?.toString();
    final Uri url = Uri.parse('$baseUrl/api/shared?id=$id&userId=$userId');

    final response = await http.delete(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to delete list: ${response.statusCode} – ${response.body}');
    }
  }

  /// Speech List
  Future<Map<String, dynamic>> extractTexts(List<String> texts) async {
    final url = Uri.parse('https://studious-octo-doodle.onrender.com/extract');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'texts': texts}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Failed to extract texts: ${response.statusCode} ${response.body}');
    }
  }

  /// Profile Add/Update
  Future<bool> updateProfile({
    required String name,
    required String email,
    required File? image, // File can be null if not updating image
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("userId")?.toString();
    try {
      var uri = Uri.parse('$baseUrl/api/profile/update');
      var request = http.MultipartRequest('POST', uri);

      // Add text fields
      request.fields['userId'] = userId!;
      request.fields['name'] = name;
      request.fields['email'] = email;

      // Add image if provided
      if (image != null) {
        final mimeType = lookupMimeType(image.path)?.split('/') ?? ['image', 'jpeg'];
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            image.path,
            contentType: MediaType(mimeType[0], mimeType[1]),
          ),
        );
      }

      // Send request
      var response = await request.send();

      if (response.statusCode == 200) {
        print('Profile updated successfully');
        return true;
      } else {
        print('Failed to update profile. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  ///Get Profile
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId")?.toString();
      final uri = Uri.parse('$baseUrl/api/profile?userId=$userId');
      final response = await http.get(uri);

      print(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API Response: $data'); // debug

        // Extract the profile object
        if (data['success'] == true && data['profile'] != null) {
          return data['profile'] as Map<String, dynamic>;
        }
      } else {
        print('Failed to load profile. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
    return null;
  }

  ///OCR API
  Future<Map<String, dynamic>> uploadBillImage(File imageFile) async {
    final uri = Uri.parse('https://improved-ocr.onrender.com/extract_bill');

    // Create multipart request
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final response = await request.send();

      // Convert response to string
      final responseString = await response.stream.bytesToString();
      print("Server response: $responseString");
      if (response.statusCode == 200) {
        // Parse JSON response
        return json.decode(responseString) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Failed to upload image: ${response.statusCode} - $responseString');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

}
