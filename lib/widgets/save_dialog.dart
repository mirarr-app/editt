import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

enum SaveOption { newFile, overwrite, cancel }

class SaveDialog extends StatefulWidget {
  final String originalFilePath;
  final String? suggestedExtension;

  const SaveDialog({
    super.key,
    required this.originalFilePath,
    this.suggestedExtension,
  });

  @override
  State<SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<SaveDialog> {
  late String newFileName;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final basename = path.basenameWithoutExtension(widget.originalFilePath);
    final ext = widget.suggestedExtension ?? path.extension(widget.originalFilePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    newFileName = '${basename}_edited_$timestamp$ext';
    _controller = TextEditingController(text: newFileName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = path.dirname(widget.originalFilePath);
    final originalName = path.basename(widget.originalFilePath);

    return AlertDialog(
      title: const Text('Save Image'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose how to save your edited image:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                title: const Text('Save as new file'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('New filename:', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          newFileName = value;
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Location: $dir',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    if (newFileName.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filename cannot be empty')),
                      );
                      return;
                    }
                    Navigator.of(context).pop({
                      'option': SaveOption.newFile,
                      'filename': newFileName.trim(),
                    });
                  },
                  child: const Text('Save as New'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Overwrite original'),
                subtitle: Text(
                  'Replace: $originalName',
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop({
                      'option': SaveOption.overwrite,
                      'filename': null,
                    });
                  },
                  child: const Text('Overwrite'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'option': SaveOption.cancel,
              'filename': null,
            });
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Show the save dialog and return the result
Future<Map<String, dynamic>?> showSaveDialog({
  required BuildContext context,
  required String originalFilePath,
  String? suggestedExtension,
}) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SaveDialog(
      originalFilePath: originalFilePath,
      suggestedExtension: suggestedExtension,
    ),
  );
}

