package logger

import (
	"os"
	"path/filepath"
	"runtime"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
)

type zapAdapter struct {
	z *zap.Logger
}

// log writes a message at the given level, capturing the caller
// at the direct call site using runtime.Caller — no hardcoded skip needed.
func (a *zapAdapter) log(level zapcore.Level, msg string, fields ...Field) {
	ce := a.z.Check(level, msg)
	if ce == nil {
		return
	}
	// Capture caller: runtime.Caller(0) = this method, Caller(1) = the adapter method, Caller(2) = actual call site
	if pc, file, line, ok := runtime.Caller(2); ok {
		ce.Caller = zapcore.EntryCaller{
			Defined:  true,
			PC:       pc,
			File:     file,
			Line:     line,
		}
	}
	ce.Write(toZapFields(fields)...)
}

func (a *zapAdapter) Debug(msg string, fields ...Field) {
	a.log(zapcore.DebugLevel, msg, fields...)
}

func (a *zapAdapter) Info(msg string, fields ...Field) {
	a.log(zapcore.InfoLevel, msg, fields...)
}

func (a *zapAdapter) Warn(msg string, fields ...Field) {
	a.log(zapcore.WarnLevel, msg, fields...)
}

func (a *zapAdapter) Error(msg string, fields ...Field) {
	a.log(zapcore.ErrorLevel, msg, fields...)
}

func (a *zapAdapter) With(fields ...Field) Logger {
	return &zapAdapter{z: a.z.With(toZapFields(fields)...)}
}

func (a *zapAdapter) Sync() error {
	return a.z.Sync()
}

func InitLogger(baseDir string) Logger {
	logDir := filepath.Join(baseDir, "logs")
	os.MkdirAll(logDir, 0755)

	writer := &lumberjack.Logger{
		Filename:   filepath.Join(logDir, "selfhosted.log"),
		MaxSize:    100,
		MaxAge:     30,
		MaxBackups: 10,
		Compress:   true,
	}

	zc := zapcore.NewCore(
		zapcore.NewJSONEncoder(zapcore.EncoderConfig{
			TimeKey:        "ts",
			LevelKey:       "level",
			NameKey:        "logger",
			CallerKey:      "caller",
			MessageKey:     "msg",
			StacktraceKey:  "stacktrace",
			LineEnding:     zapcore.DefaultLineEnding,
			EncodeLevel:    zapcore.LowercaseLevelEncoder,
			EncodeTime:     zapcore.ISO8601TimeEncoder,
			EncodeDuration: zapcore.SecondsDurationEncoder,
			EncodeCaller:   zapcore.ShortCallerEncoder,
		}),
		zapcore.NewMultiWriteSyncer(
			zapcore.AddSync(writer),
			zapcore.AddSync(os.Stdout),
		),
		zap.NewAtomicLevelAt(zap.InfoLevel),
	)

	z := zap.New(zc, zap.AddStacktrace(zapcore.ErrorLevel))
	zap.ReplaceGlobals(z)
	return &zapAdapter{z: z}
}

func NewZapForConfig() *zap.Logger {
	cfg := zap.NewProductionConfig()
	cfg.Level.SetLevel(zap.InfoLevel)
	z, _ := cfg.Build()
	return z
}
