package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	"path/filepath"
)

type Order struct {
	OrderID      string    `json:"orderId"`
	Drink        string    `json:"drink"`
	CustomerName string    `json:"customerName"`
	Instructions string    `json:"instructions"`
	Timestamp    time.Time `json:"timestamp"`
}

type CreateSessionRequest struct {
	SessionName string `json:"sessionName"`
}

type SwitchSessionRequest struct {
	SessionName string `json:"sessionName"`
}

type CreateOrderRequest struct {
	Drink        string `json:"drink"`
	CustomerName string `json:"customerName"`
	Instructions string `json:"instructions"`
}

type PopularStats struct {
	Counts map[string]int `json:"counts"`
}

var (
	selectedSessionMu sync.RWMutex
	selectedSession   string

	popularMu sync.Mutex
)

func main() {
	http.Handle("/", http.FileServer(http.Dir("web")))

	http.HandleFunc("/menu", func(w http.ResponseWriter, r *http.Request) {
		menu := getMenu()
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"menu": [`)
		for i, item := range menu {
			fmt.Fprintf(w, `"%s"`, item)
			if i < len(menu)-1 {
				fmt.Fprint(w, ", ")
			}
		}
		fmt.Fprint(w, `]}`)
	})

	http.HandleFunc("/session/create", handleCreateSession)
	http.HandleFunc("/session/switch", handleSwitchSession)
	http.HandleFunc("/session/current", handleCurrentSession)
	http.HandleFunc("/order", handleCreateOrder)
	http.HandleFunc("/orders", handleFetchOrders)
	http.HandleFunc("/popular", handlePopular)

	go func() {
		if err := startAdminServer(); err != nil {
			log.Printf("ERROR: Admin server failed to start: %v", err)
			// Don't exit - let the main server continue running
		}
	}()

	fmt.Println("Serving coffee menu on :8080/menu")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

func getMenu() []string {
	file, err := os.Open("menu.txt")
	if err != nil {
		// If error opening the file, return an empty menu or some placeholder
		return []string{}
	}
	defer file.Close()

	var menu []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		// Remove trailing commas, leading and trailing quotes
		line = strings.TrimSuffix(line, ",")
		line = strings.Trim(line, `"`)
		if line != "" {
			menu = append(menu, line)
		}
	}
	return menu
}

func startAdminServer() error {
	adminMux := http.NewServeMux()
	adminMux.Handle("/", http.FileServer(http.Dir("admin")))
	adminMux.HandleFunc("/api/sessions", adminHandleSessions)
	adminMux.HandleFunc("/api/session/create", adminHandleCreateSession)
	adminMux.HandleFunc("/api/session/switch", adminHandleSwitchSession)
	adminMux.HandleFunc("/api/orders", adminHandleOrders)
	adminMux.HandleFunc("/api/popular", adminHandlePopular)

	// Explicitly bind to all interfaces (both IPv4 and IPv6)
	addr := "0.0.0.0:9090"
	fmt.Printf("Admin portal starting on %s (all interfaces)\n", addr)
	
	// Create listener explicitly to ensure IPv4 binding
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("failed to create listener: %w", err)
	}
	
	if err := http.Serve(listener, adminMux); err != nil {
		return fmt.Errorf("admin server error: %w", err)
	}
	return nil
}

func handleCreateSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	sessionName := strings.TrimSpace(req.SessionName)
	if sessionName == "" {
		http.Error(w, "sessionName is required", http.StatusBadRequest)
		return
	}

	if !isValidSessionName(sessionName) {
		http.Error(w, "invalid sessionName", http.StatusBadRequest)
		return
	}

	if err := ensureSessionFolder(sessionName); err != nil {
		http.Error(w, "failed to create session: "+err.Error(), http.StatusInternalServerError)
		return
	}

	setSelectedSession(sessionName)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"sessionName": sessionName,
		"status":      "created",
	})
}

func handleCurrentSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	current := getSelectedSession()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"sessionName": current,
	})
}

func handleSwitchSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req SwitchSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	sessionName := strings.TrimSpace(req.SessionName)
	if sessionName == "" {
		http.Error(w, "sessionName is required", http.StatusBadRequest)
		return
	}

	if !isValidSessionName(sessionName) {
		http.Error(w, "invalid sessionName", http.StatusBadRequest)
		return
	}

	path := sessionFolderPath(sessionName)
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		http.Error(w, "session does not exist", http.StatusNotFound)
		return
	}

	setSelectedSession(sessionName)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"sessionName": sessionName,
		"status":      "switched",
	})
}

func handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	sessionName := getSelectedSession()
	if sessionName == "" {
		http.Error(w, "no session selected", http.StatusBadRequest)
		return
	}

	var req CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	req.Drink = strings.TrimSpace(req.Drink)
	if req.Drink == "" {
		http.Error(w, "drink is required", http.StatusBadRequest)
		return
	}

	req.CustomerName = strings.TrimSpace(req.CustomerName)
	if req.CustomerName == "" {
		http.Error(w, "customerName is required", http.StatusBadRequest)
		return
	}

	if !drinkOnMenu(req.Drink) {
		http.Error(w, "drink not on menu", http.StatusBadRequest)
		return
	}

	order := Order{
		OrderID:      generateOrderID(),
		Drink:        req.Drink,
		CustomerName: req.CustomerName,
		Instructions: strings.TrimSpace(req.Instructions),
		Timestamp:    time.Now().UTC(),
	}

	if err := writeOrderToSession(sessionName, order); err != nil {
		http.Error(w, "failed to save order: "+err.Error(), http.StatusInternalServerError)
		return
	}

	if err := incrementPopularCount(order.Drink); err != nil {
		// Log but don't fail the request if popularity tracking breaks.
		log.Println("failed to update popular stats:", err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(order)
}

func handleFetchOrders(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	sessionName := getSelectedSession()
	if sessionName == "" {
		http.Error(w, "no session selected", http.StatusBadRequest)
		return
	}

	orders, err := readOrdersFromSession(sessionName)
	if err != nil {
		http.Error(w, "failed to read orders: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string][]Order{
		"orders": orders,
	})
}

func isValidSessionName(name string) bool {
	for _, r := range name {
		if (r >= 'a' && r <= 'z') ||
			(r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') ||
			r == '-' || r == '_' {
			continue
		}
		return false
	}
	return true
}

func sessionsRoot() string {
	return "Sessions"
}

func sessionFolderPath(sessionName string) string {
	return filepath.Join(sessionsRoot(), sessionName)
}

func ensureSessionFolder(sessionName string) error {
	root := sessionsRoot()
	if err := os.MkdirAll(root, 0o755); err != nil {
		return err
	}
	sessionPath := sessionFolderPath(sessionName)
	return os.MkdirAll(sessionPath, 0o755)
}

func writeOrderToSession(sessionName string, order Order) error {
	if err := ensureSessionFolder(sessionName); err != nil {
		return err
	}
	orderData, err := json.MarshalIndent(order, "", "  ")
	if err != nil {
		return err
	}

	filename := fmt.Sprintf("order-%s.json", order.OrderID)
	path := filepath.Join(sessionFolderPath(sessionName), filename)
	return os.WriteFile(path, orderData, 0o644)
}

func readOrdersFromSession(sessionName string) ([]Order, error) {
	sessionPath := sessionFolderPath(sessionName)
	entries, err := os.ReadDir(sessionPath)
	if err != nil {
		return nil, err
	}

	var orders []Order
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if !strings.HasPrefix(entry.Name(), "order-") || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		fullPath := filepath.Join(sessionPath, entry.Name())
		data, err := os.ReadFile(fullPath)
		if err != nil {
			continue
		}

		var order Order
		if err := json.Unmarshal(data, &order); err != nil {
			continue
		}
		orders = append(orders, order)
	}

	return orders, nil
}

func handlePopular(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	popularMu.Lock()
	defer popularMu.Unlock()

	stats, err := loadPopularStats()
	if err != nil {
		http.Error(w, "failed to read popular stats: "+err.Error(), http.StatusInternalServerError)
		return
	}

	items := make([]popularItem, 0, len(stats.Counts))
	for drink, count := range stats.Counts {
		items = append(items, popularItem{Drink: drink, Count: count})
	}

	sort.Slice(items, func(i, j int) bool {
		if items[i].Count == items[j].Count {
			return items[i].Drink < items[j].Drink
		}
		return items[i].Count > items[j].Count
	})

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"items": items,
	})
}

