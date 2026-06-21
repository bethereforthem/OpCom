import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../theme/app_theme.dart';

class Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const Avatar({super.key, required this.name, this.imageUrl, this.size = 40});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // Server-relative paths (e.g. /media/avatar/{userId}) need the API host
  // prepended before a plain NetworkImage can load them; already-absolute
  // URLs (http://...) pass through untouched.
  String? get _resolvedUrl {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    return url.startsWith('/') ? '$kBaseUrl$url' : url;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedUrl;
    if (resolved != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(resolved),
      );
    }
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient, shape: BoxShape.circle),
      child: Text(_initials,
          style: TextStyle(color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.bold)),
    );
  }
}
