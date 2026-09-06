package slides

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

type Theme struct {
	Background string
	Foreground string
	Accent     string
	Surface    string
	Border     string
	Muted      string
	Error      string
}

func defaultTheme() Theme {
	return Theme{Background: "#0f111a", Foreground: "#d8dee9", Accent: "#7aa2f7", Surface: "#cc1a1b26", Border: "#667aa2f7", Muted: "#9aa5b1", Error: "#f7768e"}
}

func loadTheme() Theme {
	theme := defaultTheme()
	home, err := os.UserHomeDir()
	if err != nil {
		return theme
	}
	values := map[string]string{}
	parseTOML(filepath.Join(home, ".local/state/omarchy/current/theme/colors.toml"), values)
	parseTOML(filepath.Join(home, ".local/state/omarchy/current/theme/shell.toml"), values)
	parseTOML(filepath.Join(home, ".config/omarchy/shell.toml"), values)
	theme.Background = pick(values, theme.Background, "background", "base.background")
	theme.Foreground = pick(values, theme.Foreground, "foreground", "base.foreground")
	theme.Accent = pick(values, theme.Accent, "accent", "base.accent")
	theme.Error = pick(values, theme.Error, "red", "error")
	theme.Muted = pick(values, theme.Muted, "muted", "inactive", "bright-black")
	theme.Surface = withAlpha(pick(values, "#1a1b26", "surface", "popup.background", "bar.background"), "e6")
	theme.Border = withAlpha(pick(values, theme.Accent, "border", "popup.border", "bar.border"), "99")
	return theme
}

func parseTOML(path string, values map[string]string) {
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()
	section := ""
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.TrimSpace(line[1 : len(line)-1])
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.Trim(strings.TrimSpace(parts[1]), "\"'")
		if section != "" {
			values[section+"."+key] = value
		}
		values[key] = value
	}
}

func pick(values map[string]string, fallback string, keys ...string) string {
	for _, key := range keys {
		if value := values[key]; strings.HasPrefix(value, "#") {
			return value
		}
	}
	return fallback
}

func withAlpha(color, alpha string) string {
	if len(color) == 7 {
		return "#" + alpha + color[1:]
	}
	return color
}
