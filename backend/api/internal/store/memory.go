package store

import (
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/show/api/internal/domain"
)

type session struct {
	userID    string
	expiresAt time.Time
}

// Memory is a thread-safe, in-memory Store for development and tests.
type Memory struct {
	mu            sync.RWMutex
	users         map[string]*domain.User // by ID
	emailIndex    map[string]string       // email -> ID
	sessions      map[string]session      // token -> session
	subs          map[string]*domain.Subscription
	credits       map[string][]*domain.CreditTransaction // by userID (ordered)
	notifications map[string][]*domain.Notification      // by userID
	idem          map[string]IdempotentResult            // idempotency key -> result
	uploads       map[string]*Upload                     // upload id -> upload
	wallets       map[string]*domain.CreditWallet
	payments      map[string]*domain.PaymentOrder
	plans         map[domain.PlanID]domain.Plan
	items         map[string]domain.StoreItem
}

func NewMemory() *Memory {
	return &Memory{
		users:         map[string]*domain.User{},
		emailIndex:    map[string]string{},
		sessions:      map[string]session{},
		subs:          map[string]*domain.Subscription{},
		credits:       map[string][]*domain.CreditTransaction{},
		notifications: map[string][]*domain.Notification{},
		idem:          map[string]IdempotentResult{},
		uploads:       map[string]*Upload{},
		wallets:       map[string]*domain.CreditWallet{},
		payments:      map[string]*domain.PaymentOrder{},
		plans:         map[domain.PlanID]domain.Plan{},
		items:         map[string]domain.StoreItem{},
	}
}

func (m *Memory) SaveUpload(u *Upload) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	cp := *u
	m.uploads[u.ID] = &cp
	return nil
}

func (m *Memory) GetUpload(id string) (*Upload, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	u, ok := m.uploads[id]
	if !ok {
		return nil, ErrNotFound
	}
	cp := *u
	return &cp, nil
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
		if u.Deleted() {
			continue
		}
		cp := *u
		out = append(out, &cp)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.Before(out[j].CreatedAt) })
	return out, nil
}

// --- Sessions ---

func (m *Memory) CreateSession(token, userID string, expiresAt time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessions[token] = session{userID: userID, expiresAt: expiresAt}
	return nil
}

func (m *Memory) SessionUser(token string) (string, error) {
	m.mu.RLock()
	s, ok := m.sessions[token]
	m.mu.RUnlock()
	if !ok {
		return "", ErrNotFound
	}
	if time.Now().After(s.expiresAt) {
		m.mu.Lock()
		delete(m.sessions, token)
		m.mu.Unlock()
		return "", ErrNotFound
	}
	return s.userID, nil
}

func (m *Memory) DeleteSession(token string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.sessions, token)
	return nil
}

func (m *Memory) DeleteSessionsByUser(userID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for tok, s := range m.sessions {
		if s.userID == userID {
			delete(m.sessions, tok)
		}
	}
	return nil
}

// --- Idempotency ---

func (m *Memory) GetIdempotent(key string) (*IdempotentResult, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	r, ok := m.idem[key]
	if !ok {
		return nil, false
	}
	cp := r
	return &cp, true
}

