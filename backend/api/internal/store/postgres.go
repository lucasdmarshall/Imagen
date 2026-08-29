package store

import (
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strings"
	"time"

	"github.com/show/api/internal/domain"
)

// Postgres is a Store backed by PostgreSQL. It satisfies the same interface as
// the in-memory store, so swapping it in is a one-line change in main.
type Postgres struct {
	db *sql.DB
}

// NewPostgres wraps an open *sql.DB. Callers own the DB lifecycle.
func NewPostgres(db *sql.DB) *Postgres { return &Postgres{db: db} }

// Migrate applies every embedded *.sql migration in filename order. All
// migrations are idempotent (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS), so this
// is safe to run on every boot.
func Migrate(db *sql.DB, files fs.FS) error {
	entries, err := fs.Glob(files, "*.sql")
	if err != nil {
		return err
	}
	sort.Strings(entries)
	for _, name := range entries {
		b, err := fs.ReadFile(files, name)
		if err != nil {
			return fmt.Errorf("read %s: %w", name, err)
		}
		// pgx's extended protocol rejects multiple statements in one Exec, so
		// run each statement separately.
		for _, stmt := range splitSQL(string(b)) {
			if _, err := db.Exec(stmt); err != nil {
				return fmt.Errorf("apply %s: %w", name, err)
			}
		}
	}
	return nil
}

// splitSQL strips `--` line comments and splits a script into individual
// statements on semicolons. The migrations contain no semicolons inside string
// literals, so this simple split is sufficient.
func splitSQL(script string) []string {
	var b strings.Builder
	for _, line := range strings.Split(script, "\n") {
		if i := strings.Index(line, "--"); i >= 0 {
			line = line[:i]
		}
		b.WriteString(line)
		b.WriteByte('\n')
	}
	var out []string
	for _, s := range strings.Split(b.String(), ";") {
		if strings.TrimSpace(s) != "" {
			out = append(out, s)
		}
	}
	return out
}

func now(t time.Time) time.Time {
	if t.IsZero() {
		return time.Now().UTC()
	}
	return t
}

// --- Users ---

