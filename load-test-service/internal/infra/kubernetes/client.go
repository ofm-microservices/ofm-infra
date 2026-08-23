package kubernetes

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/ofm/load-test-service/internal/application"
	"go.uber.org/zap"
)

type client struct {
	namespace, image, api, token, ca, clickhouse string
	clickhouseUser, clickhousePassword           string
	http                                         *http.Client
	log                                          *zap.Logger
}

// NewRunner creates a service-account Kubernetes adapter for Job lifecycle operations.
func NewRunner(namespace, image string, log *zap.Logger) application.JobRunner {
	if namespace == "" {
		namespace = "ofm"
	}
	if image == "" {
		image = "ofm/k6-full-system:local"
	}
	pool, _ := x509.SystemCertPool()
	if pool == nil {
		pool = x509.NewCertPool()
	}
	if cert, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"); err == nil {
		pool.AppendCertsFromPEM(cert)
	}
	transport := &http.Transport{TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12, RootCAs: pool}}
	return &client{namespace: namespace, image: image, clickhouse: os.Getenv("CLICKHOUSE_URL"), clickhouseUser: os.Getenv("CLICKHOUSE_USER"), clickhousePassword: os.Getenv("CLICKHOUSE_PASSWORD"), api: "https://" + os.Getenv("KUBERNETES_SERVICE_HOST") + ":" + os.Getenv("KUBERNETES_SERVICE_PORT_HTTPS"), token: read("/var/run/secrets/kubernetes.io/serviceaccount/token"), ca: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt", http: &http.Client{Transport: transport, Timeout: 15 * time.Second}, log: log}
}
func read(path string) string { b, _ := os.ReadFile(path); return strings.TrimSpace(string(b)) }
func (c *client) request(ctx context.Context, method, path string, body any, out any) error {
	var reader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.api+path, reader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")
	if method == http.MethodPatch {
		req.Header.Set("Content-Type", "application/merge-patch+json")
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("kubernetes %s: %s", resp.Status, strings.TrimSpace(string(b)))
	}
	if out != nil {
		return json.NewDecoder(resp.Body).Decode(out)
	}
	return nil
}

type jobObject struct {
	Metadata struct {
		Name              string            `json:"name"`
		Labels            map[string]string `json:"labels"`
		Annotations       map[string]string `json:"annotations"`
		CreationTimestamp string            `json:"creationTimestamp"`
	} `json:"metadata"`
	Status struct {
		Active     int `json:"active"`
		Succeeded  int `json:"succeeded"`
		Failed     int `json:"failed"`
		Conditions []struct {
			Type    string `json:"type"`
			Reason  string `json:"reason"`
			Message string `json:"message"`
		} `json:"conditions"`
	} `json:"status"`
}

