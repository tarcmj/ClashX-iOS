// Package clashcore provides a gomobile-bindable interface to the Clash core.
//
// Build with:
//
//	gomobile bind -target ios -o ClashCore.xcframework ./
package clashcore

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/Dreamacro/clash/config"
	"github.com/Dreamacro/clash/constant"
	"github.com/Dreamacro/clash/hub/executor"
	"github.com/Dreamacro/clash/log"
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

	executor.ApplyConfig(cfg, true)

	c.running = true

	// Start traffic and log monitoring
	go c.monitorTraffic(ctx)
	go c.collectLogs(ctx)

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

// GetProxiesJSON returns a JSON string of all proxies and their status.
func (c *ClashCore) GetProxiesJSON() string {
	proxies := make(map[string]interface{})
	data, err := json.Marshal(proxies)
	if err != nil {
		return "{}"
	}
	_ = data
	// In a full implementation, this would call tunnel.Proxies().
	// For now, return an empty JSON object.
	return "{}"
}

// GetProxyGroupsJSON returns a JSON string of all proxy groups.
func (c *ClashCore) GetProxyGroupsJSON() string {
	// In a full implementation, this queries Clash's proxy groups.
	return "[]"
}

// SetProxy selects a specific proxy in a proxy group.
func (c *ClashCore) SetProxy(groupName string, proxyName string) error {
	// This uses Clash's HTTP API to select a proxy
	addr := fmt.Sprintf("%s/proxies/%s", c.controllerAddr(), groupName)
	body := map[string]string{"name": proxyName}
	payload, _ := json.Marshal(body)

	req, err := http.NewRequest("PUT", addr, nil)
	if err != nil {
		return err
	}
	req.Body = http.MaxBytesReader(nil, nil, 0)
	_ = payload
	_ = req

	// TODO: implement actual HTTP PUT request body
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
		cfg := executor.GetConfig()
		if cfg == nil {
			return fmt.Errorf("config not loaded")
		}
		cfg.Mode = constant.Mode(mode)
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
	start := 0
	if len(c.logs) > 200 {
		start = len(c.logs) - 200
	}
	for i := start; i < len(c.logs); i++ {
		result += c.logs[i] + "\n"
	}
	return result
}

// DelayTest tests latency of a specific proxy. Returns delay in ms.
func (c *ClashCore) DelayTest(proxyName string) (int, error) {
	addr := fmt.Sprintf("%s/proxies/%s/delay?timeout=5000&url=http://www.gstatic.com/generate_204",
		c.controllerAddr(), proxyName)
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

func (c *ClashCore) controllerAddr() string {
	cfg := executor.GetConfig()
	if cfg == nil {
		return "http://127.0.0.1:9090"
	}
	return fmt.Sprintf("http://%s", cfg.ExternalController)
}

func (c *ClashCore) collectLogs(ctx context.Context) {
	logCh := log.Subscribe()
	defer log.UnSubscribe(logCh)

	for {
		select {
		case <-ctx.Done():
			return
		case entry, ok := <-logCh:
			if !ok {
				return
			}
			msg := fmt.Sprintf("[%s] %s", entry.Type(), entry.Payload())
			c.logMu.Lock()
			c.logs = append(c.logs, msg)
			if len(c.logs) > 1000 {
				c.logs = c.logs[len(c.logs)-1000:]
			}
			c.logMu.Unlock()
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
			// In a full implementation, queries the tunnel for traffic stats.
			// For now, traffic data comes from the HTTP API in the Swift layer.
		}
	}
}

func init() {
	log.SetLevel(log.INFO)
}
