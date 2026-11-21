// Flutter 3.50 currently reports Material as deprecated; retain stable widgets.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import 'sodfa_update_service.dart';

Future<void> showSodfaUpdateDialog(
  BuildContext context,
  SodfaRelease release,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !release.forceUpdate,
    builder: (_) => SodfaUpdateDialog(release: release),
  );
}

class SodfaUpdateDialog extends StatefulWidget {
  const SodfaUpdateDialog({super.key, required this.release});
  final SodfaRelease release;

  @override
  State<SodfaUpdateDialog> createState() => _SodfaUpdateDialogState();
}

class _SodfaUpdateDialogState extends State<SodfaUpdateDialog> {
  double progress = 0;
  bool downloading = false;
  String? apkPath;
  String? error;

  Future<void> download() async {
    setState(() {
      downloading = true;
      error = null;
    });
    try {
      final path = await SodfaUpdateService.downloadAndVerify(
        widget.release,
        onProgress: (value) {
          if (mounted) {
            setState(() => progress = value);
          }
        },
      );
      if (mounted) {
        setState(() {
          apkPath = path;
          downloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          downloading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> install() async {
    try {
      await SodfaUpdateService.openInstaller(apkPath!);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.release.forceUpdate,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update_alt_rounded, color: Color(0xFF9185FF)),
              SizedBox(width: 9),
              Expanded(child: Text('تحديث جديد لصدفة')),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الإصدار ${widget.release.version} متوفر الآن'),
                if (widget.release.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('شنو الجديد؟',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(widget.release.releaseNotes),
                ],
                if (downloading) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(value: progress == 0 ? null : progress),
                  const SizedBox(height: 7),
                  Text(progress == 0
                      ? 'جارٍ تنزيل التحديث...'
                      : 'اكتمل ${(progress * 100).round()}٪'),
                ],
                if (apkPath != null) ...[
                  const SizedBox(height: 14),
                  const Text('تم تنزيل الملف والتحقق من سلامته. اضغط تثبيت للمتابعة.'),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
          actions: [
            if (!widget.release.forceUpdate)
              TextButton(
                onPressed: downloading ? null : () => Navigator.pop(context),
                child: const Text('لاحقاً'),
              ),
            FilledButton(
              onPressed: downloading ? null : (apkPath == null ? download : install),
              child: Text(downloading
                  ? 'جارٍ التنزيل'
                  : apkPath == null
                      ? 'تنزيل التحديث'
                      : 'تثبيت التحديث'),
            ),
          ],
          ),
        ),
      );
}
