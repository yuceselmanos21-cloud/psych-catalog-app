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

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
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
    });

    try {
      final response = await AnalysisService.generateAnalysis(input);
      setState(() {
        _result = response;
      });
    } catch (e) {
      setState(() {
        _error = 'Analiz sırasında hata oluştu: $e';
        _result = null;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _loading ? null : _runAnalysis,
                child: _loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Analiz Et'),
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
