// ─────────────────────────────────────────────────────────────────────────────
// File   : lib/screens/employee/widgets/face_enroll_dialog.dart
// Purpose: A professional, theme-aware face enrollment dialog for WEB,
//          that uses the LAPTOP's CAMERA and allows saving the photo.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../services/face_service.dart';

class FaceEnrollDialog extends StatefulWidget {
  final Map<String, dynamic> employee;
  const FaceEnrollDialog({super.key, required this.employee});

  @override
  State<FaceEnrollDialog> createState() => _FaceEnrollDialogState();
}

class _FaceEnrollDialogState extends State<FaceEnrollDialog> {
  PlatformFile? _pickedImageFile;
  bool _isFaceUploading = false;
  final ImagePicker _picker = ImagePicker();

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? theme.colorScheme.error : Colors.green,
    ));
  }

  Future<void> _showImageSourceDialog() async {
    if (_isFaceUploading) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.upload),
              title: const Text("Upload from file"),
              onTap: () {
                Navigator.of(context).pop();
                _pickImageFromFile();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text("Use laptop camera"), // Clarified text for user
              onTap: () {
                Navigator.of(context).pop();
                _takeAndSavePhotoFromWebcam();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null) {
        setState(() => _pickedImageFile = result.files.first);
      }
    } catch (e) {
      _showSnackBar("Could not open file picker: $e", isError: true);
    }
  }

  // This function uses the laptop's webcam via the browser.
  Future<void> _takeAndSavePhotoFromWebcam() async {
    print("DEBUG: 'Use laptop camera' was clicked. Attempting to open camera NOW...");
    try {
      // This command activates the laptop's camera in the browser.
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return; // User cancelled the camera.

      final bytes = await photo.readAsBytes();
      final size = await photo.length();

      // Create a descriptive filename for the download.
      final String employeeId = widget.employee['employeeId']?.toString() ?? 'employee';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = '${employeeId}_face_$timestamp.jpg';

      // Trigger the browser's "Save As..." dialog.
      _triggerDownload(bytes, fileName);
      _showSnackBar("Your browser is downloading the photo as '$fileName'.");

      // Update the UI to show the new photo.
      setState(() {
        _pickedImageFile = PlatformFile(
          name: fileName,
          bytes: bytes,
          size: size,
          path: photo.path,
        );
      });
    } catch (e) {
      _showSnackBar("Could not access camera or save photo: $e", isError: true);
    }
  }

  // This function uses dart:html to trigger a browser download.
  void _triggerDownload(List<int> bytes, String fileName) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _enrollFace() async {
    if (_isFaceUploading || _pickedImageFile == null) return;
    setState(() => _isFaceUploading = true);
    try {
      await FaceService.enrollFace(widget.employee['_id'], _pickedImageFile!);
      if (mounted) {
        _showSnackBar("Face for ${widget.employee['fullName']} enrolled successfully!");
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) _showSnackBar(e.toString().replaceFirst("Exception: ", ""), isError: true);
    } finally {
      if (mounted) setState(() => _isFaceUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The build method remains exactly the same.
    final theme = Theme.of(context);
    return AlertDialog(
      // ... (rest of the build method is unchanged)
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Enroll Face: ${widget.employee['fullName'] ?? 'Employee'}", style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            "Use a clear, frontal photo without obstructions.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            InkWell(
              onTap: _isFaceUploading ? null : _showImageSourceDialog,
              borderRadius: BorderRadius.circular(100),
              child: DottedBorder(
                borderType: BorderType.RRect,
                radius: const Radius.circular(100),
                color: theme.dividerColor,
                strokeWidth: 2,
                dashPattern: const [8, 6],
                child: Container(
                  height: 180, width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: _pickedImageFile?.bytes != null
                        ? DecorationImage(image: MemoryImage(_pickedImageFile!.bytes!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _pickedImageFile == null
                      ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.imagePlus, size: 48, color: theme.textTheme.bodySmall?.color),
                          const SizedBox(height: 8),
                          Text("Click to select image", style: theme.textTheme.bodySmall)
                        ],
                      ))
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pickedImageFile == null
                  ? Text("No image selected", style: theme.textTheme.bodySmall)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.fileImage, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _pickedImageFile!.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _isFaceUploading ? null : _showImageSourceDialog,
                    child: const Text("Change"),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isFaceUploading ? null : () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          icon: _isFaceUploading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.scanFace, size: 16),
          label: const Text("Enroll Face"),
          onPressed: (_isFaceUploading || _pickedImageFile == null) ? null : _enrollFace,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ).copyWith(
            backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (states.contains(MaterialState.disabled)) {
                return Colors.grey.withOpacity(0.5);
              }
              return Colors.green;
            }),
          ),
        ),
      ],
    );
  }
}