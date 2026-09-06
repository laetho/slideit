package slides

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestScanFiltersImages(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"one.JPG", "two.png", "notes.txt"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("test"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	images, err := Scan(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(images) != 2 {
		t.Fatalf("got %d images, want 2", len(images))
	}
}

func TestOrderByNameAndCreatedFallback(t *testing.T) {
	now := time.Now()
	images := []Image{
		{Name: "z.jpg", Modified: now.Add(-time.Hour)},
		{Name: "A.jpg", Modified: now},
	}
	byName := Order(images, "name", false, 1)
	if byName[0].Name != "A.jpg" {
		t.Fatalf("first by name = %s", byName[0].Name)
	}
	byCreated := Order(images, "created", false, 1)
	if byCreated[0].Name != "z.jpg" {
		t.Fatalf("creation fallback did not use modified time")
	}
}

func TestRandomOrderIsStableForSeed(t *testing.T) {
	images := []Image{{Name: "a"}, {Name: "b"}, {Name: "c"}, {Name: "d"}}
	first := Order(images, "random", false, 42)
	second := Order(images, "random", false, 42)
	for i := range first {
		if first[i].Name != second[i].Name {
			t.Fatal("shuffle is not stable")
		}
	}
}
