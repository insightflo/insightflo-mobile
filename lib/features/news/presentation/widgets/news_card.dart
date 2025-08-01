import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/news_entity.dart';
import '../providers/news_provider.dart';

/// Custom widget for displaying news article cards
class NewsCard extends StatelessWidget {
  final NewsEntity article;
  final String userId;
  final VoidCallback? onTap;

  const NewsCard({
    super.key,
    required this.article,
    required this.userId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with source and sentiment
              Row(
                children: [
                  // Source
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      article.source,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Sentiment indicator
                  Text(
                    _getSentimentEmoji(article.sentimentScore),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  
                  const Spacer(),
                  
                  // Time indicator for fresh articles
                  if (article.isFresh)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEW',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  
                  const SizedBox(width: 8),
                  
                  // Bookmark button
                  Consumer<NewsProvider>(
                    builder: (context, newsProvider, _) {
                      return IconButton(
                        icon: Icon(
                          article.isBookmarked 
                              ? Icons.bookmark 
                              : Icons.bookmark_border,
                          color: article.isBookmarked 
                              ? colorScheme.primary 
                              : colorScheme.onSurface,
                        ),
                        onPressed: () async {
                          if (article.isBookmarked) {
                            await newsProvider.removeBookmarkFromArticle(userId, article.id);
                          } else {
                            await newsProvider.bookmarkNewsArticle(userId, article.id);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Article image (if available)
              if (article.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    article.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported,
                          color: colorScheme.onSurfaceVariant,
                          size: 48,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Title
              Text(
                article.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Summary
              Text(
                article.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Keywords and metadata
              Row(
                children: [
                  // Keywords (show first 3)
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: article.keywords.take(3).map((keyword) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            keyword,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Published time
                  Text(
                    article.formattedPublishedAt,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSentimentEmoji(double sentimentScore) {
    if (sentimentScore > 0.1) {
      return '📈'; // Positive sentiment
    } else if (sentimentScore < -0.1) {
      return '📉'; // Negative sentiment
    } else {
      return '➖'; // Neutral sentiment
    }
  }
}