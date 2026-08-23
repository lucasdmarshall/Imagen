package services

import (
	"crypto/rand"
	"encoding/hex"
)

// newID returns a random 16-byte hex id (used for entity ids).
func newID() string { return randHex(16) }

// newToken returns a random 32-byte hex opaque session token.
func newToken() string { return randHex(32) }

func randHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
