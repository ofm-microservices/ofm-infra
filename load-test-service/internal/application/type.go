package application

import "context"

// JobRunner owns the lifecycle of Kubernetes load-test Jobs.
type JobRunner interface {
	Start(context.Context, StartInput) (Job, error)
	List(context.Context) ([]Job, error)
	Get(context.Context, string) (Job, error)
	Stop(context.Context, string) error
}

// StartInput describes a laptop-safe or explicit load-test profile.
type StartInput struct {
	LoadMode         string  `json:"load_mode"`
	Profile          string  `json:"profile"`
	Workload         string  `json:"workload"`
	VUs              int     `json:"vus"`
	Iterations       int     `json:"iterations"`
	Duration         string  `json:"duration"`
	DurationSeconds  int     `json:"duration_seconds"`
	Rate             int     `json:"rate"`
	TargetRPS        int     `json:"target_rps"`
	ReadRPS          int     `json:"read_rps"`
	WriteRPS         int     `json:"write_rps"`
	TransitionRPS    int     `json:"transition_rps"`
	PreAllocatedVUs  int     `json:"pre_allocated_vus"`
	MaxVUs           int     `json:"max_vus"`
	FaultProfile     string  `json:"fault_profile"`
	FaultTarget      string  `json:"fault_target"`
	FaultRate        float64 `json:"fault_rate"`
	FaultDelay       string  `json:"fault_delay"`
	FaultMaxFailures int     `json:"fault_max_failures"`
	FaultTTL         string  `json:"fault_ttl"`
	Accept5xx        bool    `json:"accept_5xx"`
	AllowSlow        bool    `json:"allow_slow"`
	FaultAt          string  `json:"fault_at"`
	FaultDuration    string  `json:"fault_duration"`
}

// Job is the transport-neutral load-test status model.
type Job struct {
	Name             string `json:"name"`
	RunID            string `json:"run_id"`
	State            string `json:"state"`
	Message          string `json:"message,omitempty"`
	DurationSeconds  int    `json:"duration_seconds,omitempty"`
	RemainingSeconds int    `json:"remaining_seconds,omitempty"`
}