func (c *client) Start(ctx context.Context, in application.StartInput) (application.Job, error) {
	if in.ReadRPS+in.WriteRPS > 0 {
		in.TargetRPS = in.ReadRPS + in.WriteRPS
	}
	run := newRunID()
	name := run
	if in.VUs < 1 {
		in.VUs = 1
	}
	if in.PreAllocatedVUs < 1 {
		in.PreAllocatedVUs = 200
	}
	if in.MaxVUs < 1 {
		in.MaxVUs = 1000
	}
	if in.Iterations < 1 {
		in.Iterations = 1
	}
	obj := map[string]any{"apiVersion": "batch/v1", "kind": "Job", "metadata": map[string]any{"name": name, "namespace": c.namespace, "labels": map[string]string{"ofm.test.run_id": run}}, "spec": map[string]any{"backoffLimit": 0, "ttlSecondsAfterFinished": 3600, "template": map[string]any{"metadata": map[string]any{"labels": map[string]string{"ofm.test.run_id": run}}, "spec": map[string]any{"restartPolicy": "Never", "containers": []any{map[string]any{"name": "k6", "image": c.image, "imagePullPolicy": "IfNotPresent", "command": []string{"k6", "run", "/work/full-system.js"}, "env": []map[string]string{{"name": "K6_TEST_RUN_ID", "value": run}, {"name": "K6_SCENARIO", "value": "full-system-" + run}, {"name": "OFM_FULL_K6_VUS", "value": fmt.Sprint(in.VUs)}, {"name": "OFM_FULL_K6_ITERATIONS", "value": fmt.Sprint(in.Iterations)}, {"name": "OFM_FULL_K6_MAX_DURATION", "value": in.Duration}, {"name": "OFM_FULL_K6_DURATION", "value": in.Duration}, {"name": "OFM_FULL_K6_RATE", "value": fmt.Sprint(in.Rate)}, {"name": "OFM_FULL_K6_PRE_ALLOCATED_VUS", "value": fmt.Sprint(in.PreAllocatedVUs)}, {"name": "OFM_FULL_K6_MAX_VUS", "value": fmt.Sprint(in.MaxVUs)}, {"name": "FAULT_PROFILE", "value": in.FaultProfile}, {"name": "FAULT_TARGET", "value": in.FaultTarget}, {"name": "FAULT_RATE", "value": fmt.Sprint(in.FaultRate)}, {"name": "FAULT_DELAY", "value": in.FaultDelay}, {"name": "FAULT_MAX_FAILURES", "value": fmt.Sprint(in.FaultMaxFailures)}, {"name": "FAULT_TTL", "value": in.FaultTTL}, {"name": "OFM_K6_ACCEPT_5XX", "value": strconv.FormatBool(in.Accept5xx)}, {"name": "OFM_K6_ALLOW_SLOW", "value": strconv.FormatBool(in.AllowSlow)}, {"name": "K6_CREATE_USERS", "value": "true"}, {"name": "K6_TEST_PASSWORD", "value": "Password123!"}, {"name": "K6_BASE_URL", "value": "http://api-gateway:8080/api/v2"}, {"name": "K6_PAYMENT_URL", "value": "http://payment-service:8081/v1"}}}}}}}}
	obj = map[string]any{"apiVersion": "batch/v1", "kind": "Job", "metadata": map[string]any{"name": name, "namespace": c.namespace, "labels": map[string]string{"ofm.test.run_id": run}, "annotations": map[string]string{"ofm.experiment.duration_seconds": strconv.Itoa(durationSeconds(in.Duration)), "ofm.experiment.vus": strconv.Itoa(in.VUs), "ofm.experiment.rate": strconv.Itoa(in.Rate), "ofm.experiment.profile": in.Profile}}, "spec": map[string]any{"backoffLimit": 0, "ttlSecondsAfterFinished": 3600, "template": map[string]any{"metadata": map[string]any{"labels": map[string]string{"ofm.test.run_id": run}}, "spec": map[string]any{"restartPolicy": "Never", "containers": []any{map[string]any{"name": "k6", "image": c.image, "imagePullPolicy": "IfNotPresent", "command": []string{"k6", "run", "/work/full-system.js"}, "env": []map[string]string{{"name": "K6_TEST_RUN_ID", "value": run}, {"name": "K6_SCENARIO", "value": "full-system-" + run}, {"name": "OFM_FULL_K6_VUS", "value": fmt.Sprint(in.VUs)}, {"name": "OFM_FULL_K6_ITERATIONS", "value": fmt.Sprint(in.Iterations)}, {"name": "OFM_FULL_K6_MAX_DURATION", "value": in.Duration}, {"name": "OFM_FULL_K6_DURATION", "value": in.Duration}, {"name": "OFM_FULL_K6_RATE", "value": fmt.Sprint(in.Rate)}, {"name": "OFM_FULL_K6_PRE_ALLOCATED_VUS", "value": fmt.Sprint(in.PreAllocatedVUs)}, {"name": "OFM_FULL_K6_MAX_VUS", "value": fmt.Sprint(in.MaxVUs)}, {"name": "FAULT_PROFILE", "value": in.FaultProfile}, {"name": "FAULT_TARGET", "value": in.FaultTarget}, {"name": "FAULT_RATE", "value": fmt.Sprint(in.FaultRate)}, {"name": "FAULT_DELAY", "value": in.FaultDelay}, {"name": "FAULT_MAX_FAILURES", "value": fmt.Sprint(in.FaultMaxFailures)}, {"name": "FAULT_TTL", "value": in.FaultTTL}, {"name": "OFM_K6_ACCEPT_5XX", "value": strconv.FormatBool(in.Accept5xx)}, {"name": "OFM_K6_ALLOW_SLOW", "value": strconv.FormatBool(in.AllowSlow)}, {"name": "K6_CREATE_USERS", "value": "true"}, {"name": "K6_TEST_PASSWORD", "value": "Password123!"}, {"name": "K6_BASE_URL", "value": "http://api-gateway:8080/api/v2"}, {"name": "K6_PAYMENT_URL", "value": "http://payment-service:8081/v1"}}}}}}}}
	templateSpec := obj["spec"].(map[string]any)["template"].(map[string]any)["spec"].(map[string]any)
	container := templateSpec["containers"].([]any)[0].(map[string]any)
	workload := strings.ToLower(strings.TrimSpace(in.Workload))
	if strings.EqualFold(in.LoadMode, "pc-capacity") {
		container["image"] = valueOrEnv("CAPACITY_CONTROLLER_IMAGE", "ofm/load-test-service:capacity4")
		templateSpec["serviceAccountName"] = "load-test-service"
	}
	if workload == "resilience" || workload == "high-load" {
		container["command"] = []string{"k6", "run", "/work/resilience.js"}
		workload = "resilience"
	} else {
		workload = "full-system"
	}
	env := container["env"].([]map[string]string)
	if in.Profile == "capacity-ramp" {
		env = append(env, map[string]string{"name": "OFM_CAPACITY_RAMP", "value": "true"}, map[string]string{"name": "OFM_CAPACITY_RAMP_SECONDS", "value": "10s"})
	}
	if strings.EqualFold(in.LoadMode, "pc-capacity") {
		container["command"] = []string{"/capacity-controller"}
		env = append(env,
			map[string]string{"name": "EXPERIMENT_URL", "value": "http://load-test-service:8080"},
			map[string]string{"name": "CAPACITY_START_RPS", "value": "100"},
			map[string]string{"name": "CAPACITY_STEP_RPS", "value": "100"},
			map[string]string{"name": "CAPACITY_MAX_RPS", "value": "5000"},
			map[string]string{"name": "CAPACITY_CPU_LIMIT", "value": "90"},
		)
	}
	env = append(env, map[string]string{"name": "FAULT_TEST_TOKEN", "value": "ofm-test-fault-token"})
	container["env"] = env
	annotations := obj["metadata"].(map[string]any)["annotations"].(map[string]string)
	annotations["ofm.experiment.duration_seconds"] = strconv.Itoa(durationSeconds(in.Duration))
	annotations["ofm.experiment.load_mode"] = in.LoadMode
	if strings.EqualFold(in.LoadMode, "pc-capacity") {
		annotations["ofm.experiment.duration_seconds"] = "0"
	}
	annotations["ofm.experiment.workload"] = workload
	annotations["ofm.experiment.target_rps"] = strconv.Itoa(in.TargetRPS)
	var created jobObject
	if err := c.request(ctx, http.MethodPost, "/apis/batch/v1/namespaces/"+c.namespace+"/jobs", obj, &created); err != nil {
		return application.Job{}, err
	}
	return mapJob(created), nil
}
func valueOrEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
func (c *client) List(ctx context.Context) ([]application.Job, error) {
	var result struct {
		Items []jobObject `json:"items"`
	}
	if err := c.request(ctx, http.MethodGet, "/apis/batch/v1/namespaces/"+c.namespace+"/jobs", nil, &result); err != nil {
		return nil, err
	}
	jobs := make([]application.Job, 0, len(result.Items))
	for _, j := range result.Items {
		if j.Metadata.Labels["ofm.test.run_id"] == "" {
			continue
		}
		jobs = append(jobs, mapJob(j))
	}
	return jobs, nil
}
func (c *client) Get(ctx context.Context, name string) (application.Job, error) {
	var j jobObject
	if err := c.request(ctx, http.MethodGet, "/apis/batch/v1/namespaces/"+c.namespace+"/jobs/"+name, nil, &j); err != nil {
		return application.Job{}, err
	}
	job := mapJob(j)
	if (job.State == "COMPLETED" || job.State == "FAILED") && j.Metadata.Annotations["ofm.results.persisted"] != "true" {
		if err := c.persist(ctx, name, job, j.Metadata.CreationTimestamp, j.Metadata.Annotations); err == nil {
			_ = c.request(ctx, http.MethodPatch, "/apis/batch/v1/namespaces/"+c.namespace+"/jobs/"+name, map[string]any{"metadata": map[string]any{"annotations": map[string]string{"ofm.results.persisted": "true"}}}, nil)
		} else if c.log != nil {
			c.log.Error("persisting load test result failed", zap.String("job", name), zap.Error(err))
		}
	}
	return job, nil
}
func (c *client) Stop(ctx context.Context, name string) error {
	return c.request(ctx, http.MethodDelete, "/apis/batch/v1/namespaces/"+c.namespace+"/jobs/"+name, map[string]string{"propagationPolicy": "Background"}, nil)
}
func mapJob(j jobObject) application.Job {
	state := "PENDING"
	msg := ""
	if j.Status.Active > 0 {
		state = "RUNNING"
	}
	if j.Status.Succeeded > 0 {
		state = "COMPLETED"
	}
	if j.Status.Failed > 0 {
		state = "FAILED"
	}
	if len(j.Status.Conditions) > 0 {
		msg = j.Status.Conditions[len(j.Status.Conditions)-1].Message
	}
	duration := 0
	if j.Metadata.Annotations != nil {
		duration, _ = strconv.Atoi(j.Metadata.Annotations["ofm.experiment.duration_seconds"])
	}
	remaining := duration
	if started, err := time.Parse(time.RFC3339, j.Metadata.CreationTimestamp); err == nil && duration > 0 && state == "RUNNING" {
		remaining = duration - int(time.Since(started).Seconds())
		if remaining < 0 {
			remaining = 0
		}
	}
	return application.Job{Name: j.Metadata.Name, RunID: j.Metadata.Labels["ofm.test.run_id"], State: state, Message: msg, DurationSeconds: duration, RemainingSeconds: remaining}
}
func durationSeconds(value string) int {
	d, err := time.ParseDuration(value)
	if err != nil || d <= 0 {
		return 0
	}
	return int(d.Seconds())
}
func newRunID() string {
	id, err := uuid.NewV7()
	if err != nil {
		return uuid.New().String()
	}
	return id.String()
}

