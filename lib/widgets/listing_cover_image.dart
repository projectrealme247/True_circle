import 'package:flutter/material.dart';

import '../utils/listing_data.dart';
import '../utils/listing_media.dart';
import 'listing_image_placeholder.dart';

/// Cover photo for cards and detail (uploaded, network URL, or placeholder).
class ListingCoverImage extends StatefulWidget {
  const ListingCoverImage({
    super.key,
    required this.listing,
    this.height = 88,
    this.borderRadius,
    this.placeholderLabel = 'No images',
    this.fill = false,
    this.compact = false,
  });

  final Map<String, dynamic> listing;
  final double? height;
  final BorderRadius? borderRadius;
  final String placeholderLabel;
  final bool fill;
  final bool compact;

  static const cardImageHeight = 158.0;

  @override
  State<ListingCoverImage> createState() => _ListingCoverImageState();
}

class _ListingCoverImageState extends State<ListingCoverImage> {
  bool _loadFailed = false;

  @override
  void didUpdateWidget(ListingCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing['id'] != widget.listing['id']) {
      _loadFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    final cover = ListingData.coverImageDataUri(widget.listing);
    final bytes = ListingMedia.decodeDataUri(cover);

    if (bytes != null) {
      final image = Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: widget.fill ? double.infinity : null,
        height: widget.fill ? double.infinity : widget.height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
      return _wrap(radius, image);
    }

    if (_loadFailed) {
      return _wrap(radius, _placeholder());
    }

    final url = ListingData.networkCoverUrl(widget.listing);
    if (url == null || url.isEmpty) {
      return _wrap(radius, _placeholder());
    }

    final image = Image.network(
      url,
      fit: BoxFit.cover,
      width: widget.fill ? double.infinity : null,
      height: widget.fill ? double.infinity : widget.height,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _loadingPlaceholder();
      },
      errorBuilder: (_, __, ___) {
        if (!_loadFailed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _loadFailed = true);
          });
        }
        return _placeholder();
      },
    );

    return _wrap(radius, image);
  }

  Widget _wrap(BorderRadius radius, Widget child) {
    if (widget.fill) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox.expand(child: child),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: child,
      ),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)),
      ),
    );
  }

  Widget _placeholder() {
    if (widget.fill) {
      return ListingImagePlaceholder(
        fill: true,
        borderRadius: widget.borderRadius,
        label: widget.placeholderLabel,
        compact: widget.compact,
      );
    }
    return ListingImagePlaceholder(
      height: widget.height ?? 88,
      borderRadius: widget.borderRadius,
      label: widget.placeholderLabel,
      compact: widget.compact,
    );
  }
}
