//lib/Trip/widgets/P_Course_card.dart
import 'package:flutter/material.dart';

class P_CourseCard extends StatelessWidget {
  /// 네트워크 URL 또는 에셋 경로
  final String imagePath;

  /// 서버 상대경로("/images/…")일 때 붙일 베이스 URL (예: http://10.0.2.2:8080)
  /// 절대경로(http/https)나 에셋일 경우는 무시됨.
  final String? imageBaseUrl;

  final bool isFavorite;
  final int likeCount;
  final VoidCallback favorite_Pressed;
  final String title;
  final String address;
  final VoidCallback onTap;

  const P_CourseCard({
    super.key,
    required this.imagePath,
    this.imageBaseUrl,
    required this.isFavorite,
    required this.likeCount,
    required this.favorite_Pressed,
    required this.title,
    required this.address,
    required this.onTap,
  });

  String _resolveUrl() {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    if (imagePath.startsWith('/') &&
        (imageBaseUrl != null && imageBaseUrl!.isNotEmpty)) {
      final base = imageBaseUrl!.endsWith('/')
          ? imageBaseUrl!.substring(0, imageBaseUrl!.length - 1)
          : imageBaseUrl!;
      return '$base$imagePath';
    }
    return imagePath;
  }

  bool _isNetworkResolved(String resolved) =>
      resolved.startsWith('http://') || resolved.startsWith('https://');

  Widget _buildImage() {
    final resolved = _resolveUrl();
    if (_isNetworkResolved(resolved)) {
      return Image.network(
        resolved,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const SizedBox.expand(child: ColoredBox(color: Colors.black12));
        },
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/image/courseview1.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      resolved,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildImage(),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: favorite_Pressed,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: Colors.pink,
                              size: 28,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
