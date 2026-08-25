// Package store defines the persistence interface for SHOW and an in-memory
// implementation used for development (dev has no Postgres server). A Postgres
// implementation can satisfy the same Store interface later; see migrations/.
package store

import (
	"errors"
	"time"

	"github.com/show/api/internal/domain"
)

var (
	ErrNotFound  = errors.New("not found")
	ErrEmailTaken = errors.New("email already registered")
)

// IdempotentResult is a cached response for a mutating request.
type IdempotentResult struct {
	Status    int
	Body      []byte
	CreatedAt time.Time
}

// Upload is a stored reference photo (dev: in-memory; prod: object storage).
type Upload struct {
	ID          string
	UserID      string
	ContentType string
	Data        []byte
	CreatedAt   time.Time
}

// Store is the persistence boundary. Every service depends on this interface,
// never on a concrete DB, so the backend runs in-memory today and on Postgres
// later without touching business logic.
type Store interface {
	// Users
	CreateUser(u *domain.User) error
	GetUserByID(id string) (*domain.User, error)
	GetUserByEmail(email string) (*domain.User, error)
	UpdateUser(u *domain.User) error
	ListUsers() ([]*domain.User, error)

	// Sessions (opaque bearer tokens). Expired sessions resolve as ErrNotFound.
	CreateSession(token, userID string, expiresAt time.Time) error
	SessionUser(token string) (string, error)
	DeleteSession(token string) error

	// Idempotency: store/replay responses for mutating requests keyed by a
	// caller-supplied Idempotency-Key (scoped per user/IP + method + path).
	// SaveIdempotent returns (existing, true) if the key was already stored.
	GetIdempotent(key string) (*IdempotentResult, bool)
	SaveIdempotent(key string, r IdempotentResult) (IdempotentResult, bool)

	// Subscriptions
	GetSubscription(userID string) (*domain.Subscription, error)
	SetSubscription(sub *domain.Subscription) error

	// Credits — AddCredits atomically appends a ledger entry and returns it
	// with the running balance. amount is signed.
	Balance(userID string) (int, error)
	AddCredits(tx *domain.CreditTransaction) (*domain.CreditTransaction, error)
	ListCredits(userID string) ([]*domain.CreditTransaction, error)

	// Notifications
	CreateNotification(n *domain.Notification) error
	ListNotifications(userID string) ([]*domain.Notification, error)
	MarkNotificationRead(userID, id string) error

	// Uploads (reference photos)
	SaveUpload(u *Upload) error
	GetUpload(id string) (*Upload, error)
}
