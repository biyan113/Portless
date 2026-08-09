/// DeepSeek 结构化解读结果 —— 字段与 Rust `ProcessInsight` 一一对应。
class ProcessInsight {
  final String headline;
  final String serviceName;
  final String category;
  final String stack;
  final String purpose;
  final bool isDevService;
  final String stopAdvice;
  final String stopImpact;
  final double confidence;
  final List<String> actions;
  final List<String> risks;
  final String notes;

  const ProcessInsight({
    required this.headline,
    required this.serviceName,
    required this.category,
    required this.stack,
    required this.purpose,
    required this.isDevService,
    required this.stopAdvice,
    required this.stopImpact,
    required this.confidence,
    required this.actions,
    required this.risks,
    required this.notes,
  });

  factory ProcessInsight.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic v) => (v as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return ProcessInsight(
      headline: json['headline'] as String? ?? '未知服务',
      serviceName: json['serviceName'] as String? ?? 'Unknown',
      category: json['category'] as String? ?? 'unknown',
      stack: json['stack'] as String? ?? '未知',
      purpose: json['purpose'] as String? ?? '信息不足，无法判断用途',
      isDevService: json['isDevService'] as bool? ?? false,
      stopAdvice: json['stopAdvice'] as String? ?? 'caution',
      stopImpact: json['stopImpact'] as String? ?? '停止影响未知',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      actions: strList(json['actions']),
      risks: strList(json['risks']),
      notes: json['notes'] as String? ?? '',
    );
  }

  bool get isUnknown =>
      headline == '未知服务' &&
      serviceName == 'Unknown' &&
      purpose.contains('信息不足');
}

/// agent `explain` 命令的返回。
class ExplainResult {
  final bool ok;
  final String model;
  final String summary;
  final String raw;
  final ProcessInsight? data;
  final String? message;

  const ExplainResult({
    required this.ok,
    required this.model,
    required this.summary,
    required this.raw,
    required this.data,
    required this.message,
  });

  factory ExplainResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return ExplainResult(
      ok: json['ok'] as bool? ?? false,
      model: json['model'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      raw: json['raw'] as String? ?? '',
      data: rawData is Map<String, dynamic> ? ProcessInsight.fromJson(rawData) : null,
      message: json['message'] as String?,
    );
  }
}
