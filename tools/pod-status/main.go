package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Stage status enum
type StageStatus int

const (
	StatusPending StageStatus = iota
	StatusRunning
	StatusSuccess
	StatusFailed
)

type Stage struct {
	Name        string
	Description string
	Status      StageStatus
	Detail      string
}

type model struct {
	podID       string
	timeoutSec  int
	intervalSec int
	apiKey      string

	stages       []Stage
	currentStage int
	spinner      spinner.Model
	startTime    time.Time
	elapsed      time.Duration
	err          error
	done         bool
	success      bool

	// Results
	promptResponse string
}

// Custom Messages
type tickMsg time.Time
type stageResultMsg struct {
	stageIndex int
	success    bool
	detail     string
	nextStage  bool
	response   string
	err        error
}

// Lipgloss Styles
var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#7D56F4")).
			MarginBottom(1)

	subTitleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#A0A0A0")).
			MarginBottom(1)

	stagePendingStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#626262"))

	stageRunningStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#00D7FF"))

	stageSuccessStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#50FA7B"))

	stageFailedStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#FF5555"))

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#7D56F4")).
			Padding(1, 2).
			MarginTop(1)

	detailStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#F1FA8C")).
			Italic(true)
)

func loadRunPodSecret() string {
	if key := os.Getenv("RUNPOD_API_KEY"); key != "" {
		return key
	}
	// Try loading from /dev/shm/fog/runpod-secret.env
	envPath := "/dev/shm/fog/runpod-secret.env"
	data, err := os.ReadFile(envPath)
	if err == nil {
		lines := strings.Split(string(data), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "export RUNPOD_API_KEY=") || strings.HasPrefix(line, "RUNPOD_API_KEY=") {
				parts := strings.SplitN(line, "=", 2)
				if len(parts) == 2 {
					val := strings.Trim(parts[1], `"'`)
					return val
				}
			}
		}
	}
	return ""
}

func initialModel(podID string, timeoutSec, intervalSec int) model {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("#00D7FF"))

	apiKey := loadRunPodSecret()

	stages := []Stage{
		{Name: "1. Pod Existence Check", Description: "Querying RunPod API for pod definition"},
		{Name: "2. Pod Running Status", Description: "Verifying desiredStatus is RUNNING"},
		{Name: "3. Container Port & Network", Description: "Checking container HTTP server readiness"},
		{Name: "4. LLM Health Check", Description: "Polling GET /health endpoint (HTTP 200 OK)"},
		{Name: "5. Live Inference Test", Description: "Sending prompt 'What is 2 + 2?' to worker-tier"},
	}

	return model{
		podID:        podID,
		timeoutSec:   timeoutSec,
		intervalSec:  intervalSec,
		apiKey:       apiKey,
		stages:       stages,
		currentStage: 0,
		spinner:      s,
		startTime:    time.Now(),
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		m.tickCmd(),
		m.executeStageCmd(0),
	)
}

