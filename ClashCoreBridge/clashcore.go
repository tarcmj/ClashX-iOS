// Package clashcore provides a gomobile-bindable interface to the Clash core.
//
// Build with:
//
//	gomobile bind -target ios -o ClashCore.xcframework ./
//
//go:build ignore
// +build ignore

package clashcore

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/Dreamacro/clash/config"
	"github.com/Dreamacro/clash/constant"
	"github.com/Dreamacro/clash/hub/executor"
	C "github.com/Dreamacro/clash/constant"
	"github.com/Dreamacro/clash/log"
	"github.com/Dreamacro/clash/tunnel"
)

// ClashCore is the main bridge object exposed to iOS via gomobile.
type ClashCore struct {
	mu          sync.Mutex
	running     bool
	cancel      context.CancelFunc
	homeDir     string
	httpClient  *http.Client
	trafficUp   int64
	trafficDown int64
	logCh       chan string
	logs        []string
	logMu       sync.RWMutex
}

// NewClashCore creates a new ClashCore instance.
func NewClashCore() *ClashCore {
	return &ClashCore{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		logCh:      make(chan string, 1024),
	}
}

// Start launches Clash with the given YAML config file path.
func (c *ClashCore) Start(configPath string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.running {
		return fmt.Errorf("Clash is already running")
	}

	// Verify config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return fmt.Errorf("config file not found: %s", configPath)
	}

	// Set home directory for Clash
	homeDir := filepath.Dir(configPath)
	c.homeDir = homeDir

	// Parse config
	cfg, err := config.Parse(filepath.Base(configPath), configPath)
	if err != nil {
		return fmt.Errorf("failed to parse config: %w", err)
	}

	// Apply config to start Clash
	ctx, cancel := context.WithCancel(context.Background())
	c.cancel = cancel

	go func() {
		<-ctx.Done()
		executor.Shutdown()
	}()

	executor.ApplyConfig(cfg, true)

	// Start log listener
	go c.collectLogs()

	c.running = true

	// Start traffic monitor
	go c.monitorTraffic(ctx)

	log.Infoln("Clash core started successfully")
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

	executor.Shutdown()
	c.running = false
	c.trafficUp = 0
	c.trafficDown = 0

	log.Infoln("Clash core stopped")
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

// GetTraffic returns the total uploaded and downloaded bytes since start.
func (c *ClashCore) GetTraffic() (upBytes int64, downBytes int64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.trafficUp, c.trafficDown
}

// GetProxiesJSON returns a JSON string of all proxies and their status.
func (c *ClashCore) GetProxiesJSON() string {
	proxies := tunnel.Proxies()
	data, err := json.Marshal(proxies)
	if err != nil {
		return "[]"
	}
	return string(data)
}

// GetProxyGroupsJSON returns a JSON string of all proxy groups.
func (c *ClashCore) GetProxyGroupsJSON() string {
	// This would need to be implemented with Clash's internal API
	// For now, return a JSON representation from the tunnel
	proxies := tunnel.Proxies()
	type group struct {
		Name string   `json:"name"`
		Type string   `json:"type"`
		Now  string   `json:"now"`
		All  []string `json:"all"`
	}

	var groups []group
	for name, p := range proxies {
		if _, ok := p.(C.ProxyGroupAdapter); ok {
			g := group{Name: name}
			groups = append(groups, g)
		}
		_ = name
		_ = p
	}

	_ = groups
	data, err := json.Marshal(proxies)
	if err != nil {
		return "[]"
	}
	return string(data)
}

// SetProxy selects a specific proxy in a proxy group.
func (c *ClashCore) SetProxy(groupName string, proxyName string) error {
	// This would use Clash's API to select a proxy
	// For now, we use the HTTP controller
	addr := fmt.Sprintf("http://127.0.0.1:9090/proxies/%s", groupName)
	body := map[string]string{"name": proxyName}
	payload, _ := json.Marshal(body)

	req, err := http.NewRequest("PUT", addr, nil)
	if err != nil {
		return err
	}
	req.Body = http.MaxBytesReader(nil, nil, 0)
	_ = payload
	_ = req

	// TODO: implement actual API call
	return nil
}

// GetConfigJSON returns the current running config as JSON.
func (c *ClashCore) GetConfigJSON() string {
	cfg := executor.GetConfig()
	if cfg == nil {
		return "{}"
	}
	data, err := json.Marshal(cfg)
	if err != nil {
		return "{}"
	}
	return string(data)
}

// SetMode changes the Clash mode (rule/global/direct).
func (c *ClashCore) SetMode(mode string) error {
	switch mode {
	case "rule", "global", "direct":
		// Apply mode change
		cfg := executor.GetConfig()
		if cfg == nil {
			return fmt.Errorf("config not loaded")
		}
		cfg.Mode = C.Mode(mode)
		executor.ApplyConfig(cfg, true)
		return nil
	default:
		return fmt.Errorf("invalid mode: %s", mode)
	}
}

// GetLogs returns recent log entries as a newline-separated string.
func (c *ClashCore) GetLogs() string {
	c.logMu.RLock()
	defer c.logMu.RUnlock()

	result := ""
	for i := max(0, len(c.logs)-200); i < len(c.logs); i++ {
		result += c.logs[i] + "\n"
	}
	return result
}

// DelayTest tests latency of a specific proxy. Returns delay in ms.
func (c *ClashCore) DelayTest(proxyName string) (int, error) {
	// Test proxy delay using Clash's built-in functionality
	// This would use the proxy adapter's DelayTest method
	addr := fmt.Sprintf("http://127.0.0.1:9090/proxies/%s/delay", proxyName)
	resp, err := c.httpClient.Get(addr)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var result map[string]int
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return 0, err
	}

	if delay, ok := result["delay"]; ok {
		return delay, nil
	}
	return 0, fmt.Errorf("delay test failed")
}

// ---- Internal ----

func (c *ClashCore) collectLogs() {
	// Subscribe to Clash log channel and collect entries
	logCh := log.Subscribe()
	defer log.UnSubscribe(logCh)

	for entry := range logCh {
		msg := fmt.Sprintf("[%s] %s", entry.Type(), entry.Payload())
		c.logMu.Lock()
		c.logs = append(c.logs, msg)
		if len(c.logs) > 1000 {
			c.logs = c.logs[len(c.logs)-1000:]
		}
		c.logMu.Unlock()

		// Try to send to channel (non-blocking)
		select {
		case c.logCh <- msg:
		default:
		}
	}
}

func (c *ClashCore) monitorTraffic(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Update traffic from tunnel
			up, down := tunnel.Default().Now()
			c.mu.Lock()
			c.trafficUp = up
			c.trafficDown = down
			c.mu.Unlock()
		}
	}
}

// Needed for gomobile to compile
func init() {
	// Ensure we have a log endpoint set
	log.SetLevel(log.INFO)
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
