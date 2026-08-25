// Package promptflow is SHOW's data-driven Guided Prompt Engine.
//
// A Flow is a branching questionnaire (an ordered list of nodes). Navigation is
// CONDITION-DRIVEN, not pointer-driven: the client shows nodes in Order,
// skipping any whose Condition doesn't hold given the answers so far, and any
// Advanced node when the user is in Quick mode. This makes multi-element
// COMPOSITION natural — the user picks which elements are in the image (person,
// object, scene) and each element's questions appear only if selected.
//
// Compile then assembles the answers into a precise English prompt in Order.
// UI labels are bilingual (Burmese default); prompt fragments are English
// because the image models expect English.
package promptflow

import (
	"sort"
	"strings"
)

// L10n is a bilingual label. Burmese is the app default; English is optional.
type L10n struct {
	My string `json:"my"`
	En string `json:"en"`
}

// NodeType is how a question is answered on the client.
type NodeType string

const (
	TypeSingle NodeType = "single" // pick one option
	TypeMulti  NodeType = "multi"  // pick many options (comma-joined answer)
	TypeText   NodeType = "text"   // free text
	TypeImage  NodeType = "image"  // reference photo upload (answer = upload id)
	TypeSlider NodeType = "slider" // 0..1 value
)

// Option is a choice on a single/multi node.
type Option struct {
	ID       string `json:"id"`
	Label    L10n   `json:"label"`
	Value    string `json:"value"`              // token used in the prompt
	Fragment string `json:"fragment,omitempty"` // overrides node.Fragment
}

// Node is one question in the flow.
type Node struct {
	ID       string   `json:"id"`
	Question L10n     `json:"question"`
	Help     L10n     `json:"help,omitempty"`
	Type     NodeType `json:"type"`
	Options  []Option `json:"options,omitempty"`
	// Condition gates whether this node is shown/compiled. Grammar: clauses
	// joined by " AND ", each one of:
	//   key=value  key!=value  key~=value (contains)  key!~=value (not contains)
	// "contains" tests membership in a comma-joined multi-select answer.
	Condition string `json:"condition,omitempty"`
	// Fragment renders a text/slider/image answer (or a choice with no option
	// fragment) into prompt text; "{value}" is replaced by the answer. Empty =>
	// the node is navigation-only and adds nothing to the prompt.
	Fragment string `json:"fragment,omitempty"`
	// Advanced nodes appear only in Detailed mode (hidden in Quick mode).
	Advanced bool `json:"advanced,omitempty"`
	// Order controls both wizard sequence and compile layering (lower first).
	Order int `json:"order"`
}

// Flow is the whole questionnaire.
type Flow struct {
	Version int    `json:"version"`
	Start   string `json:"start"`
	Nodes   []Node `json:"nodes"`
}

// Compile assembles answers into one English prompt. answers maps nodeID to the
// chosen option value(s) or raw text. Nodes are emitted in Order; a node
// contributes only when answered and its Condition holds.
func (f Flow) Compile(answers map[string]string) string {
	nodes := append([]Node(nil), f.Nodes...)
	sort.SliceStable(nodes, func(i, j int) bool { return nodes[i].Order < nodes[j].Order })

	var parts []string
	for _, n := range nodes {
		val, ok := answers[n.ID]
		if !ok || strings.TrimSpace(val) == "" {
			continue
		}
		if !condHolds(n.Condition, answers) {
			continue
		}
		if frag := render(n, val); strings.TrimSpace(frag) != "" {
			parts = append(parts, frag)
		}
	}
	return strings.Join(parts, ", ")
}

// render turns one answered node into its prompt fragment. A node with no
// applicable fragment (e.g. a navigation-only gate) contributes nothing, so its
// raw answer never leaks into the prompt.
func render(n Node, val string) string {
	if n.Type == TypeSingle || n.Type == TypeMulti {
		for _, o := range n.Options {
			if o.Value == val || o.ID == val {
				switch {
				case o.Fragment != "":
					return sub(o.Fragment, o.Value)
				case n.Fragment != "":
					return sub(n.Fragment, o.Value)
				default:
					return "" // navigational node — no prompt output
				}
			}
		}
		// Custom "Other" free-text answer on a choice node.
		if n.Fragment != "" {
			return sub(n.Fragment, val)
		}
		return ""
	}
	if n.Fragment != "" {
		return sub(n.Fragment, val)
	}
	return ""
}

func sub(tmpl, val string) string { return strings.ReplaceAll(tmpl, "{value}", val) }

// condHolds evaluates a minimal condition against answers. Supported per-clause
// operators: =, !=, ~= (contains), !~= (not contains), joined by " AND ".
func condHolds(cond string, answers map[string]string) bool {
	cond = strings.TrimSpace(cond)
	if cond == "" {
		return true
	}
	for _, clause := range strings.Split(cond, " AND ") {
		clause = strings.TrimSpace(clause)
		switch {
		case strings.Contains(clause, "!~="):
			k, v := split2(clause, "!~=")
			if contains(answers[k], v) {
				return false
			}
		case strings.Contains(clause, "~="):
			k, v := split2(clause, "~=")
			if !contains(answers[k], v) {
				return false
			}
		case strings.Contains(clause, "!="):
			k, v := split2(clause, "!=")
			if answers[k] == v {
				return false
			}
		case strings.Contains(clause, "="):
			k, v := split2(clause, "=")
			if answers[k] != v {
				return false
			}
		}
	}
	return true
}

func split2(clause, op string) (string, string) {
	i := strings.Index(clause, op)
	return strings.TrimSpace(clause[:i]), strings.TrimSpace(clause[i+len(op):])
}

// contains reports whether v is one of the comma-joined values in csv.
func contains(csv, v string) bool {
	for _, item := range strings.Split(csv, ",") {
		if strings.TrimSpace(item) == v {
			return true
		}
	}
	return false
}
