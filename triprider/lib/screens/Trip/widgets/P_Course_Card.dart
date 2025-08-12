import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class P_CourseCard extends StatelessWidget {
  final String imagePath; // 🔹 이미지 경로
  final bool isFavorite; // 🔹 좋아요 상태
  final int likeCount; // 🔹 좋아요 수
  final VoidCallback favorite_Pressed; // 🔹 좋아요 버튼 콜백

  const P_CourseCard({
    super.key,
    required this.imagePath,
    required this.isFavorite,
    required this.likeCount,
    required this.favorite_Pressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),

      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          children: [
            // 🔹 이미지 카드
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            Positioned(
              bottom: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '신창풍차해안도로',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(right: 145, top: 5),
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.white),
                        Text(
                          '제주특별자치도 제주시 한강면 신창리 1323',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 좋아요 버튼 + 수
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.pink,
                      size: 28,
                    ),
                    onPressed: favorite_Pressed,
                  ),
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
          ],
        ),
      ),
    );
  }
}