// Package domain holds SHOW's core data models and value types, shared by the
// services, HTTP layer, and (disposable) dev tools.
package domain

import "time"

// Role distinguishes normal users from admins.
type Role string

const (
	RoleUser  Role = "user"
	RoleAdmin Role = "admin"
)

// User is an account. PasswordHash is never serialized to clients.
type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	Role         Role      `json:"role"`
	CreatedAt    time.Time `json:"createdAt"`
	Profile      Profile   `json:"profile"`
	// Approved gates app access: a signed-in user waits in the Waiting Area
	// until an admin approves them. Admins are always approved.
	Approved bool `json:"approved"`
	// Banned blocks the app after login. Lifted by an admin without re-approval.
	Banned bool `json:"banned"`
	// DeletedAt is set when an admin deletes the account. Login then returns 404.
	DeletedAt *time.Time `json:"deletedAt,omitempty"`
}

// Deleted reports whether an admin has removed this account.
func (u *User) Deleted() bool {
	return u != nil && u.DeletedAt != nil && !u.DeletedAt.IsZero()
}

// Profile is user-editable presentation data.
type Profile struct {
	DisplayName string `json:"displayName"`
	Locale      string `json:"locale"` // "en" | "my"
	AvatarURL   string `json:"avatarUrl,omitempty"`
}

// --- Plans & subscriptions ---------------------------------------------------

// PlanID identifies a subscription tier.
type PlanID string

const (
	PlanFree        PlanID = "free"
	PlanProMonthly  PlanID = "pro_monthly"
	PlanProYearly   PlanID = "pro_yearly"
)

// Plan describes a subscription tier and what it grants.
type Plan struct {
	ID             PlanID `json:"id"`
	Name           string `json:"name"`
	PriceMMK       int    `json:"priceMmk"`       // Price in Kyat (0 = free).
	MonthlyCredits int    `json:"monthlyCredits"` // Credits granted per period.
	Description    string `json:"description"`
}

// Subscription is a user's current plan.
type Subscription struct {
	UserID    string    `json:"userId"`
	PlanID    PlanID    `json:"planId"`
	Status    string    `json:"status"` // "active" | "canceled"
	StartedAt time.Time `json:"startedAt"`
	RenewsAt  time.Time `json:"renewsAt"`
}

// --- Store -------------------------------------------------------------------

// StoreItemKind separates subscription products from one-off credit packs.
type StoreItemKind string

const (
	ItemSubscription StoreItemKind = "subscription"
	ItemCreditPack   StoreItemKind = "credit_pack" // add-on credits
)

// StoreItem is a purchasable product in the Store.
type StoreItem struct {
	ID        string        `json:"id"`
	Kind      StoreItemKind `json:"kind"`
	Name      string        `json:"name"`
	PriceMMK  int           `json:"priceMmk"`
	Credits   int           `json:"credits,omitempty"` // packs: granted add-on; subs: monthly allotment
	PlanID    PlanID        `json:"planId,omitempty"`  // for subscriptions
	SortOrder int           `json:"sortOrder,omitempty"`
}

// --- Credits -----------------------------------------------------------------

// CreditReason categorizes a ledger entry.
type CreditReason string

const (
	CreditGrant       CreditReason = "grant"        // plan/periodic grant
	CreditPurchase    CreditReason = "purchase"     // add-on pack
	CreditConsume     CreditReason = "consume"      // AI usage
	CreditRefund      CreditReason = "refund"
	CreditAdminAdjust CreditReason = "admin_adjust" // manual admin change
	CreditExpire      CreditReason = "expire"       // unused subscription credits at period end
)

// CreditWallet splits a user's balance into two buckets:
//   - SubscriptionCredits expire at the end of each monthly period and are
//     replaced by the next month's allotment (they do not stack).
//   - AddonCredits never expire and carry over.
type CreditWallet struct {
	UserID              string    `json:"userId"`
	SubscriptionCredits int       `json:"subscriptionCredits"`
	AddonCredits        int       `json:"addonCredits"`
	SubPeriodEndsAt     time.Time `json:"subPeriodEndsAt"`
}

// Total is subscription + add-on credits.
func (w *CreditWallet) Total() int {
	if w == nil {
		return 0
	}
	return w.SubscriptionCredits + w.AddonCredits
}

// --- Payments ----------------------------------------------------------------

const (
	PaymentPending  = "pending"
	PaymentApproved = "approved"
	PaymentRejected = "rejected"
)

// PaymentOrder is a store purchase waiting for (or already given) admin review.
// Credits are granted only after status becomes approved.
type PaymentOrder struct {
	ID            string        `json:"id"`
	UserID        string        `json:"userId"`
	UserEmail     string        `json:"userEmail"`
	UserName      string        `json:"userName"`
	ItemID        string        `json:"itemId"`
	Kind          StoreItemKind `json:"kind"`
	ItemName      string        `json:"itemName"`
	PriceMMK      int           `json:"priceMmk"`
	Credits       int           `json:"credits,omitempty"`
	PlanID        PlanID        `json:"planId,omitempty"`
	Method        string        `json:"method"`
	ProofUploadID string        `json:"proofUploadId"`
	Status        string        `json:"status"`
	AdminNote     string        `json:"adminNote,omitempty"`
	CreatedAt     time.Time     `json:"createdAt"`
	ReviewedAt    *time.Time    `json:"reviewedAt,omitempty"`
	ReviewedBy    string        `json:"reviewedBy,omitempty"`
}

// CreditTransaction is one immutable ledger entry. Amount is signed
// (positive = added, negative = deducted).
type CreditTransaction struct {
	ID        string       `json:"id"`
	UserID    string       `json:"userId"`
	Amount    int          `json:"amount"`
	Reason    CreditReason `json:"reason"`
	Note      string       `json:"note,omitempty"`
	Balance   int          `json:"balance"` // running balance after this entry
	CreatedAt time.Time    `json:"createdAt"`
}

// --- Notifications -----------------------------------------------------------

// Notification is a message shown to a user.
type Notification struct {
	ID        string    `json:"id"`
	UserID    string    `json:"userId"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	Read      bool      `json:"read"`
	CreatedAt time.Time `json:"createdAt"`
}
