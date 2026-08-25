// Client-side model of the Guided Prompt Engine flow served by the API.
// Navigation mirrors the backend: nodes are ordered, shown when their
// condition holds and (in Quick mode) when they are not advanced.

class L10n {
  const L10n(this.my, this.en);
  final String my;
  final String en;
  factory L10n.fromJson(Map<String, dynamic>? j) =>
      L10n((j?['my'] as String?) ?? '', (j?['en'] as String?) ?? '');

  /// Burmese default; English optional.
  String t(String locale) => locale == 'en' ? (en.isEmpty ? my : en) : (my.isEmpty ? en : my);
}

class FlowOption {
  FlowOption(this.id, this.label, this.value);
  final String id;
  final L10n label;
  final String value;
  factory FlowOption.fromJson(Map<String, dynamic> j) => FlowOption(
        j['id'] as String,
        L10n.fromJson(j['label'] as Map<String, dynamic>?),
        (j['value'] as String?) ?? j['id'] as String,
      );
}

enum NodeType { single, multi, text, image, slider }

NodeType _typeOf(String s) => switch (s) {
      'multi' => NodeType.multi,
      'text' => NodeType.text,
      'image' => NodeType.image,
      'slider' => NodeType.slider,
      _ => NodeType.single,
    };

class FlowNode {
  FlowNode({
    required this.id,
    required this.question,
    required this.help,
    required this.type,
    required this.options,
    required this.condition,
    required this.advanced,
    required this.order,
  });

  final String id;
  final L10n question;
  final L10n help;
  final NodeType type;
  final List<FlowOption> options;
  final String condition;
  final bool advanced;
  final int order;

  factory FlowNode.fromJson(Map<String, dynamic> j) => FlowNode(
        id: j['id'] as String,
        question: L10n.fromJson(j['question'] as Map<String, dynamic>?),
        help: L10n.fromJson(j['help'] as Map<String, dynamic>?),
        type: _typeOf((j['type'] as String?) ?? 'single'),
        options: ((j['options'] as List?) ?? const [])
            .map((e) => FlowOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        condition: (j['condition'] as String?) ?? '',
        advanced: (j['advanced'] as bool?) ?? false,
        order: (j['order'] as int?) ?? 0,
      );
}

class PromptFlow {
  PromptFlow(this.version, this.start, this.nodes);
  final int version;
  final String start;
  final List<FlowNode> nodes; // sorted by order

  factory PromptFlow.fromJson(Map<String, dynamic> j) {
    final nodes = ((j['nodes'] as List?) ?? const [])
        .map((e) => FlowNode.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return PromptFlow((j['version'] as int?) ?? 1, (j['start'] as String?) ?? '', nodes);
  }

  /// Whether [node] should be shown, given [answers] and Quick/Detailed [mode].
  bool isVisible(FlowNode node, Map<String, String> answers, {required bool detailed}) {
    if (node.advanced && !detailed) return false;
    return conditionHolds(node.condition, answers);
  }
}

/// Evaluates the flow condition grammar: clauses joined by " AND ", each one of
/// key=value, key!=value, key~=value (contains), key!~=value (not contains).
bool conditionHolds(String cond, Map<String, String> answers) {
  cond = cond.trim();
  if (cond.isEmpty) return true;
  for (final raw in cond.split(' AND ')) {
    final clause = raw.trim();
    if (clause.contains('!~=')) {
      final p = _split(clause, '!~=');
      if (_contains(answers[p.$1], p.$2)) return false;
    } else if (clause.contains('~=')) {
      final p = _split(clause, '~=');
      if (!_contains(answers[p.$1], p.$2)) return false;
    } else if (clause.contains('!=')) {
      final p = _split(clause, '!=');
      if ((answers[p.$1] ?? '') == p.$2) return false;
    } else if (clause.contains('=')) {
      final p = _split(clause, '=');
      if ((answers[p.$1] ?? '') != p.$2) return false;
    }
  }
  return true;
}

(String, String) _split(String clause, String op) {
  final i = clause.indexOf(op);
  return (clause.substring(0, i).trim(), clause.substring(i + op.length).trim());
}

bool _contains(String? csv, String v) {
  if (csv == null) return false;
  return csv.split(',').map((e) => e.trim()).contains(v);
}
