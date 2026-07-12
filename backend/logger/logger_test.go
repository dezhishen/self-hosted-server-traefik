package logger

import (
	"testing"
)

func TestNopLogger(t *testing.T) {
	l := NewNop()
	l.Info("test", String("key", "val"))
	l.Warn("test")
	l.Error("test")
	l.With(String("k", "v"))
	l.Sync()
}

func TestLogMethodsDontPanic(t *testing.T) {
	l := InitLogger(t.TempDir())
	l.Info("info msg", String("key", "val"))
	l.Warn("warn msg", Int("n", 1))
	l.Error("error msg", Any("any", struct{}{}))
}

func TestWithCreatesChild(t *testing.T) {
	l := InitLogger(t.TempDir())
	child := l.With(String("trace", "abc"))
	child.Info("child log")
	l.Info("parent log")
}

func TestSyncDoesntPanic(t *testing.T) {
	l := InitLogger(t.TempDir())
	if err := l.Sync(); err != nil {
		t.Logf("Sync() returned error: %v", err)
	}
}

func TestFieldConstructors(t *testing.T) {
	_ = String("k", "v")
	_ = Error(nil)
	_ = Int("n", 42)
	_ = Any("a", "b")
}
