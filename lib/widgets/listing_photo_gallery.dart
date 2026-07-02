import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/listing_data.dart';
import '../utils/listing_media.dart';
import 'listing_image_placeholder.dart';
import 'listing_gallery_nav_button.dart';

/// Hero gallery with prev/next arrows and optional thumbnail strip.
class ListingPhotoGallery extends StatefulWidget {
  const ListingPhotoGallery({
    super.key,
    required this.listing,
    this.height = 280,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.showQuickEdit = false,
    this.onQuickEdit,
  });

  final Map<String, dynamic> listing;
  final double height;
  final BorderRadius borderRadius;
  final bool showQuickEdit;
  final VoidCallback? onQuickEdit;

  @override
  State<ListingPhotoGallery> createState() => _ListingPhotoGalleryState();
}

class _ListingPhotoGalleryState extends State<ListingPhotoGallery> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _images {
    final uris = ListingData.imageDataUris(widget.listing);
    if (uris.isNotEmpty) return uris;
    final cover = ListingData.networkCoverUrl(widget.listing);
    if (cover != null && cover.isNotEmpty) return [cover];
    return const [];
  }

  bool _isNetworkUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final hasMultiple = images.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: widget.borderRadius,
                child: images.isEmpty
                    ? ListingImagePlaceholder(
                        height: widget.height,
                        borderRadius: widget.borderRadius,
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (next) => setState(() => _index = next),
                        itemBuilder: (context, index) {
                          final source = images[index];
                          if (_isNetworkUrl(source)) {
                            return Image.network(
                              source,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: widget.height,
                              errorBuilder: (_, __, ___) =>
                                  _placeholder(index),
                            );
                          }
                          final bytes = ListingMedia.decodeDataUri(source);
                          if (bytes == null) return _placeholder(index);
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: widget.height,
                            gaplessPlayback: true,
                          );
                        },
                      ),
              ),
              if (hasMultiple) ...[
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: ListingGalleryNavButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _index > 0,
                      onTap: () => _goTo(_index - 1),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: ListingGalleryNavButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _index < images.length - 1,
                      onTap: () => _goTo(_index + 1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_index + 1}/${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.showQuickEdit && widget.onQuickEdit != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: widget.onQuickEdit,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Quick edit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
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
        if (hasMultiple) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _index;
                final source = images[index];
                Widget thumb;
                if (_isNetworkUrl(source)) {
                  thumb = Image.network(source, fit: BoxFit.cover);
                } else {
                  final bytes = ListingMedia.decodeDataUri(source);
                  thumb = bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : const ColoredBox(color: Color(0xFFE5E7EB));
                }
                return GestureDetector(
                  onTap: () => _goTo(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent
                            : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: thumb,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _goTo(int index) {
    if (index < 0 || index >= _images.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    setState(() => _index = index);
  }

  Widget _placeholder(int index) {
    return ListingImagePlaceholder(
      height: widget.height,
      label: 'Photo ${index + 1}',
    );
  }
}
