/// Application-wide constants
class AppConstants {
  static const String appName = 'InsightFlo';
  static const String appVersion = '1.0.0';
  
  // Database table names
  static const String newsArticlesTable = 'news_articles';
  static const String userKeywordsTable = 'user_keywords';
  static const String userDevicesTable = 'user_devices';
  static const String userPortfolioTable = 'user_portfolio';
  static const String userBookmarksTable = 'user_bookmarks';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Cache
  static const int cacheTimeoutMinutes = 30;
  
  // UI
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  
  // Error messages
  static const String networkErrorMessage = 'Network connection failed. Please check your internet connection.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
  static const String unknownErrorMessage = 'An unknown error occurred. Please try again.';
}