func adminHandleSessions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var sessions []string
	entries, err := os.ReadDir(sessionsRoot())
	if err == nil {
		for _, entry := range entries {
			if entry.IsDir() {
				sessions = append(sessions, entry.Name())
			}
		}
	}

	current := getSelectedSession()

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"sessions":        sessions,
		"selectedSession": current,
	})
}

func adminHandleCreateSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	sessionName := strings.TrimSpace(req.SessionName)
	if sessionName == "" {
		http.Error(w, "sessionName is required", http.StatusBadRequest)
		return
	}

	if !isValidSessionName(sessionName) {
		http.Error(w, "invalid sessionName", http.StatusBadRequest)
		return
	}

	if err := ensureSessionFolder(sessionName); err != nil {
		http.Error(w, "failed to create session: "+err.Error(), http.StatusInternalServerError)
		return
	}

	setSelectedSession(sessionName)

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"sessionName": sessionName,
		"status":      "created",
	})
}

func adminHandleSwitchSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req SwitchSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	sessionName := strings.TrimSpace(req.SessionName)
	if sessionName == "" {
		http.Error(w, "sessionName is required", http.StatusBadRequest)
		return
	}

	if !isValidSessionName(sessionName) {
		http.Error(w, "invalid sessionName", http.StatusBadRequest)
		return
	}

	path := sessionFolderPath(sessionName)
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		http.Error(w, "session does not exist", http.StatusNotFound)
		return
	}

	setSelectedSession(sessionName)

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"sessionName": sessionName,
		"status":      "switched",
	})
}

func adminHandleOrders(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	sessionName := strings.TrimSpace(r.URL.Query().Get("sessionName"))
	if sessionName == "" {
		sessionName = getSelectedSession()
	}
	if sessionName == "" {
		http.Error(w, "no session selected", http.StatusBadRequest)
		return
	}

	orders, err := readOrdersFromSession(sessionName)
	if err != nil {
		http.Error(w, "failed to read orders: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"sessionName": sessionName,
		"orders":      orders,
	})
}

type popularItem struct {
	Drink string `json:"drink"`
	Count int    `json:"count"`
}

func adminHandlePopular(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	popularMu.Lock()
	defer popularMu.Unlock()

	stats, err := loadPopularStats()
	if err != nil {
		http.Error(w, "failed to read popular stats: "+err.Error(), http.StatusInternalServerError)
		return
	}

	items := make([]popularItem, 0, len(stats.Counts))
	for drink, count := range stats.Counts {
		items = append(items, popularItem{Drink: drink, Count: count})
	}

	sort.Slice(items, func(i, j int) bool {
		if items[i].Count == items[j].Count {
			return items[i].Drink < items[j].Drink
		}
		return items[i].Count > items[j].Count
	})

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"items": items,
	})
}

func loadPopularStats() (*PopularStats, error) {
	data, err := os.ReadFile("popular.json")
	if err != nil {
		if os.IsNotExist(err) {
			return &PopularStats{Counts: map[string]int{}}, nil
		}
		return nil, err
	}

	var stats PopularStats
	if err := json.Unmarshal(data, &stats); err != nil {
		return &PopularStats{Counts: map[string]int{}}, nil
	}
	if stats.Counts == nil {
		stats.Counts = map[string]int{}
	}
	return &stats, nil
}

func savePopularStats(stats *PopularStats) error {
	data, err := json.MarshalIndent(stats, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile("popular.json", data, 0o644)
}

func incrementPopularCount(drink string) error {
	popularMu.Lock()
	defer popularMu.Unlock()

	stats, err := loadPopularStats()
	if err != nil {
		return err
	}

	if stats.Counts == nil {
		stats.Counts = map[string]int{}
	}
	stats.Counts[drink]++

	return savePopularStats(stats)
}

func drinkOnMenu(drink string) bool {
	menu := getMenu()
	for _, item := range menu {
		if strings.EqualFold(item, drink) {
			return true
		}
	}
	return false
}

func generateOrderID() string {
	return fmt.Sprintf("%d", time.Now().UTC().UnixNano())
}

func setSelectedSession(name string) {
	selectedSessionMu.Lock()
	defer selectedSessionMu.Unlock()
	selectedSession = name
}

func getSelectedSession() string {
	selectedSessionMu.RLock()
	defer selectedSessionMu.RUnlock()
	return selectedSession
}
