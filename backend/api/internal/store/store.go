// Package store defines the persistence interface for SHOW and an in-memory
// implementation used for development (dev has no Postgres server). A Postgres
// implementation can satisfy the same Store interface later; see migrations/.
package store

import (
	"errors"

	"github.com/show/api/internal/domain"
)

var (
	ErrNotFound  = errors.New("not found")
	ErrEmailTaken = errors.New("email already registered")
)

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

	// Sessions (opaque bearer tokens)
	CreateSession(token, userID string) error
	SessionUser(token string) (string, error)
	DeleteSession(token string) error

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
}
