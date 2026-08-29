package services

import (
	"errors"
	"fmt"
	"strings"

	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/store"
)

// Credit costs per AI operation. Tune as needed.
const (
	CostPromptGenerate = 1
	CostImageGenerate  = 5
)

var defaultPlans = []domain.Plan{
	{ID: domain.PlanFree, Name: "Free", PriceMMK: 0, MonthlyCredits: 20,
		Description: "Get started with 20 credits each month."},
	{ID: domain.PlanProMonthly, Name: "Pro — Monthly", PriceMMK: 9900, MonthlyCredits: 500,
		Description: "500 credits every month."},
	{ID: domain.PlanProYearly, Name: "Pro — Yearly", PriceMMK: 99000, MonthlyCredits: 500,
		Description: "500 credits every month, best value yearly."},
}

var defaultStoreItems = []domain.StoreItem{
	{ID: "sub_pro_monthly", Kind: domain.ItemSubscription, Name: "Pro — Monthly",
		PriceMMK: 9900, Credits: 500, PlanID: domain.PlanProMonthly, SortOrder: 1},
	{ID: "sub_pro_yearly", Kind: domain.ItemSubscription, Name: "Pro — Yearly",
		PriceMMK: 99000, Credits: 500, PlanID: domain.PlanProYearly, SortOrder: 2},
	{ID: "credits_100", Kind: domain.ItemCreditPack, Name: "100 Credits",
		PriceMMK: 2500, Credits: 100, SortOrder: 10},
	{ID: "credits_300", Kind: domain.ItemCreditPack, Name: "300 Credits",
		PriceMMK: 6500, Credits: 300, SortOrder: 11},
	{ID: "credits_1000", Kind: domain.ItemCreditPack, Name: "1000 Credits",
		PriceMMK: 19000, Credits: 1000, SortOrder: 12},
}

// CatalogService is the admin-editable plan & store catalog.
type CatalogService struct {
	store store.Store
	hub   *AdminHub
}

