package store

import (
	"sort"
	"sync"
	"time"

	"github.com/show/api/internal/domain"
)

// Memory is a thread-safe, in-memory Store for development and tests.
type Memory struct {
	mu            sync.RWMutex
	users         map[string]*domain.User // by ID
	emailIndex    map[string]string       // email -> ID
	sessions      map[string]string       // token -> userID
	subs          map[string]*domain.Subscription
	credits       map[string][]*domain.CreditTransaction // by userID (ordered)
	notifications map[string][]*domain.Notification      // by userID
}

func NewMemory() *Memory {
	return &Memory{
		users:         map[string]*domain.User{},
		emailIndex:    map[string]string{},
		sessions:      map[string]string{},
		subs:          map[string]*domain.Subscription{},
		credits:       map[string][]*domain.CreditTransaction{},
		notifications: map[string][]*domain.Notification{},
	}
}

// --- Users ---

func (m *Memory) CreateUser(u *domain.User) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.emailIndex[u.Email]; ok {
		return ErrEmailTaken
	}
	cp := *u
	m.users[u.ID] = &cp
	m.emailIndex[u.Email] = u.ID
	return nil
}

func (m *Memory) GetUserByID(id string) (*domain.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	u, ok := m.users[id]
	if !ok {
		return nil, ErrNotFound
	}
	cp := *u
	return &cp, nil
}

func (m *Memory) GetUserByEmail(email string) (*domain.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	id, ok := m.emailIndex[email]
	if !ok {
		return nil, ErrNotFound
	}
	cp := *m.users[id]
	return &cp, nil
}

func (m *Memory) UpdateUser(u *domain.User) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.users[u.ID]; !ok {
		return ErrNotFound
	}
	cp := *u
	m.users[u.ID] = &cp
	return nil
}

func (m *Memory) ListUsers() ([]*domain.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*domain.User, 0, len(m.users))
	for _, u := range m.users {
		cp := *u
		out = append(out, &cp)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.Before(out[j].CreatedAt) })
	return out, nil
}

// --- Sessions ---

func (m *Memory) CreateSession(token, userID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessions[token] = userID
	return nil
}

func (m *Memory) SessionUser(token string) (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	id, ok := m.sessions[token]
	if !ok {
		return "", ErrNotFound
	}
	return id, nil
}

func (m *Memory) DeleteSession(token string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.sessions, token)
	return nil
}

// --- Subscriptions ---

func (m *Memory) GetSubscription(userID string) (*domain.Subscription, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	s, ok := m.subs[userID]
	if !ok {
		return nil, ErrNotFound
	}
	cp := *s
	return &cp, nil
}

func (m *Memory) SetSubscription(sub *domain.Subscription) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	cp := *sub
	m.subs[sub.UserID] = &cp
	return nil
}

// --- Credits ---

func (m *Memory) Balance(userID string) (int, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	txs := m.credits[userID]
	if len(txs) == 0 {
		return 0, nil
	}
	return txs[len(txs)-1].Balance, nil
}

func (m *Memory) AddCredits(tx *domain.CreditTransaction) (*domain.CreditTransaction, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	txs := m.credits[tx.UserID]
	prev := 0
	if len(txs) > 0 {
		prev = txs[len(txs)-1].Balance
	}
	cp := *tx
	cp.Balance = prev + tx.Amount
	if cp.CreatedAt.IsZero() {
		cp.CreatedAt = time.Now().UTC()
	}
	m.credits[tx.UserID] = append(txs, &cp)
	out := cp
	return &out, nil
}

func (m *Memory) ListCredits(userID string) ([]*domain.CreditTransaction, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	txs := m.credits[userID]
	out := make([]*domain.CreditTransaction, len(txs))
	for i, t := range txs {
		cp := *t
		out[i] = &cp
	}
	return out, nil
}

// --- Notifications ---

func (m *Memory) CreateNotification(n *domain.Notification) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	cp := *n
	m.notifications[n.UserID] = append(m.notifications[n.UserID], &cp)
	return nil
}

func (m *Memory) ListNotifications(userID string) ([]*domain.Notification, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	ns := m.notifications[userID]
	out := make([]*domain.Notification, len(ns))
	for i := range ns {
		cp := *ns[len(ns)-1-i] // newest first
		out[i] = &cp
	}
	return out, nil
}

func (m *Memory) MarkNotificationRead(userID, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, n := range m.notifications[userID] {
		if n.ID == id {
			n.Read = true
			return nil
		}
	}
	return ErrNotFound
}
