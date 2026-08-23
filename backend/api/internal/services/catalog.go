package services

import "github.com/show/api/internal/domain"

// Credit costs per AI operation. Tune as needed.
const (
	CostPromptGenerate = 1
	CostImageGenerate  = 5
)

// plans is the static subscription catalog (prices in MMK / Kyat).
var plans = []domain.Plan{
	{ID: domain.PlanFree, Name: "Free", PriceMMK: 0, MonthlyCredits: 20,
		Description: "Get started with 20 credits each month."},
	{ID: domain.PlanProMonthly, Name: "Pro — Monthly", PriceMMK: 9900, MonthlyCredits: 500,
		Description: "500 credits every month."},
	{ID: domain.PlanProYearly, Name: "Pro — Yearly", PriceMMK: 99000, MonthlyCredits: 500,
		Description: "500 credits every month, best value yearly."},
}

// storeItems lists purchasable products: subscriptions + add-on credit packs.
var storeItems = []domain.StoreItem{
	// Subscriptions
	{ID: "sub_pro_monthly", Kind: domain.ItemSubscription, Name: "Pro — Monthly",
		PriceMMK: 9900, PlanID: domain.PlanProMonthly},
	{ID: "sub_pro_yearly", Kind: domain.ItemSubscription, Name: "Pro — Yearly",
		PriceMMK: 99000, PlanID: domain.PlanProYearly},
	// Add-on credit packs
	{ID: "credits_100", Kind: domain.ItemCreditPack, Name: "100 Credits", PriceMMK: 2500, Credits: 100},
	{ID: "credits_300", Kind: domain.ItemCreditPack, Name: "300 Credits", PriceMMK: 6500, Credits: 300},
	{ID: "credits_1000", Kind: domain.ItemCreditPack, Name: "1000 Credits", PriceMMK: 19000, Credits: 1000},
}

// CatalogService exposes the static plan & store catalog.
type CatalogService struct{}

func (CatalogService) Plans() []domain.Plan          { return plans }
func (CatalogService) StoreItems() []domain.StoreItem { return storeItems }

func planByID(id domain.PlanID) (domain.Plan, bool) {
	for _, p := range plans {
		if p.ID == id {
			return p, true
		}
	}
	return domain.Plan{}, false
}