func (c *CatalogService) EnsureDefaults() error {
	for _, p := range defaultPlans {
		if _, err := c.store.GetPlan(p.ID); errors.Is(err, store.ErrNotFound) {
			if err := c.store.UpsertPlan(p); err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
	}
	for _, it := range defaultStoreItems {
		if _, err := c.store.GetStoreItem(it.ID); errors.Is(err, store.ErrNotFound) {
			if err := c.store.UpsertStoreItem(it); err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
	}
	return nil
}

func (c *CatalogService) Plans() ([]domain.Plan, error) {
	return c.store.ListPlans()
}

func (c *CatalogService) StoreItems() ([]domain.StoreItem, error) {
	return c.store.ListStoreItems()
}

func (c *CatalogService) Plan(id domain.PlanID) (domain.Plan, bool) {
	p, err := c.store.GetPlan(id)
	if err != nil {
		return domain.Plan{}, false
	}
	return p, true
}

func (c *CatalogService) Item(id string) (domain.StoreItem, bool) {
	it, err := c.store.GetStoreItem(id)
	if err != nil {
		return domain.StoreItem{}, false
	}
	return it, true
}

// UpdatePlan changes a plan's price and/or monthly credits. Paid plans also
// sync the matching store SKU so the client store stays consistent.
func (c *CatalogService) UpdatePlan(id domain.PlanID, priceMMK, monthlyCredits *int) (domain.Plan, error) {
	p, err := c.store.GetPlan(id)
	if err != nil {
		return domain.Plan{}, err
	}
	if priceMMK != nil {
		if *priceMMK < 0 {
			return domain.Plan{}, fmt.Errorf("%w: priceMmk must be >= 0", ErrBadRequest)
		}
		if id == domain.PlanFree && *priceMMK != 0 {
			return domain.Plan{}, fmt.Errorf("%w: free plan price is always 0", ErrBadRequest)
		}
		p.PriceMMK = *priceMMK
	}
	if monthlyCredits != nil {
		if *monthlyCredits < 0 {
			return domain.Plan{}, fmt.Errorf("%w: monthlyCredits must be >= 0", ErrBadRequest)
		}
		p.MonthlyCredits = *monthlyCredits
	}
	p.Description = planDescription(p)
	if err := c.store.UpsertPlan(p); err != nil {
		return domain.Plan{}, err
	}
	if id != domain.PlanFree {
		if err := c.syncSubItem(p); err != nil {
			return domain.Plan{}, err
		}
	}
	c.hub.Publish(TopicCatalog)
	return p, nil
}

func (c *CatalogService) syncSubItem(p domain.Plan) error {
	items, err := c.store.ListStoreItems()
	if err != nil {
		return err
	}
	for _, it := range items {
		if it.Kind != domain.ItemSubscription || it.PlanID != p.ID {
			continue
		}
		it.PriceMMK = p.PriceMMK
		it.Credits = p.MonthlyCredits
		it.Name = p.Name
		return c.store.UpsertStoreItem(it)
	}
	return nil
}

func planDescription(p domain.Plan) string {
	if p.ID == domain.PlanFree {
		return fmt.Sprintf("Get started with %d credits each month.", p.MonthlyCredits)
	}
	if p.ID == domain.PlanProYearly {
		return fmt.Sprintf("%d credits every month, best value yearly.", p.MonthlyCredits)
	}
	return fmt.Sprintf("%d credits every month.", p.MonthlyCredits)
}

// UpdatePack changes an add-on pack's credit amount and/or price.
func (c *CatalogService) UpdatePack(id string, priceMMK, credits *int) (domain.StoreItem, error) {
	it, err := c.store.GetStoreItem(id)
	if err != nil {
		return domain.StoreItem{}, err
	}
	if it.Kind != domain.ItemCreditPack {
		return domain.StoreItem{}, fmt.Errorf("%w: not a credit pack", ErrBadRequest)
	}
	if priceMMK != nil {
		if *priceMMK < 0 {
			return domain.StoreItem{}, fmt.Errorf("%w: priceMmk must be >= 0", ErrBadRequest)
		}
		it.PriceMMK = *priceMMK
	}
	if credits != nil {
		if *credits <= 0 {
			return domain.StoreItem{}, fmt.Errorf("%w: credits must be > 0", ErrBadRequest)
		}
		it.Credits = *credits
		it.Name = fmt.Sprintf("%d Credits", *credits)
	}
	if err := c.store.UpsertStoreItem(it); err != nil {
		return domain.StoreItem{}, err
	}
	c.hub.Publish(TopicCatalog)
	return it, nil
}

// AddPack creates a new add-on credit SKU.
func (c *CatalogService) AddPack(credits, priceMMK int) (domain.StoreItem, error) {
	if credits <= 0 {
		return domain.StoreItem{}, fmt.Errorf("%w: credits must be > 0", ErrBadRequest)
	}
	if priceMMK < 0 {
		return domain.StoreItem{}, fmt.Errorf("%w: priceMmk must be >= 0", ErrBadRequest)
	}
	items, err := c.store.ListStoreItems()
	if err != nil {
		return domain.StoreItem{}, err
	}
	id := fmt.Sprintf("credits_%d", credits)
	maxSort := 12
	taken := map[string]bool{}
	for _, it := range items {
		taken[it.ID] = true
		if it.SortOrder > maxSort {
			maxSort = it.SortOrder
		}
	}
	if taken[id] {
		id = "credits_" + newID()[:8]
	}
	it := domain.StoreItem{
		ID:        id,
		Kind:      domain.ItemCreditPack,
		Name:      fmt.Sprintf("%d Credits", credits),
		PriceMMK:  priceMMK,
		Credits:   credits,
		SortOrder: maxSort + 1,
	}
	if err := c.store.UpsertStoreItem(it); err != nil {
		return domain.StoreItem{}, err
	}
	c.hub.Publish(TopicCatalog)
	return it, nil
}

// RemovePack deletes an add-on SKU. Built-in packs cannot be removed.
func (c *CatalogService) RemovePack(id string) error {
	id = strings.TrimSpace(id)
	it, err := c.store.GetStoreItem(id)
	if err != nil {
		return err
	}
	if it.Kind != domain.ItemCreditPack {
		return fmt.Errorf("%w: not a credit pack", ErrBadRequest)
	}
	for _, d := range defaultStoreItems {
		if d.ID == id {
			return fmt.Errorf("%w: cannot delete a built-in pack (edit it instead)", ErrBadRequest)
		}
	}
	if err := c.store.DeleteStoreItem(id); err != nil {
		return err
	}
	c.hub.Publish(TopicCatalog)
	return nil
}
