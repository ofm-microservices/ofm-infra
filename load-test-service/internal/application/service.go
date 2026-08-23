package application

import (
	"context"
	"errors"
	"go.uber.org/zap"
)

var ErrNilJobRunner = errors.New("job runner is nil")

// Service orchestrates load-test commands without owning Kubernetes details.
type Service struct {
	runner JobRunner
	log    *zap.Logger
}

// New constructs the application boundary for load-test control.
func New(runner JobRunner, log *zap.Logger) (*Service, error) {
	if runner == nil {
		return nil, ErrNilJobRunner
	}
	return &Service{runner: runner, log: log}, nil
}
func (s *Service) Start(ctx context.Context, input StartInput) (Job, error) {
	return s.runner.Start(ctx, input)
}
func (s *Service) List(ctx context.Context) ([]Job, error)           { return s.runner.List(ctx) }
func (s *Service) Get(ctx context.Context, name string) (Job, error) { return s.runner.Get(ctx, name) }
func (s *Service) Stop(ctx context.Context, name string) error       { return s.runner.Stop(ctx, name) }