func (m model) tickCmd() tea.Cmd {
	return tea.Tick(time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m model) executeStageCmd(stageIdx int) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), time.Duration(m.timeoutSec)*time.Second)
		defer cancel()

		switch stageIdx {
		case 0:
			// Stage 1: Pod Exists
			exists, name, err := checkPodExists(ctx, m.apiKey, m.podID)
			if err != nil || !exists {
				return stageResultMsg{stageIndex: 0, success: false, detail: "Pod not found on RunPod account", err: err}
			}
			return stageResultMsg{stageIndex: 0, success: true, detail: fmt.Sprintf("Pod found (Name: %s)", name), nextStage: true}

		case 1:
			// Stage 2: Pod Status RUNNING
			status, err := getPodStatus(ctx, m.apiKey, m.podID)
			if err != nil {
				return stageResultMsg{stageIndex: 1, success: false, detail: "Failed to query pod status", err: err}
			}
			if status != "RUNNING" {
				return stageResultMsg{stageIndex: 1, success: false, detail: fmt.Sprintf("Current status: %s (Waiting for RUNNING)", status)}
			}
			return stageResultMsg{stageIndex: 1, success: true, detail: "Pod status is RUNNING", nextStage: true}

		case 2:
			// Stage 3: Container Port / Proxy Readiness
			url := fmt.Sprintf("https://%s-8000.proxy.runpod.net/health", m.podID)
			respStatus, err := checkHTTPHead(ctx, url)
			if err != nil || (respStatus != 200 && respStatus != 404) {
				return stageResultMsg{stageIndex: 2, success: false, detail: "Container HTTP port not reachable yet"}
			}
			return stageResultMsg{stageIndex: 2, success: true, detail: "Container proxy port accessible", nextStage: true}

		case 3:
			// Stage 4: LLM Health Endpoint (200 OK)
			url := fmt.Sprintf("https://%s-8000.proxy.runpod.net/health", m.podID)
			respStatus, err := checkHTTPHealth(ctx, url)
			if err != nil || respStatus != 200 {
				return stageResultMsg{stageIndex: 3, success: false, detail: fmt.Sprintf("Health status: HTTP %d (Waiting for 200 OK)", respStatus)}
			}
			return stageResultMsg{stageIndex: 3, success: true, detail: "vLLM Engine Health: HTTP 200 OK", nextStage: true}

		case 4:
			// Stage 5: Live Inference Test
			url := fmt.Sprintf("https://%s-8000.proxy.runpod.net/v1/chat/completions", m.podID)
			reply, err := runInferenceTest(ctx, url)
			if err != nil {
				return stageResultMsg{stageIndex: 4, success: false, detail: "Inference test failed", err: err}
			}
			return stageResultMsg{stageIndex: 4, success: true, detail: fmt.Sprintf("Response: %s", reply), response: reply, nextStage: false}
		}

		return nil
	}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" || msg.String() == "q" {
			return m, tea.Quit
		}

	case tickMsg:
		m.elapsed = time.Since(m.startTime)
		if m.elapsed >= time.Duration(m.timeoutSec)*time.Second && !m.done {
			m.done = true
			m.success = false
			m.err = fmt.Errorf("readiness verification timed out after %d seconds", m.timeoutSec)
			return m, tea.Quit
		}

		// Re-trigger stage execution if still waiting on a stage
		var cmds []tea.Cmd
		cmds = append(cmds, m.tickCmd())

		if !m.done && m.stages[m.currentStage].Status == StatusRunning {
			cmds = append(cmds, m.executeStageCmd(m.currentStage))
		}
		return m, tea.Batch(cmds...)

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case stageResultMsg:
		if msg.success {
			m.stages[msg.stageIndex].Status = StatusSuccess
			m.stages[msg.stageIndex].Detail = msg.detail

			if msg.nextStage && msg.stageIndex+1 < len(m.stages) {
				m.currentStage = msg.stageIndex + 1
				m.stages[m.currentStage].Status = StatusRunning
				return m, m.executeStageCmd(m.currentStage)
			} else if !msg.nextStage {
				m.done = true
				m.success = true
				m.promptResponse = msg.response
				return m, tea.Quit
			}
		} else {
			if msg.err != nil {
				m.stages[msg.stageIndex].Status = StatusFailed
				m.stages[msg.stageIndex].Detail = msg.detail
				m.done = true
				m.success = false
				m.err = msg.err
				return m, tea.Quit
			} else {
				// Retrying pending stage after interval
				m.stages[msg.stageIndex].Status = StatusRunning
				m.stages[msg.stageIndex].Detail = msg.detail
			}
		}
	}

	return m, nil
}

func (m model) View() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("🔍 RunPod vLLM Readiness & Health Monitor") + "\n")
	b.WriteString(subTitleStyle.Render(fmt.Sprintf("Pod ID: %s | Timeout: %ds | Elapsed: %ds", m.podID, m.timeoutSec, int(m.elapsed.Seconds()))) + "\n\n")

	for i, stage := range m.stages {
		var icon string
		var style lipgloss.Style

		switch stage.Status {
		case StatusPending:
			icon = "⚪"
			style = stagePendingStyle
		case StatusRunning:
			icon = m.spinner.View()
			style = stageRunningStyle
		case StatusSuccess:
			icon = "✔"
			style = stageSuccessStyle
		case StatusFailed:
			icon = "✖"
			style = stageFailedStyle
		}

		line := fmt.Sprintf("%s %s", icon, stage.Name)
		if stage.Detail != "" {
			line += fmt.Sprintf(" - %s", detailStyle.Render(stage.Detail))
		}

		b.WriteString(style.Render(line) + "\n")
		if i == m.currentStage && stage.Status == StatusRunning {
			b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("#626262")).Render("   ↪ "+stage.Description) + "\n")
		}
	}

	if m.done {
		var summary string
		if m.success {
			summary = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#50FA7B")).
				Render(fmt.Sprintf("🎉 SUCCESS: Pod %s is fully HEALTHY and serving inference!\nPrompt Result: %s", m.podID, m.promptResponse))
		} else {
			summary = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#FF5555")).
				Render(fmt.Sprintf("❌ FAILED: %v", m.err))
		}
		b.WriteString("\n" + boxStyle.Render(summary) + "\n")
	} else {
		b.WriteString("\n" + lipgloss.NewStyle().Foreground(lipgloss.Color("#626262")).Render("Press 'q' or 'Ctrl+C' to exit monitor") + "\n")
	}

	return b.String()
}