// SaveIdempotent stores r under key only if absent, returning the winning entry
// and whether it already existed (atomic check-and-set).
func (m *Memory) SaveIdempotent(key string, r IdempotentResult) (IdempotentResult, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if existing, ok := m.idem[key]; ok {
		return existing, true
	}
	if r.CreatedAt.IsZero() {
		r.CreatedAt = time.Now().UTC()
	}
	m.idem[key] = r
	return r, false
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

func (m *Memory) ledgerBalanceLocked(userID string) int {
	txs := m.credits[userID]
	if len(txs) == 0 {
		return 0
	}
	return txs[len(txs)-1].Balance
}

func (m *Memory) ensureWalletLocked(userID string) *domain.CreditWallet {
	if w, ok := m.wallets[userID]; ok {
		return w
	}
	w := &domain.CreditWallet{
		UserID:          userID,
		AddonCredits:    m.ledgerBalanceLocked(userID),
		SubPeriodEndsAt: time.Now().UTC().AddDate(0, 1, 0),
	}
	m.wallets[userID] = w
	return w
}

func (m *Memory) GetWallet(userID string) (*domain.CreditWallet, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	cp := *m.ensureWalletLocked(userID)
	return &cp, nil
}

func (m *Memory) MutateWallet(userID string, fn func(*domain.CreditWallet) ([]*domain.CreditTransaction, error)) (*domain.CreditWallet, []*domain.CreditTransaction, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	cur := m.ensureWalletLocked(userID)
	w := *cur
	txs, err := fn(&w)
	if err != nil {
		return nil, nil, err
	}
	prev := m.ledgerBalanceLocked(userID)
	out := make([]*domain.CreditTransaction, 0, len(txs))
	for _, tx := range txs {
		if tx == nil {
			continue
		}
		cp := *tx
		cp.UserID = userID
		if cp.ID == "" {
			cp.ID = fmt.Sprintf("%d", time.Now().UTC().UnixNano())
		}
		if cp.CreatedAt.IsZero() {
			cp.CreatedAt = time.Now().UTC()
		}
		prev += cp.Amount
		cp.Balance = prev
		stored := cp
		m.credits[userID] = append(m.credits[userID], &stored)
		out = append(out, &cp)
	}
	saved := w
	saved.UserID = userID
	m.wallets[userID] = &saved
	ret := saved
	return &ret, out, nil
}

func (m *Memory) CreatePayment(p *domain.PaymentOrder) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	cp := *p
	if cp.CreatedAt.IsZero() {
		cp.CreatedAt = time.Now().UTC()
	}
	m.payments[p.ID] = &cp
	return nil
}

func (m *Memory) GetPayment(id string) (*domain.PaymentOrder, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	p, ok := m.payments[id]
	if !ok {
		return nil, ErrNotFound
	}
	cp := *p
	return &cp, nil
}

func (m *Memory) ListPayments(status string) ([]*domain.PaymentOrder, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*domain.PaymentOrder, 0, len(m.payments))
	for _, p := range m.payments {
		if status != "" && p.Status != status {
			continue
		}
		cp := *p
		out = append(out, &cp)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (m *Memory) UpdatePayment(p *domain.PaymentOrder) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.payments[p.ID]; !ok {
		return ErrNotFound
	}
	cp := *p
	m.payments[p.ID] = &cp
	return nil
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

// --- Catalog ---

func (m *Memory) ListPlans() ([]domain.Plan, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]domain.Plan, 0, len(m.plans))
	for _, p := range m.plans {
		out = append(out, p)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func (m *Memory) GetPlan(id domain.PlanID) (domain.Plan, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	p, ok := m.plans[id]
	if !ok {
		return domain.Plan{}, ErrNotFound
	}
	return p, nil
}

func (m *Memory) UpsertPlan(p domain.Plan) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.plans[p.ID] = p
	return nil
}

func (m *Memory) ListStoreItems() ([]domain.StoreItem, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]domain.StoreItem, 0, len(m.items))
	for _, it := range m.items {
		out = append(out, it)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].SortOrder != out[j].SortOrder {
			return out[i].SortOrder < out[j].SortOrder
		}
		return out[i].ID < out[j].ID
	})
	return out, nil
}

func (m *Memory) GetStoreItem(id string) (domain.StoreItem, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	it, ok := m.items[id]
	if !ok {
		return domain.StoreItem{}, ErrNotFound
	}
	return it, nil
}

func (m *Memory) UpsertStoreItem(it domain.StoreItem) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.items[it.ID] = it
	return nil
}

func (m *Memory) DeleteStoreItem(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.items[id]; !ok {
		return ErrNotFound
	}
	delete(m.items, id)
	return nil
}
