/// API-related constants
class ApiConstants {
  // Base URL - 사용자가 API 서버를 직접 실행할 예정
  static const String baseUrl = 'http://localhost:3000';
  
  // API Endpoints
  static const String authEndpoint = '/api/auth';
  static const String newsEndpoint = '/api/news';
  static const String keywordsEndpoint = '/api/keywords';
  static const String portfolioEndpoint = '/api/portfolio';
  
  // Headers
  static const String contentTypeJson = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer';
  
  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
  
  // Status codes
  static const int successCode = 200;
  static const int createdCode = 201;
  static const int unauthorizedCode = 401;
  static const int forbiddenCode = 403;
  static const int notFoundCode = 404;
  static const int serverErrorCode = 500;
}