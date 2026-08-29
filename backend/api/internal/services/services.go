// Package services holds SHOW's business logic. Handlers (and the disposable
// dev tools) call these; services depend only on the store.Store interface and
// the AI client, never on HTTP.
package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/show/api/internal/aiclient"
	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/firebase"
	"github.com/show/api/internal/store"
)

var (
	ErrInvalidCredentials  = errors.New("invalid email or password")
	ErrInsufficientCredits = errors.New("insufficient credits")
	ErrUnauthorized        = errors.New("unauthorized")
	ErrForbidden           = errors.New("forbidden")
	ErrBadRequest          = errors.New("bad request")
	ErrConflict            = errors.New("conflict")
	ErrAccountDeleted      = errors.New("account deleted")
)

// Services is the wired container of all services.
type Services struct {
	Store         store.Store
	AI            *aiclient.Client
	Auth          *AuthService
	Profile       *ProfileService
	Credits       *CreditsService
	Notifications *NotificationsService
	Subscriptions *SubscriptionService
	Catalog       *CatalogService
	Generation    *GenerationService
	Admin         *AdminService
	Payments      *PaymentsService
	Hub           *AdminHub
}

func New(st store.Store, ai *aiclient.Client) *Services {
	s := &Services{Store: st, AI: ai, Hub: NewAdminHub()}
	s.Credits = &CreditsService{store: st}
	s.Notifications = &NotificationsService{store: st}
	s.Catalog = &CatalogService{store: st, hub: s.Hub}
	_ = s.Catalog.EnsureDefaults()
	s.Subscriptions = &SubscriptionService{store: st, credits: s.Credits, notify: s.Notifications, catalog: s.Catalog}
	s.Credits.catalog = s.Catalog
	s.Profile = &ProfileService{store: st}
	s.Auth = &AuthService{store: st, subs: s.Subscriptions, hub: s.Hub}
	s.Generation = &GenerationService{ai: ai, credits: s.Credits}
	s.Payments = &PaymentsService{store: st, credits: s.Credits, subs: s.Subscriptions, notify: s.Notifications, hub: s.Hub, catalog: s.Catalog}
	s.Admin = &AdminService{store: st, credits: s.Credits, subs: s.Subscriptions, notify: s.Notifications, payments: s.Payments, hub: s.Hub}
	return s
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

type AuthService struct {
	store store.Store
	subs  *SubscriptionService
	hub   *AdminHub
}

// Register creates a user, starts them on the Free plan (granting its credits),
// and returns a session token.
func (a *AuthService) Register(email, password, displayName string) (*domain.User, string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" || len(password) < 6 {
		return nil, "", errors.New("email required and password must be >= 6 chars")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, "", err
	}
	u := &domain.User{
		ID:           newID(),
		Email:        email,
		PasswordHash: string(hash),
		Role:         domain.RoleUser,
		CreatedAt:    time.Now().UTC(),
		// Burmese is the app default; English is an optional switch.
		Profile:      domain.Profile{DisplayName: displayName, Locale: "my"},
	}
	if err := a.store.CreateUser(u); err != nil {
		return nil, "", err
	}
	// Start on Free plan (grants monthly credits + welcome notification).
	_ = a.subs.SetPlan(u.ID, domain.PlanFree)
	a.hub.Publish(TopicUsers)
	token, err := a.issue(u.ID)
	return u, token, err
}

// EnsureAdmin creates the given account if missing, then guarantees it is an
// approved admin. Used to bootstrap the first admin in production (where the
// dev tools are disabled). Idempotent: safe to call on every startup.
func (a *AuthService) EnsureAdmin(email, password string) error {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return errors.New("admin email required")
	}
	u, err := a.store.GetUserByEmail(email)
	if errors.Is(err, store.ErrNotFound) {
		if len(password) < 6 {
			return errors.New("admin password must be >= 6 chars to create the account")
		}
		if _, _, err := a.Register(email, password, "Admin"); err != nil {
			return err
		}
		u, err = a.store.GetUserByEmail(email)
	}
	if err != nil {
		return err
	}
	if u.Role == domain.RoleAdmin && u.Approved {
		return nil
	}
	u.Role = domain.RoleAdmin
	u.Approved = true
	return a.store.UpdateUser(u)
}

func (a *AuthService) Login(email, password string) (*domain.User, string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	u, err := a.store.GetUserByEmail(email)
	if err != nil {
		return nil, "", ErrInvalidCredentials
	}
	if u.Deleted() {
		return nil, "", ErrAccountDeleted
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)) != nil {
		return nil, "", ErrInvalidCredentials
	}
	token, err := a.issue(u.ID)
	return u, token, err
}

