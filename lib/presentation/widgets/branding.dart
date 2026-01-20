import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';

class NBROBrand extends StatelessWidget {
  final String title;
  final double logoSize;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool showFullName;

  const NBROBrand({
    super.key,
    required this.title,
    this.logoSize = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.color = NBROColors.white,
    this.showFullName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Try load asset logo if present; otherwise show monogram
        _LogoDynamic(size: logoSize),
        Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showFullName)
                Text(
                  'National Building Research Organization',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                )
              else
                Text(
                  'NBRO $title',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              if (showFullName && title.isNotEmpty)
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w400,
                      ),
                ),
            ],
          ),
        )
      ],
    );
  }
}

class _LogoDynamic extends StatelessWidget {
  final double size;
  const _LogoDynamic({required this.size});

  static Future<bool> _assetExists(String path) async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> jsonMap = json.decode(manifest);
      return jsonMap.keys.contains(path);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const logoPath = 'assets/icons/pasted-image.png';
    return FutureBuilder<bool>(
      future: _assetExists(logoPath),
      builder: (context, snapshot) {
        final hasAsset = snapshot.data == true;
        if (hasAsset) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(size * 0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(size * 0.1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.15),
              child: Image.asset(
                logoPath,
                width: size * 0.8,
                height: size * 0.8,
                fit: BoxFit.contain,
              ),
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [NBROColors.primaryLight, NBROColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'NB',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              height: 1.0,
            ),
          ),
        );
      },
    );
  }
}
