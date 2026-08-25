// Package promptflow is SHOW's data-driven Guided Prompt Engine.
//
// A Flow is a branching questionnaire (a graph of nodes). The client walks it
// one question at a time — following each answer's Next (or the node's default
// Next), skipping nodes whose Condition doesn't hold — then sends the collected
// answers to Compile, which assembles a precise, English image prompt in a
// fixed layer order (subject → attributes → setting → light → camera → style →
// technical).
//
// The flow is DATA: DefaultFlow() is the seed, served by the API and (later)
// editable from the Admin app without an app release. UI labels are bilingual;
// the *compiled prompt* stays English because the image models expect English.
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
	TypeMulti  NodeType = "multi"  // pick many options
	TypeText   NodeType = "text"   // free text
	TypeImage  NodeType = "image"  // reference photo upload (answer = upload id)
	TypeSlider NodeType = "slider" // 0..1 value
)

// Option is a choice on a single/multi node.
type Option struct {
	ID       string `json:"id"`
	Label    L10n   `json:"label"`
	Value    string `json:"value"`              // token used in the prompt
	Next     string `json:"next,omitempty"`     // node to go to if chosen
	Fragment string `json:"fragment,omitempty"` // overrides node.Fragment
}

// Node is one question in the flow.
type Node struct {
	ID       string   `json:"id"`
	Question L10n     `json:"question"`
	Help     L10n     `json:"help,omitempty"`
	Type     NodeType `json:"type"`
	Options  []Option `json:"options,omitempty"`
	// Condition gates whether this node is shown/compiled. Grammar (minimal):
	// clauses joined by " AND ", each "key=value" or "key!=value".
	Condition string `json:"condition,omitempty"`
	Next      string `json:"next,omitempty"` // default next when no option.Next
	// Fragment renders a text/slider/image answer into prompt text; "{value}"
	// is replaced by the answer. Empty => the answer isn't added directly.
	Fragment string `json:"fragment,omitempty"`
	// Order controls compile layering (lower = earlier in the prompt).
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
	byID := make(map[string]Node, len(f.Nodes))
	for _, n := range f.Nodes {
		byID[n.ID] = n
	}
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
		parts = append(parts, render(n, val))
	}
	return strings.Join(nonEmpty(parts), ", ")
}

// render turns one answered node into its prompt fragment. A node with no
// applicable fragment (e.g. a navigation-only yes/no gate) contributes nothing,
// so its raw answer never leaks into the prompt.
func render(n Node, val string) string {
	// Option-level fragment/value wins for choice nodes.
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

// condHolds evaluates a minimal "k=v AND k!=v" condition against answers.
func condHolds(cond string, answers map[string]string) bool {
	cond = strings.TrimSpace(cond)
	if cond == "" {
		return true
	}
	for _, clause := range strings.Split(cond, " AND ") {
		clause = strings.TrimSpace(clause)
		if i := strings.Index(clause, "!="); i >= 0 {
			k, v := strings.TrimSpace(clause[:i]), strings.TrimSpace(clause[i+2:])
			if answers[k] == v {
				return false
			}
			continue
		}
		if i := strings.Index(clause, "="); i >= 0 {
			k, v := strings.TrimSpace(clause[:i]), strings.TrimSpace(clause[i+1:])
			if answers[k] != v {
				return false
			}
		}
	}
	return true
}

func nonEmpty(in []string) []string {
	out := in[:0]
	for _, s := range in {
		if strings.TrimSpace(s) != "" {
			out = append(out, s)
		}
	}
	return out
}