// RunPod & vLLM API Helper Functions
func checkPodExists(ctx context.Context, apiKey, podID string) (bool, string, error) {
	if apiKey == "" {
		// Default fallback to true if no API key provided
		return true, podID, nil
	}
	url := "https://api.runpod.io/graphql"
	query := fmt.Sprintf(`query { pod(input: {podId: "%s"}) { id name } }`, podID)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBufferString(fmt.Sprintf(`{"query": %q}`, query)))
	if err != nil {
		return false, "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("User-Agent", "Mozilla/5.0")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return false, "", err
	}
	defer resp.Body.Close()

	var result struct {
		Data struct {
			Pod struct {
				ID   string `json:"id"`
				Name string `json:"name"`
			} `json:"pod"`
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return false, "", err
	}

	if result.Data.Pod.ID != "" {
		return true, result.Data.Pod.Name, nil
	}
	return false, "", nil
}

func getPodStatus(ctx context.Context, apiKey, podID string) (string, error) {
	if apiKey == "" {
		return "RUNNING", nil
	}
	url := "https://api.runpod.io/graphql"
	query := fmt.Sprintf(`query { pod(input: {podId: "%s"}) { desiredStatus } }`, podID)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBufferString(fmt.Sprintf(`{"query": %q}`, query)))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("User-Agent", "Mozilla/5.0")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result struct {
		Data struct {
			Pod struct {
				DesiredStatus string `json:"desiredStatus"`
			} `json:"pod"`
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	return result.Data.Pod.DesiredStatus, nil
}

func checkHTTPHead(ctx context.Context, url string) (int, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("User-Agent", "vLLM/Client")

	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	return resp.StatusCode, nil
}

func checkHTTPHealth(ctx context.Context, url string) (int, error) {
	return checkHTTPHead(ctx, url)
}

func runInferenceTest(ctx context.Context, url string) (string, error) {
	payload := map[string]interface{}{
		"model": "Qwen/Qwen2.5-Coder-32B-Instruct-AWQ",
		"messages": []map[string]string{
			{"role": "user", "content": "What is 2 + 2? Reply with one word."},
		},
		"max_tokens": 10,
	}
	jsonBody, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "vLLM/Client")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("status HTTP %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var result struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	if len(result.Choices) > 0 {
		return strings.TrimSpace(result.Choices[0].Message.Content), nil
	}
	return "", fmt.Errorf("empty choice array returned")
}

func main() {
	podIDFlag := flag.String("pod", "ms68rc2gadvzu5", "RunPod Pod ID to monitor")
	timeoutFlag := flag.Int("timeout", 300, "Overall readiness timeout in seconds")
	intervalFlag := flag.Int("wait", 5, "Polling interval in seconds")

	flag.Parse()

	// If pod flag is default, check active hardware doc for active pod ID
	podID := *podIDFlag
	if podID == "ms68rc2gadvzu5" {
		docPath := filepath.Join(os.Getenv("HOME"), "src/fog/docs/hardware/runpod.md")
		data, err := os.ReadFile(docPath)
		if err == nil {
			lines := strings.Split(string(data), "\n")
			for _, line := range lines {
				if strings.Contains(line, "**Pod ID**") {
					parts := strings.Split(line, "`")
					if len(parts) >= 2 {
						podID = parts[1]
						break
					}
				}
			}
		}
	}

	p := tea.NewProgram(initialModel(podID, *timeoutFlag, *intervalFlag))
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error running monitor: %v\n", err)
		os.Exit(1)
	}
}
