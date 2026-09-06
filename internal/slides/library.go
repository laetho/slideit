package slides

import (
	"errors"
	"math/rand/v2"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

type Image struct {
	Path         string
	Name         string
	Modified     time.Time
	Created      time.Time
	HasCreatedAt bool
}

var imageExtensions = map[string]bool{
	".avif": true, ".bmp": true, ".gif": true, ".heic": true, ".heif": true,
	".jpeg": true, ".jpg": true, ".png": true, ".tif": true, ".tiff": true, ".webp": true,
}

func Scan(folder string) ([]Image, error) {
	if folder == "" {
		return nil, nil
	}
	entries, err := os.ReadDir(folder)
	if err != nil {
		return nil, err
	}
	images := make([]Image, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !imageExtensions[strings.ToLower(filepath.Ext(entry.Name()))] {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		path := filepath.Join(folder, entry.Name())
		created, hasCreated := birthTime(path)
		images = append(images, Image{
			Path: path, Name: entry.Name(), Modified: info.ModTime(),
			Created: created, HasCreatedAt: hasCreated,
		})
	}
	return images, nil
}

func Order(images []Image, mode string, descending bool, seed uint64) []Image {
	ordered := slices.Clone(images)
	if mode == "random" {
		rng := rand.New(rand.NewPCG(seed, seed^0x9e3779b97f4a7c15))
		rng.Shuffle(len(ordered), func(i, j int) { ordered[i], ordered[j] = ordered[j], ordered[i] })
		return ordered
	}
	slices.SortStableFunc(ordered, func(a, b Image) int {
		var comparison int
		switch mode {
		case "created":
			at, bt := a.Created, b.Created
			if !a.HasCreatedAt {
				at = a.Modified
			}
			if !b.HasCreatedAt {
				bt = b.Modified
			}
			comparison = at.Compare(bt)
		case "modified":
			comparison = a.Modified.Compare(b.Modified)
		default:
			comparison = strings.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name))
		}
		if comparison == 0 {
			comparison = strings.Compare(a.Name, b.Name)
		}
		if descending {
			return -comparison
		}
		return comparison
	})
	return ordered
}

func ValidateFolder(folder string) error {
	info, err := os.Stat(folder)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return errors.New("selected path is not a directory")
	}
	return nil
}
