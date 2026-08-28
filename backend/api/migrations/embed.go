// Package migrations embeds the SQL schema files so they ship inside the
// binary and can be applied at startup (they are all idempotent).
package migrations

import "embed"

// FS holds every *.sql migration, applied in lexical filename order.
//
//go:embed *.sql
var FS embed.FS
