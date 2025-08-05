import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insightflo_app/features/news/domain/entities/news_entity.dart';

/// 뉴스 기사의 상세 정보를 보여주는 화면
class NewsDetailScreen extends StatelessWidget {
  final NewsEntity article;

  const NewsDetailScreen({super.key, required this.article});

  /// URL을 외부 브라우저로 실행하는 메서드
  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('URL을 열 수 없습니다: $urlString')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(article.source), elevation: 1),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기사 제목
              Text(
                article.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 기사 메타 정보 (출처, 게시일)
              Row(
                children: [
                  Icon(
                    Icons.source,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    article.source,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    article.formattedPublishedAt,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 기사 이미지
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.network(
                    article.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 16),

              // 기사 요약
              Text(
                article.summary,
                style: textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 24),

              // 키워드
              if (article.keywords.isNotEmpty) ...[
                Text(
                  '주요 키워드',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: article.keywords
                      .map(
                        (keyword) => Chip(
                          label: Text(keyword),
                          backgroundColor: colorScheme.secondaryContainer
                              .withOpacity(0.5),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _launchURL(context, article.url),
        icon: const Icon(Icons.open_in_new),
        label: const Text('원문 보기'),
      ),
    );
  }
}
