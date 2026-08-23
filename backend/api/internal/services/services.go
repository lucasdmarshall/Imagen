// Package services holds SHOW's business logic. Handlers (and the disposable
// dev tools) call these; services depend only on the store.Store interface and
// the AI client, never on HTTP.
package services

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/show/api/internal/aiclient"
	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/store"
)

var (
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrInsufficientCredits = errors.New("insufficient credits")
	ErrUnauthorized        = errors.New("unauthorized")
	ErrForbidden           = errors.New("forbidden")
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
	Catalog       CatalogService
	Generation    *GenerationService
	Admin         *AdminService
}

func New(st store.Store, ai *aiclient.Client) *Services {
	s := &Services{Store: st, AI: ai}
	s.Credits = &CreditsService{store: st}
	s.Notifications = &NotificationsService{store: st}
	s.Subscriptions = &SubscriptionService{store: st, credits: s.Credits, notify: s.Notifications}
	s.Profile = &ProfileService{store: st}
	s.Auth = &AuthService{store: st, subs: s.Subscriptions}
	s.Generation = &GenerationService{ai: ai, credits: s.Credits}
	s.Admin = &AdminService{store: st, credits: s.Credits, subs: s.Subscriptions, notify: s.Notifications}
	return s
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

type AuthService struct {
	store store.Store
	subs  *SubscriptionService
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
		Profile:      domain.Profile{DisplayName: displayName, Locale: "en"},
	}
	if err := a.store.CreateUser(u); err != nil {
		return nil, "", err
	}
	// Start on Free plan (grants monthly credits + welcome notification).
	_ = a.subs.SetPlan(u.ID, domain.PlanFree)
	token, err := a.issue(u.ID)
	return u, token, err
}

func (a *AuthService) Login(email, password string) (*domain.User, string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	u, err := a.store.GetUserByEmail(email)
	if err != nil {
		return nil, "", ErrInvalidCredentials
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)) != nil {
		return nil, "", ErrInvalidCredentials
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
	return a.store.GetUserByID(uid)
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

type CreditsService struct{ store store.Store }

func (c *CreditsService) Balance(userID string) (int, error) { return c.store.Balance(userID) }

func (c *CreditsService) History(userID string) ([]*domain.CreditTransaction, error) {
	return c.store.ListCredits(userID)
}

func (c *CreditsService) add(userID string, amount int, reason domain.CreditReason, note string) (*domain.CreditTransaction, error) {
	return c.store.AddCredits(&domain.CreditTransaction{
		ID: newID(), UserID: userID, Amount: amount, Reason: reason, Note: note,
	})
}

// Grant adds credits from a plan/periodic grant.
func (c *CreditsService) Grant(userID string, amount int, note string) (*domain.CreditTransaction, error) {
	return c.add(userID, amount, domain.CreditGrant, note)
}

// Purchase adds credits bought as an add-on pack.
func (c *CreditsService) Purchase(userID string, amount int, note string) (*domain.CreditTransaction, error) {
	return c.add(userID, amount, domain.CreditPurchase, note)
}

// Adjust is a manual admin correction (delta may be negative).
func (c *CreditsService) Adjust(userID, note string, delta int) (*domain.CreditTransaction, error) {
	return c.add(userID, delta, domain.CreditAdminAdjust, note)
}

// Consume deducts credits for AI usage, refusing to overdraw.
func (c *CreditsService) Consume(userID string, amount int, note string) (*domain.CreditTransaction, error) {
	bal, err := c.store.Balance(userID)
	if err != nil {
		return nil, err
	}
	if bal < amount {
		return nil, ErrInsufficientCredits
	}
	return c.add(userID, -amount, domain.CreditConsume, note)
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
}

func (s *SubscriptionService) Get(userID string) (*domain.Subscription, error) {
	return s.store.GetSubscription(userID)
}

// SetPlan changes a user's plan, grants that plan's monthly credits, and
// notifies them.
func (s *SubscriptionService) SetPlan(userID string, planID domain.PlanID) error {
	plan, ok := planByID(planID)
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
	if plan.MonthlyCredits > 0 {
		_, _ = s.credits.Grant(userID, plan.MonthlyCredits, "Plan grant: "+plan.Name)
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
		_, _ = g.credits.add(userID, CostPromptGenerate, domain.CreditRefund, "Refund: prompt gen failed")
	}
	return out, err
}

func (g *GenerationService) GenerateImage(ctx context.Context, userID string, body any) (json.RawMessage, error) {
	if _, err := g.credits.Consume(userID, CostImageGenerate, "Image generation"); err != nil {
		return nil, err
	}
	out, err := g.ai.GenerateImage(ctx, body)
	if err != nil {
		_, _ = g.credits.add(userID, CostImageGenerate, domain.CreditRefund, "Refund: image gen failed")
	}
	return out, err
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

type AdminService struct {
	store   store.Store
	credits *CreditsService
	subs    *SubscriptionService
	notify  *NotificationsService
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
	bal, _ := a.store.Balance(userID)
	sub, _ := a.store.GetSubscription(userID)
	return &UserDetail{User: u, Balance: bal, Subscription: sub}, nil
}

func (a *AdminService) SetRole(userID string, role domain.Role) error {
	u, err := a.store.GetUserByID(userID)
	if err != nil {
		return err
	}
	u.Role = role
	return a.store.UpdateUser(u)
}

// AdjustCredits is the admin credits-management operation.
func (a *AdminService) AdjustCredits(userID string, delta int, note string) (*domain.CreditTransaction, error) {
	return a.credits.Adjust(userID, note, delta)
}

// SetPlan is the admin plan/subscription-management operation.
func (a *AdminService) SetPlan(userID string, planID domain.PlanID) error {
	return a.subs.SetPlan(userID, planID)
}
