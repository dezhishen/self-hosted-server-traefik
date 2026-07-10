package main

import (
	"embed"
	"io/fs"
)

//go:embed web/dist
var webFS embed.FS

func frontendFS() (fs.FS, error) {
	return fs.Sub(webFS, "web/dist")
}
