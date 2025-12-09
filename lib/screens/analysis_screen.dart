import 'package:flutter/material.dart';
import 'analysis_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _textCtrl = TextEditingController();

  bool _loading = false;
  String? _result;
  String? _error;

  // ✅ Cooldown
  static const Duration _cooldown = Duration(seconds: 8);
  DateTime? _lastRunAt;

  bool get _inCooldown {
    if (_lastRunAt == null) return false;
    return DateTime.now().difference(_lastRunAt!) < _cooldown;
  }

  int get _cooldownRemaining {
    if (_lastRunAt == null) return 0;
    final diff = DateTime.now().difference(_lastRunAt!);
    final remain = _cooldown.inSeconds - diff.inSeconds;
    return remain.clamp(0, _cooldown.inSeconds);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    if (_loading || _inCooldown) return;

    final input = _textCtrl.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = 'Lütfen analiz için bir metin girin.';
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _lastRunAt = DateTime.now();
    });

    try {
      final response = await AnalysisService.generateAnalysis(input);
      if (!mounted) return;

      setState(() {
        _result = response;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Analiz sırasında hata oluştu: $e';
        _result = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _loading
        ? 'Analiz ediliyor...'
        : _inCooldown
        ? 'Lütfen bekle ($_cooldownRemaining sn)'
        : 'Analiz Et';

    return Scaffold(
      appBar: AppBar(title: const Text('AI Analizi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Analiz edilecek metin',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || _inCooldown) ? null : _runAnalysis,
                child: _loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(buttonText),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_result != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_result!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
