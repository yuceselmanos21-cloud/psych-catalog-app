import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import '../config/app_config.dart';

/// Optimize edilmiş network image widget'ı
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      color: backgroundColor ?? (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    final defaultErrorWidget = Container(
      width: width,
      height: height,
      color: backgroundColor ?? (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      child: Icon(
        Icons.broken_image,
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
        size: (width != null && height != null) 
            ? (width! < height! ? width! * 0.5 : height! * 0.5)
            : 48,
      ),
    );

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? defaultErrorWidget,
      fadeInDuration: AppConstants.shortAnimation,
      fadeOutDuration: AppConstants.shortAnimation,
      memCacheWidth: width != null ? width!.toInt() : null,
      memCacheHeight: height != null ? height!.toInt() : null,
      maxWidthDiskCache: AppConstants.maxImageWidth,
      maxHeightDiskCache: AppConstants.maxImageHeight,
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Circle avatar için optimize edilmiş image
class OptimizedCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const OptimizedCircleAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? 
        (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final txtColor = textColor ?? 
        (isDark ? Colors.grey.shade300 : Colors.grey.shade700);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          name != null && name!.isNotEmpty ? name![0].toUpperCase() : '?',
          style: TextStyle(
            color: txtColor,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.6,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: ClipOval(
        child: OptimizedImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: txtColor,
              ),
            ),
          ),
          errorWidget: CircleAvatar(
            radius: radius,
            backgroundColor: bgColor,
            child: Text(
              name != null && name!.isNotEmpty ? name![0].toUpperCase() : '?',
              style: TextStyle(
                color: txtColor,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
