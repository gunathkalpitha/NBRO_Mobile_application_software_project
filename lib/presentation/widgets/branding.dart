import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';

/// Gold Shield Logo Badge for Super Admin / Dev Control Portal
class SuperAdminBrandLogo extends StatelessWidget {
  final double size;
  const SuperAdminBrandLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFFD700), // Royal Gold
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4A148C), // Deep Purple
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.shield,
          color: Color(0xFFFFD700),
          size: 18,
        ),
      ),
    );
  }
}

class NBROBrand extends StatelessWidget {
  final String title;
  final double logoSize;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool showFullName;
  final bool isSuperAdmin;

  const NBROBrand({
    super.key,
    required this.title,
    this.logoSize = 32,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.color = NBROColors.white,
    this.showFullName = false,
    this.isSuperAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSuperAdmin)
          SuperAdminBrandLogo(size: logoSize)
        else
          _LogoDynamic(size: logoSize),
        Flexible(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showFullName)
                  Text(
                    isSuperAdmin
                        ? 'SUPER ADMIN PORTAL'
                        : (isSmallScreen 
                            ? 'NBRO'
                            : 'National Building Research Organization'),
                    style: TextStyle(
                      color: isSuperAdmin ? const Color(0xFFFFD700) : color,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 15 : 14,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    isSuperAdmin ? 'SUPER ADMIN' : 'NBRO $title',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isSuperAdmin ? const Color(0xFFFFD700) : color,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (showFullName && title.isNotEmpty)
                  Text(
                    title,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
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
    const logoPath = 'assets/icons/pasted-image.png';
    return FutureBuilder<bool>(
      future: _assetExists(logoPath),
      builder: (context, snapshot) {
        final hasAsset = snapshot.data == true;
        if (hasAsset) {
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: Image.asset(
                logoPath,
                width: size * 0.85,
                height: size * 0.85,
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
              fontSize: 13,
              height: 1.0,
            ),
          ),
        );
      },
    );
  }
}
