import 'package:flutter/foundation.dart';

import '../models/flow.dart';

/// Drives the guided wizard: which question is current, the collected answers,
/// and forward/back navigation. Navigation is condition-driven — the next
/// visible node depends on the answers so far and the Quick/Detailed mode.
class WizardController extends ChangeNotifier {
  WizardController(this.flow, {required this.detailed}) {
    _idx = _firstVisible();
  }

  final PromptFlow flow;
  final bool detailed;
  final Map<String, String> answers = {};

  int _idx = 0;
  bool finished = false;

  bool _vis(int i) => flow.isVisible(flow.nodes[i], answers, detailed: detailed);

  int _firstVisible() {
    for (var i = 0; i < flow.nodes.length; i++) {
      if (_vis(i)) return i;
    }
    return flow.nodes.length;
  }

  FlowNode? get current =>
      finished || _idx >= flow.nodes.length ? null : flow.nodes[_idx];

  String? answer(String id) => answers[id];

  void setAnswer(String id, String? value) {
    if (value == null || value.isEmpty) {
      answers.remove(id);
    } else {
      answers[id] = value;
    }
    notifyListeners();
  }

  bool get canBack => finished ? _lastVisible() != -1 : _prev(_idx) != -1;

  void next() {
    final n = _next(_idx);
    if (n == -1) {
      finished = true;
    } else {
      _idx = n;
    }
    notifyListeners();
  }

  void back() {
    if (finished) {
      finished = false;
      final l = _lastVisible();
      if (l != -1) _idx = l;
      notifyListeners();
      return;
    }
    final p = _prev(_idx);
    if (p != -1) {
      _idx = p;
      notifyListeners();
    }
  }

  /// Jump to a specific node (used by "Edit" on the review screen).
  void editNode(String id) {
    final i = flow.nodes.indexWhere((n) => n.id == id);
    if (i != -1) {
      _idx = i;
      finished = false;
      notifyListeners();
    }
  }

  int _next(int from) {
    for (var i = from + 1; i < flow.nodes.length; i++) {
      if (_vis(i)) return i;
    }
    return -1;
  }

  int _prev(int from) {
    for (var i = from - 1; i >= 0; i--) {
      if (_vis(i)) return i;
    }
    return -1;
  }

  int _lastVisible() {
    var last = -1;
    for (var i = 0; i < flow.nodes.length; i++) {
      if (_vis(i)) last = i;
    }
    return last;
  }

  int get totalVisible {
    var c = 0;
    for (var i = 0; i < flow.nodes.length; i++) {
      if (_vis(i)) c++;
    }
    return c;
  }

  int get position {
    var c = 0;
    for (var i = 0; i <= _idx && i < flow.nodes.length; i++) {
      if (_vis(i)) c++;
    }
    return c;
  }

  double get progress => totalVisible == 0 ? 0 : position / totalVisible;

  /// Answered, currently-visible nodes — for the review summary.
  List<FlowNode> get answeredVisible => [
        for (var i = 0; i < flow.nodes.length; i++)
          if (_vis(i) && answers.containsKey(flow.nodes[i].id)) flow.nodes[i]
      ];
}
