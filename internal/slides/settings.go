package slides

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type Settings struct {
	Folder      string `json:"folder"`
	Layout      string `json:"layout"`
	Order       string `json:"order"`
	Descending  bool   `json:"descending"`
	PerDeck     int    `json:"perDeck"`
	Interval    int    `json:"intervalSeconds"`
	Crop        bool   `json:"crop"`
	Fullscreen  bool   `json:"fullscreen"`
	ShuffleSeed uint64 `json:"shuffleSeed"`
	FrameStyle  string `json:"frameStyle"`
	FrameSize   string `json:"frameSize"`
	Transition  string `json:"transition"`
}

func defaultSettings() Settings {
	return Settings{Layout: "single", Order: "name", PerDeck: 5, Interval: 8, ShuffleSeed: 1, FrameStyle: "white", FrameSize: "medium", Transition: "fade"}
}

func settingsPath() string {
	base, err := os.UserConfigDir()
	if err != nil {
		return "slideit.json"
	}
	return filepath.Join(base, "slideit", "settings.json")
}

func loadSettings() Settings {
	settings := defaultSettings()
	data, err := os.ReadFile(settingsPath())
	if err == nil {
		_ = json.Unmarshal(data, &settings)
	}
	if settings.Layout != "single" && settings.Layout != "grid" && settings.Layout != "montage" {
		settings.Layout = "single"
	}
	if settings.Order != "name" && settings.Order != "created" && settings.Order != "modified" && settings.Order != "random" {
		settings.Order = "name"
	}
	settings.PerDeck = clamp(settings.PerDeck, 1, 12)
	settings.Interval = clamp(settings.Interval, 2, 60)
	if settings.ShuffleSeed == 0 {
		settings.ShuffleSeed = 1
	}
	if settings.FrameStyle != "none" && settings.FrameStyle != "white" && settings.FrameStyle != "black" && settings.FrameStyle != "aged" {
		settings.FrameStyle = "white"
	}
	if settings.FrameSize != "thin" && settings.FrameSize != "medium" && settings.FrameSize != "thick" {
		settings.FrameSize = "medium"
	}
	if settings.Transition != "none" && settings.Transition != "fade" && settings.Transition != "slide" && settings.Transition != "zoom" && settings.Transition != "tilt" {
		settings.Transition = "fade"
	}
	return settings
}

func saveSettings(settings Settings) error {
	path := settingsPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0o644)
}

func clamp(value, low, high int) int {
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}
