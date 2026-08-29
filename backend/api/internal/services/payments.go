package services

import (
	"fmt"
	"strings"
	"time"

	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/payments"
	"github.com/show/api/internal/store"
)

// PaymentsService handles manual-transfer proof → admin review → credit grant.
type PaymentsService struct {
	store   store.Store
	credits *CreditsService
	subs    *SubscriptionService
	notify  *NotificationsService
	hub     *AdminHub
	catalog *CatalogService
}

func methodOK(id string) bool {
	for _, m := range payments.Methods() {
		if m.ID == id {
			return true
		}
	}
	return false
}

// SubmitProof records a pending store purchase. No proof image is required.
func (p *PaymentsService) SubmitProof(user *domain.User, itemID, method, proofUploadID string) (*domain.PaymentOrder, error) {
	itemID = strings.TrimSpace(itemID)
	method = strings.TrimSpace(method)
	if itemID == "" || method == "" {
		return nil, fmt.Errorf("%w: itemId and method are required", ErrBadRequest)
	}
	item, ok := p.catalog.Item(itemID)
	if !ok {
		return nil, fmt.Errorf("%w: unknown store item", ErrBadRequest)
	}
	if !methodOK(method) {
		return nil, fmt.Errorf("%w: unknown payment method", ErrBadRequest)
	}

	order := &domain.PaymentOrder{
		ID:            newID(),
		UserID:        user.ID,
		UserEmail:     user.Email,
		UserName:      user.Profile.DisplayName,
		ItemID:        item.ID,
		Kind:          item.Kind,
		ItemName:      item.Name,
		PriceMMK:      item.PriceMMK,
		Credits:       item.Credits,
		PlanID:        item.PlanID,
		Method:        method,
		ProofUploadID: strings.TrimSpace(proofUploadID),
		Status:        domain.PaymentPending,
		CreatedAt:     time.Now().UTC(),
	}
	if err := p.store.CreatePayment(order); err != nil {
		return nil, err
	}
	p.hub.Publish(TopicPayments)
	return order, nil
}

func (p *PaymentsService) List(status string) ([]*domain.PaymentOrder, error) {
	return p.store.ListPayments(strings.TrimSpace(status))
}

func (p *PaymentsService) Approve(adminID, paymentID string) (*domain.PaymentOrder, error) {
	order, err := p.store.GetPayment(paymentID)
	if err != nil {
		return nil, err
	}
	if order.Status != domain.PaymentPending {
		return nil, fmt.Errorf("%w: payment already %s", ErrConflict, order.Status)
	}

	switch order.Kind {
	case domain.ItemSubscription:
		if order.PlanID == "" {
			return nil, fmt.Errorf("%w: subscription item missing planId", ErrBadRequest)
		}
		if err := p.subs.SetPlan(order.UserID, order.PlanID); err != nil {
			return nil, err
		}
	case domain.ItemCreditPack:
		if order.Credits <= 0 {
			return nil, fmt.Errorf("%w: credit pack missing credits", ErrBadRequest)
		}
		if _, err := p.credits.Purchase(order.UserID, order.Credits, "Add-on: "+order.ItemName); err != nil {
			return nil, err
		}
	default:
		return nil, fmt.Errorf("%w: unknown item kind", ErrBadRequest)
	}

	now := time.Now().UTC()
	order.Status = domain.PaymentApproved
	order.ReviewedAt = &now
	order.ReviewedBy = adminID
	if err := p.store.UpdatePayment(order); err != nil {
		return nil, err
	}
	_, _ = p.notify.Notify(order.UserID, "Payment approved",
		order.ItemName+" is now active on your account.")
	p.hub.Publish(TopicPayments)
	return order, nil
}

func (p *PaymentsService) Reject(adminID, paymentID, note string) (*domain.PaymentOrder, error) {
	order, err := p.store.GetPayment(paymentID)
	if err != nil {
		return nil, err
	}
	if order.Status != domain.PaymentPending {
		return nil, fmt.Errorf("%w: payment already %s", ErrConflict, order.Status)
	}
	now := time.Now().UTC()
	order.Status = domain.PaymentRejected
	order.AdminNote = strings.TrimSpace(note)
	order.ReviewedAt = &now
	order.ReviewedBy = adminID
	if err := p.store.UpdatePayment(order); err != nil {
		return nil, err
	}
	body := order.ItemName + " was not approved."
	if order.AdminNote != "" {
		body += " " + order.AdminNote
	}
	_, _ = p.notify.Notify(order.UserID, "Payment not approved", body)
	p.hub.Publish(TopicPayments)
	return order, nil
}
