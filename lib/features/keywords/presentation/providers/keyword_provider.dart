import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:insightflo_app/features/keywords/domain/entities/keyword_entity.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/get_keywords.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/create_keyword.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/update_keyword.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/delete_keyword.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/search_keyword_suggestions.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/core/utils/logger.dart';

enum KeywordState { initial, loading, loaded, error }

class KeywordProvider extends ChangeNotifier {
  final GetKeywords _getKeywords;
  final CreateKeyword _createKeyword;
  final UpdateKeyword _updateKeyword;
  final DeleteKeyword _deleteKeyword;
  final SearchKeywordSuggestions _searchKeywordSuggestions;
  final AuthProvider _authProvider;

  // UUID 생성기
  static const _uuid = Uuid();
  
  // 로컬 키워드 관리를 위한 ID 생성기
  int _nextLocalId = 1;

  // 키워드 변경 시 뉴스 갱신을 위한 콜백
  Function(String userId)? _onKeywordChanged;

  KeywordProvider({
    required GetKeywords getKeywords,
    required CreateKeyword createKeyword,
    required UpdateKeyword updateKeyword,
    required DeleteKeyword deleteKeyword,
    required SearchKeywordSuggestions searchKeywordSuggestions,
    required AuthProvider authProvider,
  })  : _getKeywords = getKeywords,
        _createKeyword = createKeyword,
        _updateKeyword = updateKeyword,
        _deleteKeyword = deleteKeyword,
        _searchKeywordSuggestions = searchKeywordSuggestions,
        _authProvider = authProvider;

  KeywordState _state = KeywordState.initial;
  List<KeywordEntity> _keywords = [];
  List<String> _suggestions = [];
  String _errorMessage = '';
  Timer? _debounceTimer;

  // Getters
  KeywordState get state => _state;
  List<KeywordEntity> get keywords => _keywords;
  List<String> get suggestions => _suggestions;
  String get errorMessage => _errorMessage;
  bool get isLoading => _state == KeywordState.loading;
  bool get hasError => _state == KeywordState.error;

  // Set callback for keyword changes (to trigger news refresh)
  void setOnKeywordChangedCallback(Function(String userId)? callback) {
    _onKeywordChanged = callback;
  }

  // Load keywords from local storage (guest mode) or server (authenticated)
  Future<void> loadKeywords() async {
    try {
      AppLogger.info('KeywordProvider: Starting loadKeywords');
      
      // 이미 로드된 상태이고 키워드가 있다면 로딩 상태로 변경하지 않음
      final shouldShowLoading = _keywords.isEmpty || _state == KeywordState.initial;
      if (shouldShowLoading) {
        _setState(KeywordState.loading);
      }

      // 타임아웃을 적용한 초기화 대기
      await _waitForAuthStateInitialization().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('KeywordProvider: AuthProvider initialization timeout, proceeding with guest mode');
        },
      );

      final userId = _authProvider.isGuestMode ? 'local_user' : _authProvider.currentUser?.id;
      AppLogger.info('KeywordProvider: Auth state determined - isGuestMode: ${_authProvider.isGuestMode}, userId: $userId');

