package logger

import "go.uber.org/zap"

type Logger interface {
	Info(msg string, fields ...Field)
	Warn(msg string, fields ...Field)
	Error(msg string, fields ...Field)
	With(fields ...Field) Logger
	Sync() error
}

type Field struct {
	key   string
	value interface{}
}

func NewNop() Logger {
	return &nopLogger{}
}

type nopLogger struct{}

func (n *nopLogger) Info(msg string, fields ...Field) {}
func (n *nopLogger) Warn(msg string, fields ...Field) {}
func (n *nopLogger) Error(msg string, fields ...Field) {}
func (n *nopLogger) With(fields ...Field) Logger       { return n }
func (n *nopLogger) Sync() error                       { return nil }

func toZapFields(fields []Field) []zap.Field {
	zf := make([]zap.Field, 0, len(fields))
	for _, f := range fields {
		zf = append(zf, zap.Any(f.key, f.value))
	}
	return zf
}
