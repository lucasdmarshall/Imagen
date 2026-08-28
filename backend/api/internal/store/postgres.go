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
		INSERT INTO users (id, email, password_hash, role, display_name, locale, avatar_url, approved, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
		u.ID, u.Email, u.PasswordHash, string(u.Role),
		u.Profile.DisplayName, u.Profile.Locale, u.Profile.AvatarURL,
		u.Approved, now(u.CreatedAt))
	if err != nil {
		if isUniqueViolation(err) {
			return ErrEmailTaken
		}
		return err
	}
	return nil
}

const userCols = `id, email, password_hash, role, display_name, locale, avatar_url, approved, created_at`

func scanUser(row interface{ Scan(...any) error }) (*domain.User, error) {
	var u domain.User
	var role string
	if err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &role,
		&u.Profile.DisplayName, &u.Profile.Locale, &u.Profile.AvatarURL,
		&u.Approved, &u.CreatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	u.Role = domain.Role(role)
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
			display_name=$5, locale=$6, avatar_url=$7, approved=$8
		WHERE id=$1`,
		u.ID, u.Email, u.PasswordHash, string(u.Role),
		u.Profile.DisplayName, u.Profile.Locale, u.Profile.AvatarURL, u.Approved)
	if err != nil {
		return err
	}
	return mustAffect(res)
}

func (p *Postgres) ListUsers() ([]*domain.User, error) {
	rows, err := p.db.Query(`SELECT ` + userCols + ` FROM users ORDER BY created_at ASC`)
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