func (c *client) persist(ctx context.Context, name string, job application.Job, started string, annotations map[string]string) error {
	if c.clickhouse == "" {
		return nil
	}
	if started == "" {
		started = time.Now().UTC().Format(time.RFC3339Nano)
	}
	finished := time.Now().UTC().Format(time.RFC3339Nano)
	var pods struct {
		Items []struct {
			Metadata struct {
				Name string `json:"name"`
			} `json:"metadata"`
		} `json:"items"`
	}
	if err := c.request(ctx, http.MethodGet, "/api/v1/namespaces/"+c.namespace+"/pods?labelSelector=job-name%3D"+url.QueryEscape(name), nil, &pods); err == nil && len(pods.Items) > 0 {
		if text, err := c.text(ctx, "/api/v1/namespaces/"+c.namespace+"/pods/"+pods.Items[0].Metadata.Name+"/log"); err == nil {
			for _, line := range strings.Split(text, "\n") {
				if strings.HasPrefix(line, "{\"ofm_summary\":") {
					var summary map[string]any
					if json.Unmarshal([]byte(line), &summary) == nil {
						return c.insertResult(ctx, started, finished, job, annotations, summary)
					}
				}
			}
		}
	}
	return c.insertResult(ctx, started, finished, job, annotations, map[string]any{})
}
func (c *client) insertResult(ctx context.Context, started, finished string, job application.Job, annotations map[string]string, summary map[string]any) error {
	started = clickhouseTime(started)
	finished = clickhouseTime(finished)
	query := "INSERT INTO ofm_load_test_runs (started_at,finished_at,run_id,scenario_id,environment,profile,architecture,vus,rate,duration_seconds,status,checks_total,checks_failed,expected_failures,recovery_pass,verdict,http_requests,http_failed,p95_duration_ms,kafka_lag,projection_pending,projection_failures,dlq_count,recovery_time_ms,result_json) FORMAT JSONEachRow"
	status := strings.ToLower(job.State)
	verdict := "FAIL"
	if status == "completed" && number(summary, "checks_failed") == 0 {
		verdict = "PASS"
	}
	workload := annotations["ofm.experiment.workload"]
	if workload == "" {
		workload = "full-system"
	}
	row, _ := json.Marshal(map[string]any{"started_at": started, "finished_at": finished, "run_id": job.RunID, "scenario_id": workload + "-" + job.RunID, "environment": "k3d", "profile": annotations["ofm.experiment.profile"], "architecture": "microservice", "vus": annotationInt(annotations, "ofm.experiment.vus"), "rate": annotationInt(annotations, "ofm.experiment.target_rps"), "duration_seconds": number(summary, "test_run_duration_ms") / 1000, "status": status, "checks_total": number(summary, "checks_total"), "checks_failed": number(summary, "checks_failed"), "expected_failures": number(summary, "expected_failures"), "recovery_pass": 0, "verdict": verdict, "http_requests": number(summary, "http_requests"), "http_failed": number(summary, "http_failed"), "p95_duration_ms": summary["p95_duration_ms"], "kafka_lag": 0, "projection_pending": 0, "projection_failures": 0, "dlq_count": 0, "recovery_time_ms": 0, "result_json": stringValue(summary, "result_json")})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.clickhouse+"/?query="+url.QueryEscape(query), bytes.NewReader(append(row, '\n')))
	if err != nil {
		return err
	}
	if c.clickhouseUser != "" {
		req.SetBasicAuth(c.clickhouseUser, c.clickhousePassword)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusMultipleChoices {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("clickhouse insert status %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}
	if c.log != nil {
		c.log.Info("load test result persisted", zap.String("run_id", job.RunID), zap.Int("http_status", resp.StatusCode))
	}
	return nil
}
func annotationInt(annotations map[string]string, key string) int {
	v, _ := strconv.Atoi(annotations[key])
	return v
}
func clickhouseTime(value string) string {
	parsed, err := time.Parse(time.RFC3339Nano, value)
	if err != nil {
		return value
	}
	return parsed.UTC().Format("2006-01-02 15:04:05.000")
}
func number(m map[string]any, key string) int {
	if v, ok := m[key].(float64); ok {
		return int(v)
	}
	return 0
}
func stringValue(m map[string]any, key string) string {
	if v, ok := m[key].(string); ok {
		return v
	}
	b, _ := json.Marshal(m)
	return string(b)
}
func (c *client) text(ctx context.Context, path string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.api+path, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	resp, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return "", fmt.Errorf("kubernetes log status %s", resp.Status)
	}
	b, err := io.ReadAll(resp.Body)
	return string(b), err
}
