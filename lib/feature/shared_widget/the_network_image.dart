
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Standard network image with a shimmer placeholder.
class TheNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TheNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    // Avoid using infinity as an image cache dimension.
    final cacheWidth = width != null && width!.isFinite && width! > 0
        ? (width! * devicePixelRatio).ceil()
        : null;

    final cacheHeight = height != null && height!.isFinite && height! > 0
        ? (height! * devicePixelRatio).ceil()
        : null;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,

        // Reduce decoded image memory usage.
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,

        placeholder: (context, _) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            width: width,
            height: height,
            color: Colors.white,
          ),
        ),

        errorWidget: (context, _, __) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.image_not_supported_outlined,
          ),
        ),
      ),
    );
  }
}
