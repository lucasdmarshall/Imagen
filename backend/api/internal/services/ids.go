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

// tempPassword is a one-time password an admin can give a user who forgot theirs.
func tempPassword() string {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
	b := make([]byte, 10)
	_, _ = rand.Read(b)
	out := make([]byte, 10)
	for i := range out {
		out[i] = alphabet[int(b[i])%len(alphabet)]
	}
	return string(out)
}
