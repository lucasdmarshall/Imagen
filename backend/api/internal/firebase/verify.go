// Package firebase verifies Firebase Authentication ID tokens (RS256 JWTs)
// using only the standard library — no Firebase Admin SDK, no extra deps.
//
// It fetches Google's public signing certificates, verifies the token
// signature, and validates the issuer/audience/expiry against the Firebase
// project id (env FIREBASE_PROJECT_ID, defaulting to the SHOW project).
package firebase

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

const certURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

const defaultProjectID = "myanmar-health-9d171"

func projectID() string {
	if v := os.Getenv("FIREBASE_PROJECT_ID"); v != "" {
		return v
	}
	return defaultProjectID
}

// Claims holds the verified fields we use from a Firebase ID token.
type Claims struct {
	Sub           string
	Email         string
	Name          string
	EmailVerified bool
}

var (
	mu       sync.Mutex
	certs    map[string]*rsa.PublicKey
	certsExp time.Time
)

// getCerts returns Google's securetoken public keys, cached for an hour.
func getCerts() (map[string]*rsa.PublicKey, error) {
	mu.Lock()
	defer mu.Unlock()
	if certs != nil && time.Now().Before(certsExp) {
		return certs, nil
	}
	resp, err := http.Get(certURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("firebase certs: status %d", resp.StatusCode)
	}
	var raw map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return nil, err
	}
	m := make(map[string]*rsa.PublicKey, len(raw))
	for kid, pemStr := range raw {
		block, _ := pem.Decode([]byte(pemStr))
		if block == nil {
			continue
		}
		cert, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			continue
		}
		if pk, ok := cert.PublicKey.(*rsa.PublicKey); ok {
			m[kid] = pk
		}
	}
	if len(m) == 0 {
		return nil, errors.New("firebase: no usable certs")
	}
	certs, certsExp = m, time.Now().Add(time.Hour)
	return m, nil
}

func b64(s string) ([]byte, error) { return base64.RawURLEncoding.DecodeString(s) }

// VerifyIDToken validates a Firebase ID token and returns its claims. It errors
// if the signature, issuer, audience, or expiry are invalid.
func VerifyIDToken(token string) (*Claims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, errors.New("malformed token")
	}

	headerJSON, err := b64(parts[0])
	if err != nil {
		return nil, err
	}
	var hdr struct {
		Alg string `json:"alg"`
		Kid string `json:"kid"`
	}
	if err := json.Unmarshal(headerJSON, &hdr); err != nil {
		return nil, err
	}
	if hdr.Alg != "RS256" {
		return nil, fmt.Errorf("unexpected alg %q", hdr.Alg)
	}

	certMap, err := getCerts()
	if err != nil {
		return nil, err
	}
	pub, ok := certMap[hdr.Kid]
	if !ok {
		return nil, errors.New("unknown signing key")
	}

	sig, err := b64(parts[2])
	if err != nil {
		return nil, err
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(pub, crypto.SHA256, digest[:], sig); err != nil {
		return nil, errors.New("invalid signature")
	}

	payloadJSON, err := b64(parts[1])
	if err != nil {
		return nil, err
	}
	var c struct {
		Iss           string `json:"iss"`
		Aud           string `json:"aud"`
		Exp           int64  `json:"exp"`
		Sub           string `json:"sub"`
		Email         string `json:"email"`
		Name          string `json:"name"`
		EmailVerified bool   `json:"email_verified"`
	}
	if err := json.Unmarshal(payloadJSON, &c); err != nil {
		return nil, err
	}

	pid := projectID()
	if c.Iss != "https://securetoken.google.com/"+pid {
		return nil, errors.New("invalid issuer")
	}
	if c.Aud != pid {
		return nil, errors.New("invalid audience")
	}
	if c.Exp <= time.Now().Unix() {
		return nil, errors.New("token expired")
	}
	if c.Sub == "" {
		return nil, errors.New("token missing subject")
	}

	return &Claims{
		Sub:           c.Sub,
		Email:         strings.ToLower(strings.TrimSpace(c.Email)),
		Name:          strings.TrimSpace(c.Name),
		EmailVerified: c.EmailVerified,
	}, nil
}