// LoginWithGoogle verifies a Firebase Google ID token, finds or creates the
// matching user, and issues a session token. New Google users are unapproved
// (they land in the Waiting Area until an admin approves them), just like
// email sign-ups.
func (a *AuthService) LoginWithGoogle(idToken string) (*domain.User, string, error) {
	claims, err := firebase.VerifyIDToken(idToken)
	if err != nil {
		return nil, "", ErrUnauthorized
	}
	email := strings.ToLower(strings.TrimSpace(claims.Email))
	if email == "" {
		return nil, "", ErrUnauthorized
	}
	u, err := a.store.GetUserByEmail(email)
	if err != nil {
		// First time this Google account signs in — create the account.
		u = &domain.User{
			ID:        newID(),
			Email:     email,
			Role:      domain.RoleUser,
			CreatedAt: time.Now().UTC(),
			Profile:   domain.Profile{DisplayName: claims.Name, Locale: "my"},
		}
		if err := a.store.CreateUser(u); err != nil {
			return nil, "", err
		}
		_ = a.subs.SetPlan(u.ID, domain.PlanFree)
		a.hub.Publish(TopicUsers)
	}
	if u.Deleted() {
		return nil, "", ErrAccountDeleted
	}
	token, err := a.issue(u.ID)
	return u, token, err
}

func (a *AuthService) Logout(token string) error { return a.store.DeleteSession(token) }

// Authenticate resolves a bearer token to its user.
func (a *AuthService) Authenticate(token string) (*domain.User, error) {
	uid, err := a.store.SessionUser(token)
	if err != nil {
		return nil, ErrUnauthorized
	}
	u, err := a.store.GetUserByID(uid)
	if err != nil {
		return nil, ErrUnauthorized
	}
	if u.Deleted() {
		return nil, ErrAccountDeleted
	}
	return u, nil
}

// SessionTTL is how long an issued bearer token remains valid.
const SessionTTL = 30 * 24 * time.Hour

func (a *AuthService) issue(userID string) (string, error) {
	token := newToken()
	return token, a.store.CreateSession(token, userID, time.Now().Add(SessionTTL))
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

type ProfileService struct{ store store.Store }

func (p *ProfileService) Get(userID string) (*domain.User, error) {
	return p.store.GetUserByID(userID)
}

func (p *ProfileService) Update(userID string, patch domain.Profile) (*domain.User, error) {
	u, err := p.store.GetUserByID(userID)
	if err != nil {
		return nil, err
	}
	if patch.DisplayName != "" {
		u.Profile.DisplayName = patch.DisplayName
	}
	if patch.Locale != "" {
		u.Profile.Locale = patch.Locale
	}
	if patch.AvatarURL != "" {
		u.Profile.AvatarURL = patch.AvatarURL
	}
	if err := p.store.UpdateUser(u); err != nil {
		return nil, err
	}
	return u, nil
}

// ---------------------------------------------------------------------------
// Credits
// ---------------------------------------------------------------------------

type CreditsService struct {
	store   store.Store
	catalog *CatalogService
}

func (c *CreditsService) Wallet(userID string) (*domain.CreditWallet, error) {
	if err := c.EnsurePeriod(userID); err != nil {
		return nil, err
	}
	return c.store.GetWallet(userID)
}

func (c *CreditsService) Balance(userID string) (int, error) {
	w, err := c.Wallet(userID)
	if err != nil {
		return 0, err
	}
	return w.Total(), nil
}

func (c *CreditsService) History(userID string) ([]*domain.CreditTransaction, error) {
	return c.store.ListCredits(userID)
}

func creditTx(userID string, amount int, reason domain.CreditReason, note string) *domain.CreditTransaction {
	return &domain.CreditTransaction{
		ID: newID(), UserID: userID, Amount: amount, Reason: reason, Note: note,
	}
}

func lastTx(txs []*domain.CreditTransaction) *domain.CreditTransaction {
	if len(txs) == 0 {
		return nil
	}
	return txs[len(txs)-1]
}

func deduct(w *domain.CreditWallet, amount int) bool {
	if amount <= 0 || w.Total() < amount {
		return false
	}
	if w.SubscriptionCredits >= amount {
		w.SubscriptionCredits -= amount
		return true
	}
	amount -= w.SubscriptionCredits
	w.SubscriptionCredits = 0
	w.AddonCredits -= amount
	return true
}

// EnsurePeriod expires leftover subscription credits when a monthly window
// ends and, if the plan is still covered, grants this month's allotment.
// Add-on credits are never touched. Yearly plans still refresh monthly
// until RenewsAt; unpaid monthly plans stop granting after RenewsAt.
func (c *CreditsService) EnsurePeriod(userID string) error {
	sub, err := c.store.GetSubscription(userID)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return err
	}
	_, _, err = c.store.MutateWallet(userID, func(w *domain.CreditWallet) ([]*domain.CreditTransaction, error) {
		now := time.Now().UTC()
		if w.SubPeriodEndsAt.IsZero() {
			w.SubPeriodEndsAt = now.AddDate(0, 1, 0)
		}
		if !now.After(w.SubPeriodEndsAt) {
			return nil, nil
		}
		planID := domain.PlanFree
		status := ""
		var renews time.Time
		if sub != nil {
			planID = sub.PlanID
			status = sub.Status
			renews = sub.RenewsAt
		}
		plan, ok := c.catalog.Plan(planID)
		if !ok {
			plan, _ = c.catalog.Plan(domain.PlanFree)
		}
		var txs []*domain.CreditTransaction
		for now.After(w.SubPeriodEndsAt) {
			if leftover := w.SubscriptionCredits; leftover > 0 {
				w.SubscriptionCredits = 0
				txs = append(txs, creditTx(userID, -leftover, domain.CreditExpire, "Unused subscription credits expired"))
			}
			periodStart := w.SubPeriodEndsAt
			w.SubPeriodEndsAt = w.SubPeriodEndsAt.AddDate(0, 1, 0)
			covered := status == "active" && (planID == domain.PlanFree || periodStart.Before(renews))
			if covered && plan.MonthlyCredits > 0 {
				w.SubscriptionCredits = plan.MonthlyCredits
				txs = append(txs, creditTx(userID, plan.MonthlyCredits, domain.CreditGrant, "Monthly plan grant: "+plan.Name))
			}
		}
		return txs, nil
	})
	return err
}

