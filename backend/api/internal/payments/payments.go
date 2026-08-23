// Package payments describes SHOW's supported payment methods.
//
// Myanmar mobile-wallet flow (AYA Pay, KBZ Pay): the buyer transfers to the
// receiver's wallet number / QR, then submits proof. These are the receiver
// (payee) details shown to the buyer at checkout. Values here are PLACEHOLDERS
// — replace ReceiverPhone and QRImageURL with the real account before launch.
package payments

// Method is a single supported wallet.
type Method struct {
	ID            string `json:"id"`
	Name          string `json:"name"`          // Display name.
	ReceiverName  string `json:"receiverName"`  // ငွေလက်ခံ Name.
	ReceiverPhone string `json:"receiverPhone"` // ငွေလက်ခံ နံပါတ်.
	QRImageURL    string `json:"qrImageUrl"`    // Payee QR image.
}

// Methods returns the configured payee methods.
//
// TODO(payments): source these from config/DB and set real values.
func Methods() []Method {
	const (
		receiverName = "U Kyaw Win"
		receiverPhone = "09........" // placeholder
	)
	return []Method{
		{
			ID:            "aya_pay",
			Name:          "AYA Pay",
			ReceiverName:  receiverName,
			ReceiverPhone: receiverPhone,
			QRImageURL:    "/static/payments/aya_pay_qr_placeholder.png",
		},
		{
			ID:            "kbz_pay",
			Name:          "KBZ Pay",
			ReceiverName:  receiverName,
			ReceiverPhone: receiverPhone,
			QRImageURL:    "/static/payments/kbz_pay_qr_placeholder.png",
		},
	}
}
