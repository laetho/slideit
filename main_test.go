package main

import (
	"path/filepath"
	"testing"
)

func TestFolderArgument(t *testing.T) {
	got := folderArgument([]string{"pictures"})
	want, err := filepath.Abs("pictures")
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Fatalf("folderArgument() = %q, want %q", got, want)
	}
}

func TestFolderArgumentEmpty(t *testing.T) {
	if got := folderArgument([]string{"--fullscreen"}); got != "" {
		t.Fatalf("folderArgument() = %q, want empty", got)
	}
}