// RefreshSubscription replaces unused subscription credits with this period's
// allotment (they do not stack) and starts a new monthly window.
func (c *CreditsService) RefreshSubscription(userID string, amount int, note string) error {
	_, _, err := c.store.MutateWallet(userID, func(w *domain.CreditWallet) ([]*domain.CreditTransaction, error) {
		var txs []*domain.CreditTransaction
		if leftover := w.SubscriptionCredits; leftover > 0 {
			w.SubscriptionCredits = 0
			txs = append(txs, creditTx(userID, -leftover, domain.CreditExpire, "Unused subscription credits replaced"))
		}
		w.SubscriptionCredits = amount
		w.SubPeriodEndsAt = time.Now().UTC().AddDate(0, 1, 0)
		if amount > 0 {
			txs = append(txs, creditTx(userID, amount, domain.CreditGrant, note))
		}
		return txs, nil
	})
	return err
}

// Purchase adds credits bought as an add-on pack (never expire).
func (c *CreditsService) Purchase(userID string, amount int, note string) (*domain.CreditTransaction, error) {
	if amount <= 0 {
		return nil, fmt.Errorf("%w: amount must be positive", ErrBadRequest)
	}
	_, txs, err := c.store.MutateWallet(userID, func(w *domain.CreditWallet) ([]*domain.CreditTransaction, error) {
		w.AddonCredits += amount
		return []*domain.CreditTransaction{creditTx(userID, amount, domain.CreditPurchase, note)}, nil
	})
	return lastTx(txs), err
}

// Adjust is a manual admin correction (delta may be negative).
func (c *CreditsService) Adjust(userID, note string, delta int) (*domain.CreditTransaction, error) {
	if delta == 0 {
		return nil, fmt.Errorf("%w: delta must be non-zero", ErrBadRequest)
	}
	_, txs, err := c.store.MutateWallet(userID, func(w *domain.CreditWallet) ([]*domain.CreditTransaction, error) {
		if delta > 0 {
			w.AddonCredits += delta
			return []*domain.CreditTransaction{creditTx(userID, delta, domain.CreditAdminAdjust, note)}, nil
		}
		if !deduct(w, -delta) {
			return nil, ErrInsufficientCredits
		}
		return []*domain.CreditTransaction{creditTx(userID, delta, domain.CreditAdminAdjust, note)}, nil
	})
	return lastTx(txs), err
}

