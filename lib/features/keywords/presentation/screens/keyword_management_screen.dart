import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:insightflo_app/features/keywords/domain/entities/keyword_entity.dart';
import 'package:insightflo_app/features/keywords/presentation/providers/keyword_provider.dart';
import 'package:insightflo_app/features/news/presentation/widgets/confirmation_dialog.dart';

class KeywordManagementScreen extends StatefulWidget {
  const KeywordManagementScreen({super.key});

  @override
  State<KeywordManagementScreen> createState() => _KeywordManagementScreenState();
}

class _KeywordManagementScreenState extends State<KeywordManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    
    // 키워드 화면 진입 로그
    debugPrint('🎯 KeywordManagementScreen: initState called');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🎯 KeywordManagementScreen: Loading keywords...');
      context.read<KeywordProvider>().loadKeywords();
    });

    _searchController.addListener(() {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        context.read<KeywordProvider>().searchSuggestions(query);
        setState(() => _showSuggestions = true);
      } else {
        context.read<KeywordProvider>().clearSuggestions();
        setState(() => _showSuggestions = false);
      }
    });

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        // 짧은 지연 후 제안 숨기기 (사용자가 제안을 클릭할 시간 제공)
        Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _showSuggestions = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎯 KeywordManagementScreen: build called');
    
    return WillPopScope(
      onWillPop: () async {
        debugPrint('🎯 KeywordManagementScreen: Back button pressed - going to home');
        context.go('/home');
        return false; // 기본 뒤로가기 동작 방지
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('키워드 관리'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            debugPrint('🔙 키워드 화면에서 뒤로 가기 - 홈으로 이동');
            context.go('/home');
          },
        ),
      ),
      body: Column(
        children: [
          // 검색 입력 영역
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 검색 입력 필드
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: '새 키워드를 입력하세요...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<KeywordProvider>().clearSuggestions();
                              setState(() => _showSuggestions = false);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  onSubmitted: _addKeyword,
                ),
                const SizedBox(height: 8),
                
                // 자동완성 제안
                if (_showSuggestions)
                  Consumer<KeywordProvider>(
                    builder: (context, provider, child) {
                      if (provider.suggestions.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          itemCount: provider.suggestions.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                          ),
                          itemBuilder: (context, index) {
                            final suggestion = provider.suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.search,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                suggestion,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              onTap: () => _addKeyword(suggestion),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // 키워드 목록 영역
          Expanded(
            child: Consumer<KeywordProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.keywords.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.errorMessage,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.loadKeywords(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.keywords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.label_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '아직 등록된 키워드가 없습니다',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '위 검색창에서 관심 있는 키워드를 추가해보세요',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadKeywords(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.keywords.length,
                    itemBuilder: (context, index) {
                      final keyword = provider.keywords[index];
                      return _KeywordCard(
                        keyword: keyword,
                        onDelete: () => _deleteKeyword(keyword),
                        onWeightChanged: (weight) => _updateKeywordWeight(keyword.id, weight),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _addKeyword(String keywordText) async {
    if (keywordText.trim().isEmpty) return;

    final provider = context.read<KeywordProvider>();
    final success = await provider.createKeyword(keywordText.trim());

    if (success) {
      _searchController.clear();
      setState(() => _showSuggestions = false);
      _searchFocusNode.unfocus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('키워드 "$keywordText"가 추가되었습니다'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteKeyword(KeywordEntity keyword) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: '키워드 삭제',
        content: '키워드 "${keyword.keyword}"를 삭제하시겠습니까?',
        confirmText: '삭제',
        cancelText: '취소',
      ),
    );

    if (confirmed == true) {
      final provider = context.read<KeywordProvider>();
      final success = await provider.deleteKeyword(keyword.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '키워드가 삭제되었습니다' 
                : provider.errorMessage),
            backgroundColor: success 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateKeywordWeight(String keywordId, double weight) async {
    final provider = context.read<KeywordProvider>();
    await provider.updateKeywordWeight(keywordId, weight);
  }
}

class _KeywordCard extends StatelessWidget {
  final KeywordEntity keyword;
  final VoidCallback onDelete;
  final ValueChanged<double> onWeightChanged;

  const _KeywordCard({
    required this.keyword,
    required this.onDelete,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Chip(
                    label: Text(
                      keyword.keyword,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onDelete,
                  tooltip: '키워드 삭제',
                ),
              ],
            ),
            
            if (keyword.category != null) ...[
              const SizedBox(height: 8),
              Text(
                '카테고리: ${keyword.category}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '중요도:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: keyword.weight.clamp(0.1, 1.0),
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: '${(keyword.weight.clamp(0.1, 1.0) * 100).round()}%',
                    onChanged: (value) {
                      // 값을 0.1-1.0 범위로 제한하고 소수점 1자리로 반올림
                      final clampedValue = double.parse((value.clamp(0.1, 1.0)).toStringAsFixed(1));
                      onWeightChanged(clampedValue);
                    },
                  ),
                ),
                Text(
                  '${(keyword.weight.clamp(0.1, 1.0) * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '등록일: ${_formatDate(keyword.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}