      if (_authProvider.isGuestMode) {
        // Guest mode - load from local SQLite only
        AppLogger.info('KeywordProvider: Loading keywords in guest mode (local only)');
        final result = await _getKeywords(userId!);
        
        result.fold(
          (failure) {
            AppLogger.info('KeywordProvider: No local keywords found, starting with empty list');
            _keywords = [];
            _setState(KeywordState.loaded);
          },
          (keywords) {
            AppLogger.info('KeywordProvider: Loaded ${keywords.length} local keywords');
            _keywords = keywords;
            _setState(KeywordState.loaded);
          },
        );
      } else if (_authProvider.isAuthenticated && userId != null) {
        // Authenticated mode - load from server
        AppLogger.info('KeywordProvider: Loading keywords for authenticated user: $userId');
        
        final result = await _getKeywords(userId);
        result.fold(
          (failure) {
            AppLogger.error('KeywordProvider: Failed to load server keywords', failure.message);
            _setError(failure.message);
          },
          (keywords) {
            AppLogger.info('KeywordProvider: Loaded ${keywords.length} server keywords');
            _keywords = keywords;
            _setState(KeywordState.loaded);
          },
        );
      } else {
        // Fallback - 초기화가 완료되지 않았어도 게스트 모드로 진행
        AppLogger.warning('KeywordProvider: Falling back to guest mode');
        _keywords = [];
        _setState(KeywordState.loaded);
      }
    } catch (e) {
      AppLogger.error('KeywordProvider: Unexpected error in loadKeywords', e);
      _setError('Unexpected error: ${e.toString()}');
    }
  }

  /// Enhanced method to wait for AuthProvider initialization
  Future<void> _waitForAuthStateInitialization() async {
    int retryCount = 0;
    const maxRetries = 50; // 5초 최대 대기
    const retryDelay = Duration(milliseconds: 100);
    
    AppLogger.info('KeywordProvider: Waiting for AuthProvider initialization...');
    
    while (retryCount < maxRetries) {
      // AuthProvider 초기화 완료 체크
      if (_authProvider.isInitialized) {
        AppLogger.info('KeywordProvider: AuthProvider initialized after ${retryCount} retries');
        return;
      }
      
      await Future.delayed(retryDelay);
      retryCount++;
      
      if (retryCount % 10 == 0) {
        AppLogger.info('KeywordProvider: Still waiting for AuthProvider initialization (retry $retryCount/$maxRetries)');
      }
    }
    
    // 최대 대기 시간 초과 - 강제로 진행
    AppLogger.warning('KeywordProvider: AuthProvider initialization timeout after ${maxRetries * 100}ms, proceeding anyway');
  }

  // Create keyword - local first
  Future<bool> createKeyword(String keywordText, {String? category}) async {
    // Check for duplicates
    if (_keywords.any((k) => k.keyword.toLowerCase() == keywordText.toLowerCase())) {
      _setError('Keyword already exists');
      return false;
    }

    _setState(KeywordState.loading);

    final userId = _authProvider.isGuestMode ? 'local_user' : _authProvider.currentUser!.id;

    final keyword = KeywordEntity(
      id: _authProvider.isGuestMode ? 'local_${_nextLocalId++}' : _uuid.v4(), // UUID for authenticated users
      userId: userId,
      keyword: keywordText.trim(),
      weight: 1.0,
      category: category,
      createdAt: DateTime.now(),
    );

    final result = await _createKeyword(keyword);
    return result.fold(
      (failure) {
        AppLogger.error('KeywordProvider: Failed to create keyword', failure.message);
        _setError(failure.message);
        return false;
      },
      (createdKeyword) {
        AppLogger.info('KeywordProvider: Successfully created keyword: ${createdKeyword.keyword}');
        _keywords.add(createdKeyword);
        _setState(KeywordState.loaded);
        
        // Trigger news refresh after keyword creation
        _triggerNewsRefresh();
        
        return true;
      },
    );
  }

  // Update keyword
  Future<bool> updateKeyword(KeywordEntity keyword) async {
    _setState(KeywordState.loading);

    final result = await _updateKeyword(keyword);
    return result.fold(
      (failure) {
        _setError(failure.message);
        return false;
      },
      (updatedKeyword) {
        final index = _keywords.indexWhere((k) => k.id == updatedKeyword.id);
        if (index != -1) {
          _keywords[index] = updatedKeyword;
          _setState(KeywordState.loaded);
        }
        return true;
      },
    );
  }

  // Delete keyword
  Future<bool> deleteKeyword(String keywordId) async {
    _setState(KeywordState.loading);

    final result = await _deleteKeyword(keywordId);
    return result.fold(
      (failure) {
        _setError(failure.message);
        return false;
      },
      (_) {
        _keywords.removeWhere((k) => k.id == keywordId);
        _setState(KeywordState.loaded);
        
        // Trigger news refresh after keyword deletion
        _triggerNewsRefresh();
        
        return true;
      },
    );
  }

  // Search suggestions with debouncing
  void searchSuggestions(String query) {
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      _suggestions.clear();
      notifyListeners();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final result = await _searchKeywordSuggestions(query);
      result.fold(
        (failure) {
          // Silently fail for suggestions
          _suggestions.clear();
        },
        (suggestions) {
          _suggestions = suggestions
              .where((s) => !_keywords.any((k) => k.keyword.toLowerCase() == s.toLowerCase()))
              .toList();
        },
      );
      notifyListeners();
    });
  }

  // Update keyword weight
  Future<bool> updateKeywordWeight(String keywordId, double weight) async {
    // 값을 0.1-1.0 범위로 제한하고 소수점 1자리로 반올림
    final clampedWeight = double.parse((weight.clamp(0.1, 1.0)).toStringAsFixed(1));
    
    final keyword = _keywords.firstWhere((k) => k.id == keywordId);
    final updatedKeyword = KeywordEntity(
      id: keyword.id,
      userId: keyword.userId,
      keyword: keyword.keyword,
      weight: clampedWeight,
      category: keyword.category,
      createdAt: keyword.createdAt,
    );
    return await updateKeyword(updatedKeyword);
  }

  // Clear suggestions
  void clearSuggestions() {
    _suggestions.clear();
    notifyListeners();
  }

  // Private methods
  void _setState(KeywordState state) {
    _state = state;
    _errorMessage = '';
    notifyListeners();
  }

  void _setError(String message) {
    _state = KeywordState.error;
    _errorMessage = message;
    notifyListeners();
  }

  // Trigger news refresh when keywords change
  void _triggerNewsRefresh() {
    if (_onKeywordChanged != null && _authProvider.currentUser != null) {
      final userId = _authProvider.isGuestMode ? 'local_user' : _authProvider.currentUser!.id;
      AppLogger.info('KeywordProvider: Triggering news refresh for user: $userId');
      _onKeywordChanged!(userId);
    } else {
      AppLogger.info('KeywordProvider: No callback set or user not authenticated, skipping news refresh');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}