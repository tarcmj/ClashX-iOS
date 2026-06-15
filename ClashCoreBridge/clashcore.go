// Package clashcore provides a gomobile-bindable interface to the Clash core.
//
// Build with:
//
//	gomobile bind -target ios -o ClashCore.xcframework ./
package clashcore

import (
	"context"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/Dreamacro/clash/config"
	"github.com/Dreamacro/clash/constant"
	"github.com/Dreamacro/clash/hub/executor"
)

// ClashCore is the main bridge object exposed to iOS via gomobile.
type ClashCore struct {
	mu          sync.Mutex
	running     bool
	cancel      context.CancelFunc
	httpClient  *http.Client
	trafficUp   int64
	trafficDown int64
	logs        []string
	logMu       sync.RWMutex
}

// NewClashCore creates a new ClashCore instance.
func NewClashCore() *ClashCore {
	return &ClashCore{
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

// Start launches Clash with the given YAML config file path.
func (c *ClashCore) Start(configPath string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.running {
		return nil
	}

	// Read and parse config file
	data, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}

	_ = filepath.Dir(configPath)

	cfg, err := config.Parse(data)
	if err != nil {
		return err
	}

	// Apply config to start Clash
	executor.ApplyConfig(cfg, true)

	ctx, cancel := context.WithCancel(context.Background())
	c.cancel = cancel
	c.running = true

	go c.collectLogs(ctx)

	return nil
}

// Stop shuts down the Clash core.
func (c *ClashCore) Stop() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.running {
		return nil
	}

	if c.cancel != nil {
		c.cancel()
	}

	c.running = false
	c.trafficUp = 0
	c.trafficDown = 0

	return nil
}

// IsRunning returns whether Clash is currently active.
func (c *ClashCore) IsRunning() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.running
}

// GetVersion returns the Clash core version.
func (c *ClashCore) GetVersion() string {
	return constant.Version
}

// GetUploadTraffic returns the total uploaded bytes since start.
func (c *ClashCore) GetUploadTraffic() int64 {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.trafficUp
}

// GetDownloadTraffic returns the total downloaded bytes since start.
func (c *ClashCore) GetDownloadTraffic() int64 {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.trafficDown
}

// GetLogs returns recent log entries as a newline-separated string.
func (c *ClashCore) GetLogs() string {
	c.logMu.RLock()
	defer c.logMu.RUnlock()

	result := ""
	start := 0
	if len(c.logs) > 200 {
		start = len(c.logs) - 200
	}
	for i := start; i < len(c.logs); i++ {
		result += c.logs[i] + "\n"
	}
	return result
}

// ---- Internal ----

func (c *ClashCore) collectLogs(ctx context.Context) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Log collection placeholder
		}
	}
}
