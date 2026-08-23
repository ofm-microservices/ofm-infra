package http

import (
	"encoding/json"
	"fmt"
	"github.com/ofm/load-test-service/internal/application"
	"github.com/ofm/load-test-service/internal/observability"
	"go.uber.org/zap"
	"net/http"
	"strconv"
	"strings"
)

// New builds the HTTP/HTMX boundary for load-test control.
func New(svc *application.Service, log *zap.Logger) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	mux.Handle("/metrics", observability.MetricsHandler())
	mux.HandleFunc("/api/runs", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var input application.StartInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			http.Error(w, "invalid experiment request", http.StatusBadRequest)
			return
		}
		if input.Workload == "" {
			input.Workload = "resilience"
		}
		if input.Duration == "" && input.DurationSeconds > 0 {
			input.Duration = fmt.Sprintf("%ds", input.DurationSeconds)
		}
		if input.Duration == "" {
			input.Duration = "10m"
		}
		job, err := svc.Start(r.Context(), input)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(job)
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		jobs, err := svc.List(r.Context())
		if err != nil {
			http.Error(w, err.Error(), 502)
			return
		}
		_ = Home(jobs).Render(r.Context(), w)
	})
	mux.HandleFunc("/runs", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			_ = r.ParseForm()
			duration := ""
			if r.FormValue("minutes") != "" {
				duration = fmt.Sprintf("%dm", intValue(r.FormValue("minutes"), 1))
			}
			profile := r.FormValue("profile")
			defaults := profileDefaults(profile)
			job, err := svc.Start(r.Context(), application.StartInput{LoadMode: valueOr(r.FormValue("load_mode"), "manual"), Profile: profile, Workload: valueOr(r.FormValue("workload"), "full-system"), VUs: intValue(r.FormValue("vus"), defaults.VUs), Iterations: intValue(r.FormValue("iterations"), defaults.Iterations), Duration: duration, Rate: intValue(r.FormValue("rate"), defaults.Rate), TargetRPS: intValue(r.FormValue("target_rps"), 0), ReadRPS: intValue(r.FormValue("read_rps"), 0), WriteRPS: intValue(r.FormValue("write_rps"), 0), TransitionRPS: intValue(r.FormValue("transition_rps"), 0), PreAllocatedVUs: intValue(r.FormValue("pre_allocated_vus"), defaults.PreAllocatedVUs), MaxVUs: intValue(r.FormValue("max_vus"), defaults.MaxVUs), FaultProfile: valueOr(r.FormValue("fault_profile"), "none"), FaultTarget: valueOr(r.FormValue("fault_target"), "*"), FaultRate: floatValue(r.FormValue("fault_rate"), 0), FaultDelay: r.FormValue("fault_delay"), FaultMaxFailures: intValue(r.FormValue("fault_max_failures"), 0), FaultTTL: r.FormValue("fault_ttl"), FaultAt: r.FormValue("fault_at"), FaultDuration: r.FormValue("fault_duration"), Accept5xx: r.FormValue("accept_5xx") == "on", AllowSlow: r.FormValue("allow_slow") == "on"})
			if err != nil {
				http.Error(w, err.Error(), 502)
				return
			}
			if strings.EqualFold(r.Header.Get("HX-Request"), "true") {
				w.Header().Set("HX-Redirect", "/runs/"+job.Name)
				w.WriteHeader(http.StatusNoContent)
				return
			}
			if strings.Contains(r.Header.Get("Accept"), "text/html") {
				http.Redirect(w, r, "/runs/"+job.Name, http.StatusSeeOther)
				return
			}
			json.NewEncoder(w).Encode(job)
			return
		}
		jobs, err := svc.List(r.Context())
		if err != nil {
			http.Error(w, err.Error(), 502)
			return
		}
		if strings.Contains(r.Header.Get("HX-Request"), "true") {
			_ = JobTable(jobs).Render(r.Context(), w)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"items": jobs})
	})
	mux.HandleFunc("/runs/", func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimPrefix(r.URL.Path, "/runs/")
		if r.Method == http.MethodDelete {
			if err := svc.Stop(r.Context(), name); err != nil {
				http.Error(w, err.Error(), 502)
				return
			}
			if strings.EqualFold(r.Header.Get("HX-Request"), "true") {
				w.Header().Set("HX-Redirect", "/")
				w.WriteHeader(http.StatusNoContent)
				return
			}
			jobs, _ := svc.List(r.Context())
			_ = JobTable(jobs).Render(r.Context(), w)
			return
		}
		job, err := svc.Get(r.Context(), name)
		if err != nil {
			http.Error(w, err.Error(), 502)
			return
		}
		payload, _ := json.MarshalIndent(job, "", "  ")
		if strings.EqualFold(r.Header.Get("HX-Request"), "true") {
			_ = DetailsContent(job, string(payload)).Render(r.Context(), w)
			return
		}
		if strings.Contains(r.Header.Get("Accept"), "text/html") {
			_ = Details(job, string(payload)).Render(r.Context(), w)
			return
		}
		json.NewEncoder(w).Encode(job)
	})
	return observability.Handler(mux)
}

func valueOr(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}
func floatValue(value string, fallback float64) float64 {
	v, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return fallback
	}
	return v
}
func profileDefaults(profile string) application.StartInput {
	switch strings.ToLower(profile) {
	case "mixed", "resilience", "high-load":
		return application.StartInput{VUs: 1, Iterations: 1, PreAllocatedVUs: 200, MaxVUs: 1000}
	case "light":
		return application.StartInput{VUs: 5, Iterations: 1, PreAllocatedVUs: 5, MaxVUs: 10}
	case "medium":
		return application.StartInput{VUs: 25, Iterations: 1, PreAllocatedVUs: 25, MaxVUs: 50}
	case "stress":
		return application.StartInput{VUs: 100, Iterations: 1, PreAllocatedVUs: 100, MaxVUs: 200}
	default:
		return application.StartInput{VUs: 1, Iterations: 1, PreAllocatedVUs: 1, MaxVUs: 2}
	}
}
func intValue(value string, fallback int) int {
	n, err := strconv.Atoi(value)
	if err != nil || n < 1 {
		return fallback
	}
	return n
}
