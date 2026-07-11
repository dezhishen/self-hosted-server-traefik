package service

import (
	"fmt"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *Validator implements contracts.ServiceValidator.
var _ contracts.ServiceValidator = (*Validator)(nil)

type Validator struct{}

func NewValidator() *Validator {
	return &Validator{}
}

func (v *Validator) Validate(service *contracts.ServiceDefinition) error {
	if service.Name == "" {
		return fmt.Errorf("service name is required")
	}
	if service.Container != nil && service.Container.Image == "" {
		return fmt.Errorf("service %q: container image is required", service.Name)
	}
	if len(service.Params) > 0 {
		seen := make(map[string]bool)
		for _, p := range service.Params {
			if p.Name == "" {
				return fmt.Errorf("service %q: param name is required", service.Name)
			}
			if seen[p.Name] {
				return fmt.Errorf("service %q: duplicate param name %q", service.Name, p.Name)
			}
			seen[p.Name] = true
		}
	}
	return nil
}

func (v *Validator) ValidateAll(services []*contracts.ServiceDefinition) error {
	for _, svc := range services {
		if err := v.Validate(svc); err != nil {
			return err
		}
	}
	return nil
}
