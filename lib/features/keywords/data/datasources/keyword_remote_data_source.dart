import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:insightflo_app/core/constants/api_constants.dart';
import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/features/keywords/data/models/keyword_model.dart';
import 'package:insightflo_app/features/auth/data/datasources/auth_remote_data_source.dart';

abstract class KeywordRemoteDataSource {
  Future<List<KeywordModel>> getKeywords(String userId);
  Future<KeywordModel> createKeyword(KeywordModel keyword);
  Future<KeywordModel> updateKeyword(KeywordModel keyword);
  Future<void> deleteKeyword(String keywordId);
  Future<List<String>> searchKeywordSuggestions(String query);
}

class KeywordRemoteDataSourceImpl implements KeywordRemoteDataSource {
  final http.Client client;
  final AuthRemoteDataSource authDataSource;

  KeywordRemoteDataSourceImpl({
    required this.client,
    required this.authDataSource,
  });

  Future<Map<String, String>> _getHeaders() async {
    final token = await authDataSource.getStoredToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<List<KeywordModel>> getKeywords(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await client.get(
        Uri.parse('${ApiConstants.baseUrl}/api/keywords?userId=$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final List<dynamic> jsonList = responseBody['data']['interests'];
        return jsonList.map((json) => KeywordModel.fromJson(json)).toList();
      } else {
        throw ServerException(
          message: json.decode(response.body)['message'] ?? 'Failed to fetch keywords',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error fetching keywords: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<KeywordModel> createKeyword(KeywordModel keyword) async {
    try {
      final headers = await _getHeaders();
      final response = await client.post(
        Uri.parse('${ApiConstants.baseUrl}/api/keywords'),
        headers: headers,
        body: json.encode(keyword.toCreateJson()),
      );

      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body)['data'];
        return KeywordModel.fromJson(jsonData);
      } else {
        throw ServerException(
          message: json.decode(response.body)['message'] ?? 'Failed to create keyword',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error creating keyword: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<KeywordModel> updateKeyword(KeywordModel keyword) async {
    try {
      final headers = await _getHeaders();
      final response = await client.put(
        Uri.parse('${ApiConstants.baseUrl}/api/keywords/${keyword.id}'),
        headers: headers,
        body: json.encode(keyword.toUpdateJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body)['data'];
        return KeywordModel.fromJson(jsonData);
      } else {
        throw ServerException(
          message: json.decode(response.body)['message'] ?? 'Failed to update keyword',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error updating keyword: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<void> deleteKeyword(String keywordId) async {
    try {
      final headers = await _getHeaders();
      final response = await client.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/keywords/$keywordId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: json.decode(response.body)['message'] ?? 'Failed to delete keyword',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error deleting keyword: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<List<String>> searchKeywordSuggestions(String query) async {
    try {
      final headers = await _getHeaders();
      final response = await client.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/api/keywords/suggestions?q=${Uri.encodeComponent(query)}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body)['data'];
        return jsonList.cast<String>();
      } else {
        throw ServerException(
          message: json.decode(response.body)['message'] ?? 'Failed to fetch keyword suggestions',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error searching keyword suggestions: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}
