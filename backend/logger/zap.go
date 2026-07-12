package logger

import (
	"os"
	"path/filepath"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
)

type zapAdapter struct {
	z *zap.Logger
}

func (a *zapAdapter) Info(msg string, fields ...Field) {
	a.z.Info(msg, toZapFields(fields)...)
}

func (a *zapAdapter) Warn(msg string, fields ...Field) {
	a.z.Warn(msg, toZapFields(fields)...)
}

func (a *zapAdapter) Error(msg string, fields ...Field) {
	a.z.Error(msg, toZapFields(fields)...)
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

	z := zap.New(zc, zap.AddCaller(), zap.AddCallerSkip(1), zap.AddStacktrace(zapcore.ErrorLevel))
	zap.ReplaceGlobals(z)
	return &zapAdapter{z: z}
}

func NewZapForConfig() *zap.Logger {
	cfg := zap.NewProductionConfig()
	cfg.Level.SetLevel(zap.InfoLevel)
	z, _ := cfg.Build()
	return z
}
