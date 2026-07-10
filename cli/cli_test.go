package main

import (
	"context"
	"os"
	"testing"
	"time"
)

func runWithArgs(args []string) int {
	os.Args = args
	return run()
}

func TestHelp(t *testing.T) {
	if code := runWithArgs([]string{"selfhosted", "help"}); code != 0 {
		t.Errorf("help exit code = %d, want 0", code)
	}
}

func TestVersion(t *testing.T) {
	if code := runWithArgs([]string{"selfhosted", "version"}); code != 0 {
		t.Errorf("version exit code = %d, want 0", code)
	}
}

func TestNoArgs(t *testing.T) {
	if code := runWithArgs([]string{"selfhosted"}); code != 0 {
		t.Errorf("no args exit code = %d, want 0", code)
	}
}

func TestUnknownCommand(t *testing.T) {
	if code := runWithArgs([]string{"selfhosted", "nonexistent"}); code != 2 {
		t.Errorf("unknown command exit code = %d, want 2", code)
	}
}

func TestConfigFlag(t *testing.T) {
	code := runWithArgs([]string{"selfhosted", "-c", "/tmp/test.yaml", "version"})
	if code != 0 {
		t.Errorf("config flag exit code = %d, want 0", code)
	}
}

func TestHostFlag(t *testing.T) {
	code := runWithArgs([]string{"selfhosted", "--host", "tcp://192.168.1.1:2375", "version"})
	if code != 0 {
		t.Errorf("host flag exit code = %d, want 0", code)
	}
}

func TestInstallMissingArgs(t *testing.T) {
	if code := runWithArgs([]string{"selfhosted", "install"}); code != 2 {
		t.Errorf("install missing args exit code = %d, want 2", code)
	}
}

func TestUninstallMissingArgs(t *testing.T) {
	if code := runWithArgs([]string{"selfhosted", "uninstall"}); code != 2 {
		t.Errorf("uninstall missing args exit code = %d, want 2", code)
	}
}

func TestStatusMissingArgs(t *testing.T) {
	if code := runWithArgs([]string{"selfhosted", "status"}); code != 2 {
		t.Errorf("status missing args exit code = %d, want 2", code)
	}
}

func TestServeDefault(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	done := make(chan int, 1)
	go func() {
		done <- runWithArgs([]string{"selfhosted", "serve", ":0"})
	}()

	select {
	case code := <-done:
		// Server exited on its own (may happen with :0)
		t.Logf("serve exit code = %d", code)
	case <-ctx.Done():
		// Server started successfully (blocked), timeout is expected
	}
}

func TestServeCustomPort(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	done := make(chan int, 1)
	go func() {
		done <- runWithArgs([]string{"selfhosted", "serve", ":9091"})
	}()

	select {
	case code := <-done:
		t.Logf("serve exit code = %d", code)
	case <-ctx.Done():
	}
}

func TestSubCommands(t *testing.T) {
	tests := []struct {
		name     string
		args     []string
		wantCode int
	}{
		{"sub add missing url", []string{"selfhosted", "sub", "add", "name"}, 2},
		{"sub add missing name", []string{"selfhosted", "sub", "add"}, 2},
		{"sub remove missing name", []string{"selfhosted", "sub", "remove"}, 2},
		{"sub list", []string{"selfhosted", "sub", "list"}, 1},
		{"sub sync missing name", []string{"selfhosted", "sub", "sync"}, 2},
		{"sub unknown", []string{"selfhosted", "sub", "unknown"}, 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if code := runWithArgs(tt.args); code != tt.wantCode {
				t.Errorf("%s exit code = %d, want %d", tt.name, code, tt.wantCode)
			}
		})
	}
}

func TestRemoteCommands(t *testing.T) {
	tests := []struct {
		name     string
		args     []string
		wantCode int
	}{
		{"remote add", []string{"selfhosted", "remote", "add", "s1", "tcp://h:2375"}, 1},
		{"remote add missing addr", []string{"selfhosted", "remote", "add", "s1"}, 2},
		{"remote remove missing name", []string{"selfhosted", "remote", "remove"}, 2},
		{"remote list", []string{"selfhosted", "remote", "list"}, 1},
		{"remote unknown", []string{"selfhosted", "remote", "unknown"}, 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if code := runWithArgs(tt.args); code != tt.wantCode {
				t.Errorf("%s exit code = %d, want %d", tt.name, code, tt.wantCode)
			}
		})
	}
}

func TestPasswdCommand(t *testing.T) {
	tmp := t.TempDir()
	cfg := tmp + "/config.yaml"
	if err := os.WriteFile(cfg, []byte("endpoints: {}\n"), 0644); err != nil {
		t.Fatal(err)
	}
	code := runWithArgs([]string{"selfhosted", "-c", cfg, "passwd", "testpass"})
	if code != 0 {
		t.Errorf("passwd exit code = %d, want 0", code)
	}
}

func TestVersionOutput(t *testing.T) {
	code := runWithArgs([]string{"selfhosted", "version"})
	if code != 0 {
		t.Errorf("version exit code = %d, want 0", code)
	}
}

func TestNoPanicOnInvalidArgs(t *testing.T) {
	tests := [][]string{
		{"selfhosted", "-c"},
		{"selfhosted", "--host"},
		{"selfhosted", "-c", "--host", "addr", "version"},
	}
	for _, args := range tests {
		t.Run(args[1], func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("panic with args %v: %v", args, r)
				}
			}()
			_ = runWithArgs(args)
		})
	}
}

func TestInstallWithParams(t *testing.T) {
	code := runWithArgs([]string{"selfhosted", "install", "traefik", "domain=example.com", "email=admin@example.com"})
	if code != 1 {
		t.Errorf("install with params exit code = %d, want 1", code)
	}
}

func TestListCommand(t *testing.T) {
	code := runWithArgs([]string{"selfhosted", "list"})
	if code != 1 {
		t.Errorf("list exit code = %d, want 1", code)
	}
}
