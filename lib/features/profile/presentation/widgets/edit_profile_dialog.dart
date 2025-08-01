import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../news/presentation/providers/theme_provider.dart';

/// 프로필 편집 다이얼로그 - Material 3 디자인
/// 
/// 기능:
/// - 닉네임 변경 (유효성 검증)
/// - 프로필 이미지 업로드 (갤러리/카메라)
/// - Form 검증 및 에러 처리
/// - 로딩 상태 표시
/// - 취소/저장 액션
class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  File? _selectedImage;
  bool _isLoading = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _initializeCurrentUser();
  }

  void _initializeCurrentUser() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    
    // 현재 사용자 정보로 폼 초기화
    if (user != null) {
      _nicknameController.text = user.displayName ?? user.fullName;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, authProvider, themeProvider, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final user = authProvider.currentUser;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      _buildHeader(theme, colorScheme),
                      
                      const SizedBox(height: 24),
                      
                      // 프로필 이미지 섹션
                      _buildProfileImageSection(theme, colorScheme, user),
                      
                      const SizedBox(height: 24),
                      
                      // 닉네임 입력 필드
                      _buildNicknameField(theme, colorScheme),
                      
                      const SizedBox(height: 8),
                      
                      // 도움말 텍스트
                      _buildHelpText(theme, colorScheme),
                      
                      const SizedBox(height: 32),
                      
                      // 액션 버튼들
                      _buildActionButtons(theme, colorScheme, authProvider),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 헤더 구성
  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.edit,
            color: colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '프로필 편집',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              
              Text(
                '개인정보를 수정하세요',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        
        // 닫기 버튼
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close,
            color: colorScheme.onSurfaceVariant,
          ),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  /// 프로필 이미지 섹션
  Widget _buildProfileImageSection(ThemeData theme, ColorScheme colorScheme, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '프로필 사진',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Center(
          child: Stack(
            children: [
              // 프로필 이미지 또는 기본 아바타
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : user?.profileImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              user!.profileImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 50,
                                  color: colorScheme.onPrimaryContainer,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 50,
                            color: colorScheme.onPrimaryContainer,
                          ),
              ),
              
              // 편집 버튼
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showImageSourceDialog,
                    icon: Icon(
                      Icons.camera_alt,
                      color: colorScheme.onPrimary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 이미지 에러 표시
        if (_imageError != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              _imageError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  /// 닉네임 입력 필드
  Widget _buildNicknameField(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '닉네임',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        
        const SizedBox(height: 8),
        
        TextFormField(
          controller: _nicknameController,
          decoration: InputDecoration(
            hintText: '닉네임을 입력하세요',
            prefixIcon: Icon(
              Icons.person_outline,
              color: colorScheme.onSurfaceVariant,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          validator: _validateNickname,
          textInputAction: TextInputAction.done,
          maxLength: 20,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
            return Text(
              '$currentLength/${maxLength ?? 20}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
      ],
    );
  }

  /// 도움말 텍스트
  Widget _buildHelpText(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.primary,
            size: 16,
          ),
          
          const SizedBox(width: 8),
          
          Expanded(
            child: Text(
              '닉네임은 2-20자 사이로 입력해주세요. 특수문자는 사용할 수 없습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 액션 버튼들
  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme, AuthProvider authProvider) {
    return Row(
      children: [
        // 취소 버튼
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading 
                ? null 
                : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('취소'),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // 저장 버튼
        Expanded(
          child: FilledButton(
            onPressed: _isLoading 
                ? null 
                : () => _saveProfile(authProvider),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Text('저장'),
          ),
        ),
      ],
    );
  }

  // 유틸리티 메서드들

  /// 닉네임 유효성 검증
  String? _validateNickname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '닉네임을 입력해주세요';
    }
    
    final trimmed = value.trim();
    
    if (trimmed.length < 2) {
      return '닉네임은 최소 2자 이상이어야 합니다';
    }
    
    if (trimmed.length > 20) {
      return '닉네임은 최대 20자까지 가능합니다';
    }
    
    // 특수문자 검증 (한글, 영문, 숫자, 공백만 허용)
    final RegExp validPattern = RegExp(r'^[가-힣a-zA-Z0-9\s]+$');
    if (!validPattern.hasMatch(trimmed)) {
      return '한글, 영문, 숫자만 사용할 수 있습니다';
    }
    
    // 연속된 공백 검증
    if (trimmed.contains('  ')) {
      return '연속된 공백은 사용할 수 없습니다';
    }
    
    return null;
  }

  /// 이미지 소스 선택 다이얼로그
  Future<void> _showImageSourceDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                '프로필 사진 선택',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 카메라 옵션
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('카메라로 촬영'),
                subtitle: const Text('새로운 사진을 촬영합니다'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              
              // 갤러리 옵션
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                title: const Text('갤러리에서 선택'),
                subtitle: const Text('저장된 사진을 선택합니다'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              
              // 현재 사진 제거 (선택된 이미지나 기존 이미지가 있는 경우에만)
              if (_selectedImage != null || 
                  (context.read<AuthProvider>().currentUser?.profileImageUrl != null)) ...[
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  title: const Text('기본 이미지로 변경'),
                  subtitle: const Text('현재 프로필 사진을 제거합니다'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeImage();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 이미지 선택
  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _imageError = null;
      });
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        
        // 파일 크기 검증 (5MB 제한)
        final fileSize = await imageFile.length();
        if (fileSize > 5 * 1024 * 1024) {
          setState(() {
            _imageError = '이미지 크기는 5MB 이하여야 합니다';
          });
          return;
        }
        
        setState(() {
          _selectedImage = imageFile;
        });
      }
    } catch (e) {
      setState(() {
        _imageError = '이미지를 선택할 수 없습니다: ${e.toString()}';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 이미지 제거
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageError = null;
    });
  }

  /// 프로필 저장
  Future<void> _saveProfile(AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // TODO: 실제 API 호출로 프로필 업데이트
      // final nickname = _nicknameController.text.trim();
      // await authProvider.updateUserProfile(
      //   displayName: nickname,
      //   photoFile: _selectedImage,
      // );
      
      // 임시로 지연 시뮬레이션
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                const Text('프로필이 업데이트되었습니다'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 업데이트 실패: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}