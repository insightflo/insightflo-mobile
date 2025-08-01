import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SupabaseConfig {
  static late final Supabase _supabase;
  static late final String _supabaseUrl;
  static SupabaseClient get client => _supabase.client;
  static String get supabaseUrl => _supabaseUrl;
  
  // Secure storage for authentication tokens
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<void> initialize() async {
    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
      
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception('Supabase URL or Anon Key not found in environment variables');
      }
      
      // Store URL for later access
      _supabaseUrl = supabaseUrl;
      
      // Initialize Supabase with enhanced auth configuration
      _supabase = await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: dotenv.env['ENVIRONMENT'] == 'development',
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
          localStorage: _CustomLocalStorage(),
        ),
      );
      
      // Set up auth state listener for automatic token management
      _setupAuthStateListener();
      
    } catch (e) {
      throw Exception('Failed to initialize Supabase: $e');
    }
  }
  
  // Set up authentication state change listener
  static void _setupAuthStateListener() {
    client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        // Store session securely
        _storeSession(session);
      } else {
        // Clear stored session
        _clearStoredSession();
      }
    });
  }
  
  // Store session securely
  static Future<void> _storeSession(Session session) async {
    try {
      await _storage.write(
        key: 'supabase_session', 
        value: jsonEncode(session.toJson()),
      );
    } catch (e) {
      // Use debugPrint for production safety
      debugPrint('Failed to store session: $e');
    }
  }
  
  // Clear stored session
  static Future<void> _clearStoredSession() async {
    try {
      await _storage.delete(key: 'supabase_session');
    } catch (e) {
      debugPrint('Failed to clear session: $e');
    }
  }
  
  // Restore session on app start
  static Future<void> restoreSession() async {
    try {
      final sessionString = await _storage.read(key: 'supabase_session');
      if (sessionString != null) {
        final sessionData = jsonDecode(sessionString);
        final session = Session.fromJson(sessionData);
        if (session != null) {
          await client.auth.recoverSession(jsonEncode(session.toJson()));
        }
      }
    } catch (e) {
      debugPrint('Failed to restore session: $e');
      // Clear invalid session
      await _clearStoredSession();
    }
  }
  
  // Auth helper methods
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  static Session? get currentSession => client.auth.currentSession;
  
  // Auth stream for reactive UI
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
  
  // Database helper
  static SupabaseQueryBuilder from(String table) => client.from(table);
  
  // Storage helper
  static SupabaseStorageClient get storage => client.storage;
  
  // Realtime helper
  static RealtimeClient get realtime => client.realtime;
}

// Custom localStorage implementation for secure token storage
class _CustomLocalStorage extends LocalStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> initialize() async {
    // Initialize if needed
  }

  @override
  Future<String?> accessToken() async {
    return await _storage.read(key: 'supabase_access_token');
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: 'supabase_session', value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: 'supabase_session');
    await _storage.delete(key: 'supabase_access_token');
  }
}