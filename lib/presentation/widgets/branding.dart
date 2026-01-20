import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';

class NBROBrand extends StatelessWidget {
  final String title;
  final double logoSize;
  final EdgeInsetsGeometry padding;
  final Color color;

  const NBROBrand({
    super.key,
    required this.title,
    this.logoSize = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.color = NBROColors.white,
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
          child: Text(
            'NBRO $title',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
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
    const logoPath = 'assets/images/nbro_logo.png';
    return FutureBuilder<bool>(
      future: _assetExists(logoPath),
      builder: (context, snapshot) {
        final hasAsset = snapshot.data == true;
        if (hasAsset) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.2),
            child: Image.asset(
              logoPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
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
