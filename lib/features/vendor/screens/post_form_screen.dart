import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class PostFormScreen extends ConsumerStatefulWidget {
  final String? postId;

  const PostFormScreen({super.key, this.postId});

  @override
  ConsumerState<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends ConsumerState<PostFormScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  final List<String> _mediaUrls = [];
  final List<File> _pendingFiles = [];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isInitialized = false;

  bool get _isEditing => widget.postId != null;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.sand, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Photo',
                style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppTheme.terracotta.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.terracotta),
                ),
                title: Text('Take Photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text('Use your camera', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickSingle(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppTheme.baobab.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.baobab),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text('Pick from your photos', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickMultiple();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSingle(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _pendingFiles.add(File(image.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _pickMultiple() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() => _pendingFiles.addAll(images.map((x) => File(x.path))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access gallery: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<List<String>> _uploadPendingImages() async {
    if (_pendingFiles.isEmpty) return [];
    final service = ref.read(supabaseServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return [];

    final uploaded = <String>[];
    for (final file in _pendingFiles) {
      final url = await service.uploadShopImage(userId, file, folder: 'posts');
      uploaded.add(url);
    }
    return uploaded;
  }

  Future<void> _save() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Caption is required', style: GoogleFonts.poppins()), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_pendingFiles.isNotEmpty) {
        setState(() => _isUploading = true);
        final newUrls = await _uploadPendingImages();
        _mediaUrls.addAll(newUrls);
        _pendingFiles.clear();
        setState(() => _isUploading = false);
      }

      final service = ref.read(supabaseServiceProvider);
      final shop = await ref.read(vendorShopProvider.future);
      if (shop == null) throw Exception('No shop found');

      if (_isEditing) {
        await service.updateShopPost(widget.postId!, {
          'caption': _captionController.text.trim(),
          'media_urls': _mediaUrls,
        });
      } else {
        await service.createShopPost(
          shop.id,
          caption: _captionController.text.trim(),
          mediaUrls: _mediaUrls,
        );
      }

      ref.invalidate(vendorPostsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && !_isInitialized) {
      final postsAsync = ref.watch(vendorPostsProvider);
      postsAsync.whenData((posts) {
        final post = posts.where((p) => p.id == widget.postId).firstOrNull;
        if (post != null && !_isInitialized) {
          _isInitialized = true;
          _captionController.text = post.caption;
          _mediaUrls.addAll(post.mediaUrls);
          setState(() {});
        }
      });
    }

    final totalImages = _mediaUrls.length + _pendingFiles.length;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Post' : 'New Post',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Photos section ──────────────────────────────────
          Text('Photos', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(
            '$totalImages/10 photos added',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._mediaUrls.asMap().entries.map((entry) => _ImageTile(
                      key: ValueKey('url-${entry.key}'),
                      onRemove: () => setState(() => _mediaUrls.removeAt(entry.key)),
                      child: CachedNetworkImage(
                        imageUrl: entry.value,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.textHint),
                      ),
                    )),
                ..._pendingFiles.asMap().entries.map((entry) => _ImageTile(
                      key: ValueKey('file-${entry.key}'),
                      onRemove: () => setState(() => _pendingFiles.removeAt(entry.key)),
                      isPending: true,
                      child: Image.file(entry.value, fit: BoxFit.cover),
                    )),
                if (totalImages < 10)
                  GestureDetector(
                    onTap: _showImageSourcePicker,
                    child: Container(
                      width: 110,
                      height: 110,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.sand, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: AppTheme.baobab.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.baobab, size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text('Add Photo', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.baobab)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.baobab)),
                  const SizedBox(width: 8),
                  Text('Uploading photos...', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.baobab)),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // ── Caption ─────────────────────────────────────────
          Text('Caption', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _captionController,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Share an update with your followers...'),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 12),
                        Text(
                          _isUploading ? 'Uploading...' : 'Publishing...',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Text(
                      _isEditing ? 'Update Post' : 'Publish Post',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final bool isPending;

  const _ImageTile({
    super.key,
    required this.child,
    required this.onRemove,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.expand(child: child),
          ),
          if (isPending)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text('New', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
