package template

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"text/template"
	"time"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *Engine implements contracts.TemplateEngine.
var _ contracts.TemplateEngine = (*Engine)(nil)

type Engine struct {
	funcs template.FuncMap
}

func NewEngine() *Engine {
	return &Engine{
		funcs: template.FuncMap{
			"now":      time.Now,
			"date":     func(layout string) string { return time.Now().Format(layout) },
			"env":      os.Getenv,
			"join":     strings.Join,
			"split":    strings.Split,
			"contains": strings.Contains,
			"has":      strings.Contains,
			"upper":    strings.ToUpper,
			"lower":    strings.ToLower,
			"title":    strings.Title,
			"quote":    func(s string) string { return `"` + s + `"` },
			"default": func(def, val interface{}) interface{} {
				if val == nil || val == "" {
					return def
				}
				return val
			},
		},
	}
}

func (e *Engine) RenderString(tmpl string, data *contracts.TemplateData) (string, error) {
	t, err := template.New("render").Funcs(e.funcs).Parse(tmpl)
	if err != nil {
		return "", fmt.Errorf("parse template: %w", err)
	}
	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("execute template: %w", err)
	}
	return buf.String(), nil
}

func (e *Engine) RenderFile(path string, data *contracts.TemplateData) (string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return e.RenderString(string(content), data)
}

func (e *Engine) RenderFS(files map[string]string, data *contracts.TemplateData) (map[string]string, error) {
	result := make(map[string]string, len(files))
	for name, content := range files {
		out, err := e.RenderString(content, data)
		if err != nil {
			return nil, fmt.Errorf("render %s: %w", name, err)
		}
		result[name] = out
	}
	return result, nil
}

func (e *Engine) RenderFSFromDir(fsys fs.FS, pattern string, data *contracts.TemplateData) (map[string]string, error) {
	files := make(map[string]string)
	if err := fs.WalkDir(fsys, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		match, err := filepath.Match(pattern, path)
		if err != nil || !match {
			return nil
		}
		content, err := fs.ReadFile(fsys, path)
		if err != nil {
			return err
		}
		files[path] = string(content)
		return nil
	}); err != nil {
		return nil, err
	}
	return e.RenderFS(files, data)
}
