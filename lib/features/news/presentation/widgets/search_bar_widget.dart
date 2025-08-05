import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insightflo_app/features/news/presentation/providers/news_provider.dart';

/// Custom search bar widget for news search functionality
class SearchBarWidget extends StatefulWidget {
  final String userId;
  final String? hintText;
  final Function(String)? onSearchChanged;
  final bool autofocus;

  const SearchBarWidget({
    super.key,
    required this.userId,
    this.hintText,
    this.onSearchChanged,
    this.autofocus = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    
    _focusNode.addListener(() {
      setState(() {
        _isSearchActive = _focusNode.hasFocus;
      });
    });

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    final newsProvider = context.read<NewsProvider>();
    newsProvider.searchNewsArticles(query.trim(), refresh: true);
    
    widget.onSearchChanged?.call(query.trim());
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _controller.clear();
    final newsProvider = context.read<NewsProvider>();
    newsProvider.getPersonalizedNewsForUser(widget.userId, refresh: true);
    
    widget.onSearchChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<NewsProvider>(
      builder: (context, newsProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _isSearchActive 
                  ? colorScheme.primary 
                  : colorScheme.outline.withValues(alpha: 0.5),
              width: _isSearchActive ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Search icon
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Icon(
                  Icons.search,
                  color: _isSearchActive 
                      ? colorScheme.primary 
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              
              // Search input field
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Search financial news...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _onSearchSubmitted,
                  onChanged: (value) {
                    // Optional: Implement real-time search with debouncing
                    // For now, we'll only search on submit
                  },
                ),
              ),
              
              // Clear/Loading indicator
              if (_controller.text.isNotEmpty || newsProvider.isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: newsProvider.isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: _clearSearch,
                          splashRadius: 16,
                          tooltip: 'Clear search',
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}