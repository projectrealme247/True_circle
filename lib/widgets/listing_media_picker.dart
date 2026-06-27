import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/listing_media.dart';

/// Image/video picker with previews for the add-listing form.
class ListingMediaPicker extends StatelessWidget {
  const ListingMediaPicker({
    super.key,
    required this.images,
    required this.video,
    required this.onImagesChanged,
    required this.onVideoChanged,
    required this.enabled,
    this.onMessage,
  });

  final List<String> images;
  final String? video;
  final ValueChanged<List<String>> onImagesChanged;
  final ValueChanged<String?> onVideoChanged;
  final bool enabled;
  final void Function(String message)? onMessage;

  Future<void> _pickImages() async {
    if (!enabled) return;
    final remaining = ListingMedia.maxImages - images.length;
    if (remaining <= 0) {
      onMessage?.call('You can add up to ${ListingMedia.maxImages} photos.');
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final next = List<String>.from(images);
    for (final file in result.files) {
      if (next.length >= ListingMedia.maxImages) break;
      final bytes = file.bytes;
      if (bytes == null) continue;
      if (bytes.length > ListingMedia.maxBytesPerImage) {
        onMessage?.call('${file.name} is too large (max ~1.5 MB).');
        continue;
      }
      final mime = ListingMedia.guessImageMime(file.extension) ?? 'image/jpeg';
      next.add(ListingMedia.encodeBytes(bytes, mime: mime));
    }

    if (next.length == images.length) {
      onMessage?.call('No photos were added.');
      return;
    }
    onImagesChanged(next);
  }

  Future<void> _pickVideo() async {
    if (!enabled) return;
    if (video != null) {
      onMessage?.call('Remove the current video before adding another.');
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      onMessage?.call('Could not read video file.');
      return;
    }
    if (bytes.length > ListingMedia.maxBytesPerVideo) {
      onMessage?.call('Video is too large (max ~8 MB).');
      return;
    }
    final mime = ListingMedia.guessVideoMime(file.extension) ?? 'video/mp4';
    onVideoChanged(ListingMedia.encodeBytes(bytes, mime: mime));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Photos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1C1E21),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Optional · ${images.length}/${ListingMedia.maxImages}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (images.isEmpty)
          _emptyPreview()
        else
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _thumb(
                dataUri: images[index],
                onRemove: enabled
                    ? () {
                        final next = List<String>.from(images)..removeAt(index);
                        onImagesChanged(next);
                      }
                    : null,
                badge: index == 0 ? 'Cover' : null,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: enabled && images.length < ListingMedia.maxImages
                  ? _pickImages
                  : null,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add photos'),
            ),
            if (video == null)
              OutlinedButton.icon(
                onPressed: enabled ? _pickVideo : null,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Add video'),
              ),
          ],
        ),
        if (video != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.movie_outlined, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '1 video attached',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1C1E21),
                    ),
                  ),
                ),
                if (enabled)
                  IconButton(
                    tooltip: 'Remove video',
                    onPressed: () => onVideoChanged(null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyPreview() {
    return Container(
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_outlined, size: 22, color: Color(0xFF9CA3AF)),
          SizedBox(width: 8),
          Text(
            'No images',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb({
    required String dataUri,
    required VoidCallback? onRemove,
    String? badge,
  }) {
    final bytes = ListingMedia.decodeDataUri(dataUri);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 88,
            height: 88,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        if (badge != null)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
