package slides

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseTOMLPreservesHexColors(t *testing.T) {
	path := filepath.Join(t.TempDir(), "colors.toml")
	if err := os.WriteFile(path, []byte("accent = \"#aabbcc\"\n[popup]\nbackground = '#112233'\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	values := map[string]string{}
	parseTOML(path, values)
	if values["accent"] != "#aabbcc" {
		t.Fatalf("accent = %q", values["accent"])
	}
	if values["popup.background"] != "#112233" {
		t.Fatalf("popup background = %q", values["popup.background"])
	}
}
