package services

import "sync"

// AdminHub fans out live events to connected admin SSE clients.
type AdminHub struct {
	mu   sync.Mutex
	subs map[chan string]struct{}
}

func NewAdminHub() *AdminHub {
	return &AdminHub{subs: map[chan string]struct{}{}}
}

const (
	TopicUsers    = "users"
	TopicPayments = "payments"
	TopicCatalog  = "catalog"
)

// Subscribe returns a buffered channel of topic names. Call the returned
// function to unsubscribe (it also closes the channel).
func (h *AdminHub) Subscribe() (<-chan string, func()) {
	if h == nil {
		ch := make(chan string)
		close(ch)
		return ch, func() {}
	}
	ch := make(chan string, 16)
	h.mu.Lock()
	h.subs[ch] = struct{}{}
	h.mu.Unlock()
	return ch, func() {
		h.mu.Lock()
		delete(h.subs, ch)
		h.mu.Unlock()
		close(ch)
	}
}

func (h *AdminHub) Publish(topic string) {
	if h == nil {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	for ch := range h.subs {
		select {
		case ch <- topic:
		default:
		}
	}
}