// Consume deducts credits for AI usage (subscription bucket first, then add-on).
func (c *CreditsService) Consume(userID string, amount int, note string) (*domain.CreditTransaction, error) {
	if amount <= 0 {
		return nil, fmt.Errorf("%w: amount must be positive", ErrBadRequest)
	}
	if err := c.EnsurePeriod(userID); err != nil {
		return nil, err
	}
	_, txs, err := c.store.MutateWallet(userID, func(w *domain.CreditWallet) ([]*domain.CreditTransaction, error) {
		if !deduct(w, amount) {
			return nil, ErrInsufficientCredits
		}
		return []*domain.CreditTransaction{creditTx(userID, -amount, domain.CreditConsume, note)}, nil
	})
	return lastTx(txs), err
}

func (c *CreditsService) refund(userID string, amount int, note string) {
	if amount <= 0 {
		return
	}
	_, _, _ = c.store.MutateWallet(userID, func(w *domain.CreditWallet) ([]*domain.CreditTransaction, error) {
		w.AddonCredits += amount
		return []*domain.CreditTransaction{creditTx(userID, amount, domain.CreditRefund, note)}, nil
	})
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

type NotificationsService struct{ store store.Store }

func (n *NotificationsService) Notify(userID, title, body string) (*domain.Notification, error) {
	note := &domain.Notification{
		ID: newID(), UserID: userID, Title: title, Body: body,
		CreatedAt: time.Now().UTC(),
	}
	return note, n.store.CreateNotification(note)
}

func (n *NotificationsService) List(userID string) ([]*domain.Notification, error) {
	return n.store.ListNotifications(userID)
}

func (n *NotificationsService) MarkRead(userID, id string) error {
	return n.store.MarkNotificationRead(userID, id)
}

// ---------------------------------------------------------------------------
// Subscriptions
// ---------------------------------------------------------------------------

type SubscriptionService struct {
	store   store.Store
	credits *CreditsService
	notify  *NotificationsService
	catalog *CatalogService
}

func (s *SubscriptionService) Get(userID string) (*domain.Subscription, error) {
	return s.store.GetSubscription(userID)
}

// SetPlan changes a user's plan, grants that plan's monthly credits, and
// notifies them.
func (s *SubscriptionService) SetPlan(userID string, planID domain.PlanID) error {
	plan, ok := s.catalog.Plan(planID)
	if !ok {
		return errors.New("unknown plan")
	}
	now := time.Now().UTC()
	renews := now.AddDate(0, 1, 0)
	if planID == domain.PlanProYearly {
		renews = now.AddDate(1, 0, 0)
	}
	sub := &domain.Subscription{
		UserID: userID, PlanID: planID, Status: "active", StartedAt: now, RenewsAt: renews,
	}
	if err := s.store.SetSubscription(sub); err != nil {
		return err
	}
	if err := s.credits.RefreshSubscription(userID, plan.MonthlyCredits, "Plan grant: "+plan.Name); err != nil {
		return err
	}
	_, _ = s.notify.Notify(userID, "Plan updated", "You are now on the "+plan.Name+" plan.")
	return nil
}

// ---------------------------------------------------------------------------
// Generation (AI) — consumes credits, then calls the Python AI service.
// ---------------------------------------------------------------------------

type GenerationService struct {
	ai      *aiclient.Client
	credits *CreditsService
}

func (g *GenerationService) GeneratePrompt(ctx context.Context, userID string, body any) (json.RawMessage, error) {
	if _, err := g.credits.Consume(userID, CostPromptGenerate, "Prompt generation"); err != nil {
		return nil, err
	}
	out, err := g.ai.GeneratePrompt(ctx, body)
	if err != nil {
		g.credits.refund(userID, CostPromptGenerate, "Refund: prompt gen failed")
	}
	return out, err
}

func (g *GenerationService) GenerateImage(ctx context.Context, userID string, body any) (json.RawMessage, error) {
	if _, err := g.credits.Consume(userID, CostImageGenerate, "Image generation"); err != nil {
		return nil, err
	}
	out, err := g.ai.GenerateImage(ctx, body)
	if err != nil {
		g.credits.refund(userID, CostImageGenerate, "Refund: image gen failed")
	}
	return out, err
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

type AdminService struct {
	store    store.Store
	credits  *CreditsService
	subs     *SubscriptionService
	notify   *NotificationsService
	payments *PaymentsService
	hub      *AdminHub
}

// UserDetail is an admin's composite view of a user.
type UserDetail struct {
	User         *domain.User         `json:"user"`
	Balance      int                  `json:"balance"`
	Subscription *domain.Subscription `json:"subscription"`
}

func (a *AdminService) ListUsers() ([]*domain.User, error) { return a.store.ListUsers() }

func (a *AdminService) UserDetail(userID string) (*UserDetail, error) {
	u, err := a.store.GetUserByID(userID)
	if err != nil {
		return nil, err
	}
	w, _ := a.credits.Wallet(userID)
	bal := 0
	if w != nil {
		bal = w.Total()
	}
	sub, _ := a.store.GetSubscription(userID)
	return &UserDetail{User: u, Balance: bal, Subscription: sub}, nil
}

func (a *AdminService) SetRole(userID string, role domain.Role) error {
	u, err := a.store.GetUserByID(userID)
	if err != nil {
		return err
	}
	u.Role = role
	// An admin is implicitly approved — they must never be stuck in the gate.
	if role == domain.RoleAdmin {
		u.Approved = true
	}
	if err := a.store.UpdateUser(u); err != nil {
		return err
	}
	a.hub.Publish(TopicUsers)
	return nil
}

// SetApproval flips the Waiting-Area gate for a user (Approvals section).
func (a *AdminService) SetApproval(userID string, approved bool) error {
	u, err := a.store.GetUserByID(userID)
	if err != nil {
		return err
	}
	u.Approved = approved
	if err := a.store.UpdateUser(u); err != nil {
		return err
	}
	a.hub.Publish(TopicUsers)
	return nil
}

// AdjustCredits is the admin credits-management operation.
func (a *AdminService) AdjustCredits(userID string, delta int, note string) (*domain.CreditTransaction, error) {
	tx, err := a.credits.Adjust(userID, note, delta)
	if err != nil {
		return nil, err
	}
	a.hub.Publish(TopicUsers)
	return tx, nil
}

// SetPlan is the admin plan/subscription-management operation.
func (a *AdminService) SetPlan(userID string, planID domain.PlanID) error {
	if err := a.subs.SetPlan(userID, planID); err != nil {
		return err
	}
	a.hub.Publish(TopicUsers)
	return nil
}

func (a *AdminService) SetBan(actorID, userID string, banned bool) error {
	if actorID == userID {
		return fmt.Errorf("%w: cannot ban yourself", ErrBadRequest)
	}
	u, err := a.store.GetUserByID(userID)
	if err != nil {
		return err
	}
	if u.Deleted() {
		return ErrAccountDeleted
	}
	if u.Role == domain.RoleAdmin {
		return fmt.Errorf("%w: cannot ban an admin", ErrForbidden)
	}
	u.Banned = banned
	if err := a.store.UpdateUser(u); err != nil {
		return err
	}
	if banned {
		_ = a.store.DeleteSessionsByUser(userID)
	}
	a.hub.Publish(TopicUsers)
	return nil
}

func (a *AdminService) DeleteUser(actorID, userID string) error {
	if actorID == userID {
		return fmt.Errorf("%w: cannot delete yourself", ErrBadRequest)
	}
	u, err := a.store.GetUserByID(userID)
	if err != nil {
		return err
	}
	if u.Deleted() {
		return ErrAccountDeleted
	}
	if u.Role == domain.RoleAdmin {
		return fmt.Errorf("%w: cannot delete an admin", ErrForbidden)
	}
	now := time.Now().UTC()
	u.DeletedAt = &now
	u.Banned = false
	if err := a.store.UpdateUser(u); err != nil {
		return err
	}
	_ = a.store.DeleteSessionsByUser(userID)
	a.hub.Publish(TopicUsers)
	return nil
}

func (a *AdminService) ResetPassword(userID, password string) (string, error) {
	u, err := a.store.GetUserByID(userID)
	if err != nil {
		return "", err
	}
	if u.Deleted() {
		return "", ErrAccountDeleted
	}
	if u.Role == domain.RoleAdmin {
		return "", fmt.Errorf("%w: cannot reset an admin password here", ErrForbidden)
	}
	password = strings.TrimSpace(password)
	if password == "" {
		password = tempPassword()
	}
	if len(password) < 6 {
		return "", fmt.Errorf("%w: password must be >= 6 chars", ErrBadRequest)
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	u.PasswordHash = string(hash)
	if err := a.store.UpdateUser(u); err != nil {
		return "", err
	}
	_ = a.store.DeleteSessionsByUser(userID)
	return password, nil
}

func (a *AdminService) ListPayments(status string) ([]*domain.PaymentOrder, error) {
	return a.payments.List(status)
}

func (a *AdminService) ApprovePayment(adminID, paymentID string) (*domain.PaymentOrder, error) {
	return a.payments.Approve(adminID, paymentID)
}

func (a *AdminService) RejectPayment(adminID, paymentID, note string) (*domain.PaymentOrder, error) {
	return a.payments.Reject(adminID, paymentID, note)
}
