import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 웹에서는 [Image.network], 모바일에서는 [CachedNetworkImage]를 사용하는
/// 플랫폼 적응형 네트워크 이미지 위젯.
///
/// `cached_network_image` 패키지가 웹에서 캐시 동작 및 CORS 관련 이슈를
/// 일으킬 수 있으므로 웹에서는 기본 [Image.network]를 사용한다.
class AdaptiveNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context)? placeholder;
  final Widget Function(BuildContext context)? errorWidget;

  const AdaptiveNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder?.call(context) ??
              const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget?.call(context) ??
              Icon(Icons.broken_image, color: Theme.of(context).colorScheme.outline);
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, _) =>
          placeholder?.call(context) ??
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (context, _, _) =>
          errorWidget?.call(context) ??
          Icon(Icons.broken_image, color: Theme.of(context).colorScheme.outline),
    );
  }
}