func (p *Postgres) CreateUser(u *domain.User) error {
	_, err := p.db.Exec(`
		INSERT INTO users (id, email, password_hash, role, display_name, locale, avatar_url, approved, banned, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		u.ID, u.Email, u.PasswordHash, string(u.Role),
		u.Profile.DisplayName, u.Profile.Locale, u.Profile.AvatarURL,
		u.Approved, u.Banned, now(u.CreatedAt))
	if err != nil {
		if isUniqueViolation(err) {
			return ErrEmailTaken
		}
		return err
	}
	return nil
}

const userCols = `id, email, password_hash, role, display_name, locale, avatar_url, approved, banned, deleted_at, created_at`

func scanUser(row interface{ Scan(...any) error }) (*domain.User, error) {
	var u domain.User
	var role string
	var deleted sql.NullTime
	if err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &role,
		&u.Profile.DisplayName, &u.Profile.Locale, &u.Profile.AvatarURL,
		&u.Approved, &u.Banned, &deleted, &u.CreatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	u.Role = domain.Role(role)
	if deleted.Valid {
		t := deleted.Time
		u.DeletedAt = &t
	}
	return &u, nil
}

func (p *Postgres) GetUserByID(id string) (*domain.User, error) {
	return scanUser(p.db.QueryRow(`SELECT `+userCols+` FROM users WHERE id=$1`, id))
}

func (p *Postgres) GetUserByEmail(email string) (*domain.User, error) {
	return scanUser(p.db.QueryRow(`SELECT `+userCols+` FROM users WHERE email=$1`, email))
}

func (p *Postgres) UpdateUser(u *domain.User) error {
	res, err := p.db.Exec(`
		UPDATE users SET email=$2, password_hash=$3, role=$4,
			display_name=$5, locale=$6, avatar_url=$7, approved=$8, banned=$9, deleted_at=$10
		WHERE id=$1`,
		u.ID, u.Email, u.PasswordHash, string(u.Role),
		u.Profile.DisplayName, u.Profile.Locale, u.Profile.AvatarURL, u.Approved,
		u.Banned, nullableTime(u.DeletedAt))
	if err != nil {
		return err
	}
	return mustAffect(res)
}

func (p *Postgres) ListUsers() ([]*domain.User, error) {
	rows, err := p.db.Query(`SELECT ` + userCols + ` FROM users WHERE deleted_at IS NULL ORDER BY created_at ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*domain.User
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// --- Sessions ---

func (p *Postgres) CreateSession(token, userID string, expiresAt time.Time) error {
	_, err := p.db.Exec(
		`INSERT INTO sessions (token, user_id, expires_at) VALUES ($1,$2,$3)`,
		token, userID, expiresAt)
	return err
}

func (p *Postgres) SessionUser(token string) (string, error) {
	var userID string
	var expiresAt time.Time
	err := p.db.QueryRow(
		`SELECT user_id, expires_at FROM sessions WHERE token=$1`, token).
		Scan(&userID, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", err
	}
	if time.Now().After(expiresAt) {
		_, _ = p.db.Exec(`DELETE FROM sessions WHERE token=$1`, token)
		return "", ErrNotFound
	}
	return userID, nil
}

func (p *Postgres) DeleteSession(token string) error {
	_, err := p.db.Exec(`DELETE FROM sessions WHERE token=$1`, token)
	return err
}

func (p *Postgres) DeleteSessionsByUser(userID string) error {
	_, err := p.db.Exec(`DELETE FROM sessions WHERE user_id=$1`, userID)
	return err
}

// --- Idempotency ---

func (p *Postgres) GetIdempotent(key string) (*IdempotentResult, bool) {
	var r IdempotentResult
	err := p.db.QueryRow(
		`SELECT status, body, created_at FROM idempotency_keys WHERE key=$1`, key).
		Scan(&r.Status, &r.Body, &r.CreatedAt)
	if err != nil {
		return nil, false
	}
	return &r, true
}

// SaveIdempotent stores r under key only if absent (atomic check-and-set via
// INSERT ... ON CONFLICT DO NOTHING), returning the winning entry.
func (p *Postgres) SaveIdempotent(key string, r IdempotentResult) (IdempotentResult, bool) {
	r.CreatedAt = now(r.CreatedAt)
	res, err := p.db.Exec(
		`INSERT INTO idempotency_keys (key, status, body, created_at)
		 VALUES ($1,$2,$3,$4) ON CONFLICT (key) DO NOTHING`,
		key, r.Status, r.Body, r.CreatedAt)
	if err == nil {
		if n, _ := res.RowsAffected(); n == 1 {
			return r, false // we inserted it
		}
	}
	// Someone else won (or the insert errored): return the stored entry.
	if existing, ok := p.GetIdempotent(key); ok {
		return *existing, true
	}
	return r, false
}

// --- Subscriptions ---

func (p *Postgres) GetSubscription(userID string) (*domain.Subscription, error) {
	var s domain.Subscription
	var planID string
	err := p.db.QueryRow(
		`SELECT user_id, plan_id, status, started_at, renews_at
		 FROM subscriptions WHERE user_id=$1`, userID).
		Scan(&s.UserID, &planID, &s.Status, &s.StartedAt, &s.RenewsAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	s.PlanID = domain.PlanID(planID)
	return &s, nil
}

func (p *Postgres) SetSubscription(sub *domain.Subscription) error {
	_, err := p.db.Exec(`
		INSERT INTO subscriptions (user_id, plan_id, status, started_at, renews_at)
		VALUES ($1,$2,$3,$4,$5)
		ON CONFLICT (user_id) DO UPDATE SET
			plan_id=EXCLUDED.plan_id, status=EXCLUDED.status,
			started_at=EXCLUDED.started_at, renews_at=EXCLUDED.renews_at`,
		sub.UserID, string(sub.PlanID), sub.Status, now(sub.StartedAt), sub.RenewsAt)
	return err
}

// --- Credits ---

func (p *Postgres) Balance(userID string) (int, error) {
	var bal int
	err := p.db.QueryRow(
		`SELECT COALESCE(
			(SELECT balance FROM credit_transactions
			 WHERE user_id=$1 ORDER BY created_at DESC, id DESC LIMIT 1), 0)`,
		userID).Scan(&bal)
	return bal, err
}

// AddCredits appends a ledger entry with the running balance. The whole
// read-modify-write runs in a transaction that locks the user row, so
// concurrent credit changes for the same user serialize correctly.
func (p *Postgres) AddCredits(tx *domain.CreditTransaction) (*domain.CreditTransaction, error) {
	dbtx, err := p.db.Begin()
	if err != nil {
		return nil, err
	}
	defer dbtx.Rollback() //nolint:errcheck // no-op after Commit

	// Serialize per-user credit writes.
	_, _ = dbtx.Exec(`SELECT id FROM users WHERE id=$1 FOR UPDATE`, tx.UserID)

	var prev int
	if err := dbtx.QueryRow(
		`SELECT COALESCE(
			(SELECT balance FROM credit_transactions
			 WHERE user_id=$1 ORDER BY created_at DESC, id DESC LIMIT 1), 0)`,
		tx.UserID).Scan(&prev); err != nil {
		return nil, err
	}

	out := *tx
	out.Balance = prev + tx.Amount
	out.CreatedAt = now(tx.CreatedAt)
	if _, err := dbtx.Exec(`
		INSERT INTO credit_transactions (id, user_id, amount, reason, note, balance, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		out.ID, out.UserID, out.Amount, string(out.Reason), out.Note, out.Balance, out.CreatedAt,
	); err != nil {
		return nil, err
	}
	if err := dbtx.Commit(); err != nil {
		return nil, err
	}
	return &out, nil
}

func (p *Postgres) ensureWalletTx(dbtx *sql.Tx, userID string) (*domain.CreditWallet, error) {
	w := &domain.CreditWallet{UserID: userID}
	err := dbtx.QueryRow(`
		SELECT subscription_credits, addon_credits, sub_period_ends_at
		FROM credit_wallets WHERE user_id=$1 FOR UPDATE`, userID).
		Scan(&w.SubscriptionCredits, &w.AddonCredits, &w.SubPeriodEndsAt)
	if err == nil {
		return w, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}
	_, err = dbtx.Exec(`
		INSERT INTO credit_wallets (user_id, subscription_credits, addon_credits, sub_period_ends_at)
		SELECT $1, 0,
			COALESCE((SELECT balance FROM credit_transactions
			          WHERE user_id=$1 ORDER BY created_at DESC, id DESC LIMIT 1), 0),
			now() + interval '1 month'
		ON CONFLICT (user_id) DO NOTHING`, userID)
	if err != nil {
		return nil, err
	}
	err = dbtx.QueryRow(`
		SELECT subscription_credits, addon_credits, sub_period_ends_at
		FROM credit_wallets WHERE user_id=$1 FOR UPDATE`, userID).
		Scan(&w.SubscriptionCredits, &w.AddonCredits, &w.SubPeriodEndsAt)
	if err != nil {
		return nil, err
	}
	return w, nil
}

func (p *Postgres) GetWallet(userID string) (*domain.CreditWallet, error) {
	w := &domain.CreditWallet{UserID: userID}
	err := p.db.QueryRow(`
		SELECT subscription_credits, addon_credits, sub_period_ends_at
		FROM credit_wallets WHERE user_id=$1`, userID).
		Scan(&w.SubscriptionCredits, &w.AddonCredits, &w.SubPeriodEndsAt)
	if err == nil {
		return w, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}
	dbtx, err := p.db.Begin()
	if err != nil {
		return nil, err
	}
	defer dbtx.Rollback() //nolint:errcheck
	w, err = p.ensureWalletTx(dbtx, userID)
	if err != nil {
		return nil, err
	}
	if err := dbtx.Commit(); err != nil {
		return nil, err
	}
	return w, nil
}

func (p *Postgres) MutateWallet(userID string, fn func(*domain.CreditWallet) ([]*domain.CreditTransaction, error)) (*domain.CreditWallet, []*domain.CreditTransaction, error) {
	dbtx, err := p.db.Begin()
	if err != nil {
		return nil, nil, err
	}
	defer dbtx.Rollback() //nolint:errcheck

	var uid string
	if err := dbtx.QueryRow(`SELECT id FROM users WHERE id=$1 FOR UPDATE`, userID).Scan(&uid); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil, ErrNotFound
		}
		return nil, nil, err
	}

	w, err := p.ensureWalletTx(dbtx, userID)
	if err != nil {
		return nil, nil, err
	}
	txs, err := fn(w)
	if err != nil {
		return nil, nil, err
	}

	var prev int
	if err := dbtx.QueryRow(`
		SELECT COALESCE(
			(SELECT balance FROM credit_transactions
			 WHERE user_id=$1 ORDER BY created_at DESC, id DESC LIMIT 1), 0)`,
		userID).Scan(&prev); err != nil {
		return nil, nil, err
	}

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
		cp.CreatedAt = now(cp.CreatedAt)
		prev += cp.Amount
		cp.Balance = prev
		if _, err := dbtx.Exec(`
			INSERT INTO credit_transactions
				(id, user_id, amount, reason, note, balance, created_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			cp.ID, cp.UserID, cp.Amount, string(cp.Reason), cp.Note, cp.Balance, cp.CreatedAt); err != nil {
			return nil, nil, err
		}
		stored := cp
		out = append(out, &stored)
	}

	if _, err := dbtx.Exec(`
		UPDATE credit_wallets
		SET subscription_credits=$2, addon_credits=$3, sub_period_ends_at=$4
		WHERE user_id=$1`,
		userID, w.SubscriptionCredits, w.AddonCredits, now(w.SubPeriodEndsAt)); err != nil {
		return nil, nil, err
	}
	if err := dbtx.Commit(); err != nil {
		return nil, nil, err
	}
	ret := *w
	ret.UserID = userID
	return &ret, out, nil
}

const paymentCols = `id, user_id, user_email, user_name, item_id, kind, item_name, price_mmk,
	credits, plan_id, method, proof_upload_id, status, admin_note, created_at, reviewed_at, reviewed_by`

func scanPayment(row interface{ Scan(...any) error }) (*domain.PaymentOrder, error) {
	var p domain.PaymentOrder
	var kind, planID string
	var reviewed sql.NullTime
	if err := row.Scan(&p.ID, &p.UserID, &p.UserEmail, &p.UserName, &p.ItemID, &kind,
		&p.ItemName, &p.PriceMMK, &p.Credits, &planID, &p.Method, &p.ProofUploadID,
		&p.Status, &p.AdminNote, &p.CreatedAt, &reviewed, &p.ReviewedBy); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	p.Kind = domain.StoreItemKind(kind)
	p.PlanID = domain.PlanID(planID)
	if reviewed.Valid {
		t := reviewed.Time
		p.ReviewedAt = &t
	}
	return &p, nil
}

func (p *Postgres) CreatePayment(order *domain.PaymentOrder) error {
	_, err := p.db.Exec(`
		INSERT INTO payment_orders (
			id, user_id, user_email, user_name, item_id, kind, item_name, price_mmk,
			credits, plan_id, method, proof_upload_id, status, admin_note, created_at,
			reviewed_at, reviewed_by)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
		order.ID, order.UserID, order.UserEmail, order.UserName, order.ItemID,
		string(order.Kind), order.ItemName, order.PriceMMK, order.Credits,
		string(order.PlanID), order.Method, order.ProofUploadID, order.Status,
		order.AdminNote, now(order.CreatedAt), nullableTime(order.ReviewedAt),
		order.ReviewedBy)
	return err
}

func (p *Postgres) GetPayment(id string) (*domain.PaymentOrder, error) {
	return scanPayment(p.db.QueryRow(`SELECT `+paymentCols+` FROM payment_orders WHERE id=$1`, id))
}

func (p *Postgres) ListPayments(status string) ([]*domain.PaymentOrder, error) {
	var (
		rows *sql.Rows
		err  error
	)
	if status == "" {
		rows, err = p.db.Query(`SELECT ` + paymentCols + ` FROM payment_orders ORDER BY created_at DESC, id DESC`)
	} else {
		rows, err = p.db.Query(`SELECT `+paymentCols+` FROM payment_orders WHERE status=$1 ORDER BY created_at DESC, id DESC`, status)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*domain.PaymentOrder
	for rows.Next() {
		order, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, order)
	}
	return out, rows.Err()
}

func (p *Postgres) UpdatePayment(order *domain.PaymentOrder) error {
	res, err := p.db.Exec(`
		UPDATE payment_orders SET
			status=$2, admin_note=$3, reviewed_at=$4, reviewed_by=$5
		WHERE id=$1`,
		order.ID, order.Status, order.AdminNote, nullableTime(order.ReviewedAt), order.ReviewedBy)
	if err != nil {
		return err
	}
	return mustAffect(res)
}

func nullableTime(t *time.Time) any {
	if t == nil {
		return nil
	}
	return *t
}

func (p *Postgres) ListCredits(userID string) ([]*domain.CreditTransaction, error) {
	rows, err := p.db.Query(`
		SELECT id, user_id, amount, reason, note, balance, created_at
		FROM credit_transactions WHERE user_id=$1
		ORDER BY created_at ASC, id ASC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*domain.CreditTransaction
	for rows.Next() {
		var t domain.CreditTransaction
		var reason string
		if err := rows.Scan(&t.ID, &t.UserID, &t.Amount, &reason, &t.Note,
			&t.Balance, &t.CreatedAt); err != nil {
			return nil, err
		}
		t.Reason = domain.CreditReason(reason)
		out = append(out, &t)
	}
	return out, rows.Err()
}

// --- Notifications ---

func (p *Postgres) CreateNotification(n *domain.Notification) error {
	_, err := p.db.Exec(`
		INSERT INTO notifications (id, user_id, title, body, read, created_at)
		VALUES ($1,$2,$3,$4,$5,$6)`,
		n.ID, n.UserID, n.Title, n.Body, n.Read, now(n.CreatedAt))
	return err
}

func (p *Postgres) ListNotifications(userID string) ([]*domain.Notification, error) {
	rows, err := p.db.Query(`
		SELECT id, user_id, title, body, read, created_at
		FROM notifications WHERE user_id=$1
		ORDER BY created_at DESC, id DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*domain.Notification
	for rows.Next() {
		var n domain.Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Title, &n.Body, &n.Read, &n.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, &n)
	}
	return out, rows.Err()
}

func (p *Postgres) MarkNotificationRead(userID, id string) error {
	res, err := p.db.Exec(
		`UPDATE notifications SET read=true WHERE id=$1 AND user_id=$2`, id, userID)
	if err != nil {
		return err
	}
	return mustAffect(res)
}

// --- Uploads ---

func (p *Postgres) SaveUpload(u *Upload) error {
	_, err := p.db.Exec(`
		INSERT INTO uploads (id, user_id, content_type, data, created_at)
		VALUES ($1,$2,$3,$4,$5)`,
		u.ID, u.UserID, u.ContentType, u.Data, now(u.CreatedAt))
	return err
}

func (p *Postgres) GetUpload(id string) (*Upload, error) {
	var u Upload
	err := p.db.QueryRow(
		`SELECT id, user_id, content_type, data, created_at FROM uploads WHERE id=$1`, id).
		Scan(&u.ID, &u.UserID, &u.ContentType, &u.Data, &u.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// --- Catalog ---

func (p *Postgres) ListPlans() ([]domain.Plan, error) {
	rows, err := p.db.Query(`
		SELECT id, name, price_mmk, monthly_credits, description
		FROM catalog_plans ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Plan
	for rows.Next() {
		var pl domain.Plan
		var id string
		if err := rows.Scan(&id, &pl.Name, &pl.PriceMMK, &pl.MonthlyCredits, &pl.Description); err != nil {
			return nil, err
		}
		pl.ID = domain.PlanID(id)
		out = append(out, pl)
	}
	return out, rows.Err()
}

func (p *Postgres) GetPlan(id domain.PlanID) (domain.Plan, error) {
	var pl domain.Plan
	var raw string
	err := p.db.QueryRow(`
		SELECT id, name, price_mmk, monthly_credits, description
		FROM catalog_plans WHERE id=$1`, string(id)).
		Scan(&raw, &pl.Name, &pl.PriceMMK, &pl.MonthlyCredits, &pl.Description)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.Plan{}, ErrNotFound
	}
	if err != nil {
		return domain.Plan{}, err
	}
	pl.ID = domain.PlanID(raw)
	return pl, nil
}

func (p *Postgres) UpsertPlan(pl domain.Plan) error {
	_, err := p.db.Exec(`
		INSERT INTO catalog_plans (id, name, price_mmk, monthly_credits, description)
		VALUES ($1,$2,$3,$4,$5)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			price_mmk = EXCLUDED.price_mmk,
			monthly_credits = EXCLUDED.monthly_credits,
			description = EXCLUDED.description`,
		string(pl.ID), pl.Name, pl.PriceMMK, pl.MonthlyCredits, pl.Description)
	return err
}

func (p *Postgres) ListStoreItems() ([]domain.StoreItem, error) {
	rows, err := p.db.Query(`
		SELECT id, kind, name, price_mmk, credits, plan_id, sort_order
		FROM catalog_items ORDER BY sort_order, id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.StoreItem
	for rows.Next() {
		var it domain.StoreItem
		var kind, planID string
		if err := rows.Scan(&it.ID, &kind, &it.Name, &it.PriceMMK, &it.Credits, &planID, &it.SortOrder); err != nil {
			return nil, err
		}
		it.Kind = domain.StoreItemKind(kind)
		it.PlanID = domain.PlanID(planID)
		out = append(out, it)
	}
	return out, rows.Err()
}

func (p *Postgres) GetStoreItem(id string) (domain.StoreItem, error) {
	var it domain.StoreItem
	var kind, planID string
	err := p.db.QueryRow(`
		SELECT id, kind, name, price_mmk, credits, plan_id, sort_order
		FROM catalog_items WHERE id=$1`, id).
		Scan(&it.ID, &kind, &it.Name, &it.PriceMMK, &it.Credits, &planID, &it.SortOrder)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.StoreItem{}, ErrNotFound
	}
	if err != nil {
		return domain.StoreItem{}, err
	}
	it.Kind = domain.StoreItemKind(kind)
	it.PlanID = domain.PlanID(planID)
	return it, nil
}

func (p *Postgres) UpsertStoreItem(it domain.StoreItem) error {
	_, err := p.db.Exec(`
		INSERT INTO catalog_items (id, kind, name, price_mmk, credits, plan_id, sort_order)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		ON CONFLICT (id) DO UPDATE SET
			kind = EXCLUDED.kind,
			name = EXCLUDED.name,
			price_mmk = EXCLUDED.price_mmk,
			credits = EXCLUDED.credits,
			plan_id = EXCLUDED.plan_id,
			sort_order = EXCLUDED.sort_order`,
		it.ID, string(it.Kind), it.Name, it.PriceMMK, it.Credits, string(it.PlanID), it.SortOrder)
	return err
}

func (p *Postgres) DeleteStoreItem(id string) error {
	res, err := p.db.Exec(`DELETE FROM catalog_items WHERE id=$1`, id)
	if err != nil {
		return err
	}
	return mustAffect(res)
}

// --- helpers ---

func mustAffect(res sql.Result) error {
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// isUniqueViolation reports whether err is a Postgres unique-constraint error
// (SQLSTATE 23505). Checked without importing the driver: the pgx error
// exposes SQLState() via a small interface.
func isUniqueViolation(err error) bool {
	var se interface{ SQLState() string }
	if errors.As(err, &se) {
		return se.SQLState() == "23505"
	}
	return false
}
