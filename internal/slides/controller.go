package slides

import (
	"fmt"
	"math"
	"net/url"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/qml"
)

type Controller struct {
	state        *qml.QQmlPropertyMap
	settings     Settings
	images       []Image
	ordered      []Image
	deck         []Image
	deckIndex    int
	deckRevision int
	scanResults  chan scanResult
	scanRequest  uint64
	timer        *qt.QTimer
	themeTimer   *qt.QTimer
	themeStamp   string
	published    map[string]any
}

type scanResult struct {
	request uint64
	folder  string
	images  []Image
	err     error
}

func NewController(initialFolder string) (*Controller, error) {
	c := &Controller{settings: loadSettings(), scanResults: make(chan scanResult, 8), published: make(map[string]any)}
	c.state = qml.NewQQmlPropertyMap()
	c.publishTheme()
	c.publishState("")
	c.publishDeck()
	c.publishNextDeck()
	c.insert("command", "")
	c.state.OnValueChanged(c.onValueChanged)

	c.timer = qt.NewQTimer()
	c.timer.SetInterval(50)
	c.timer.OnTimeout(c.poll)
	c.timer.Start2()
	c.themeTimer = qt.NewQTimer()
	c.themeTimer.SetInterval(1500)
	c.themeTimer.OnTimeout(c.refreshTheme)
	c.themeTimer.Start2()

	if initialFolder != "" {
		c.scan(initialFolder)
	} else if c.settings.Folder != "" {
		c.scan(c.settings.Folder)
	}
	return c, nil
}

func (c *Controller) State() *qml.QQmlPropertyMap { return c.state }

func (c *Controller) Close() {
	_ = saveSettings(c.settings)
}

func (c *Controller) onValueChanged(key string, value *qt.QVariant) {
	if key != "command" {
		return
	}
	action, argument := parseCommand(value.ToString())
	if action == "" {
		return
	}
	settingsChanged := false
	switch action {
	case "folder":
		if parsed, err := url.Parse(argument); err == nil && parsed.Scheme == "file" {
			argument = parsed.Path
		}
		c.scan(argument)
	case "next":
		c.move(1)
	case "previous":
		c.move(-1)
	case "first":
		c.deckIndex = 0
		c.updateDeck()
	case "last":
		c.deckIndex = max(0, c.deckCount()-1)
		c.updateDeck()
	case "layout":
		c.setLayout(argument)
		settingsChanged = true
	case "cycle-layout":
		c.cycleLayout()
		settingsChanged = true
	case "order":
		c.setOrder(argument)
		settingsChanged = true
	case "cycle-order":
		c.cycleOrder()
		settingsChanged = true
	case "reverse":
		c.settings.Descending = !c.settings.Descending
		c.reorder(true)
		settingsChanged = true
	case "count":
		if n, err := strconv.Atoi(argument); err == nil {
			c.settings.PerDeck = clamp(n, 1, 12)
			c.updateDeck()
			settingsChanged = true
		}
	case "interval":
		if n, err := strconv.Atoi(argument); err == nil {
			c.settings.Interval = clamp(n, 2, 60)
			c.publishState("")
			settingsChanged = true
		}
	case "crop":
		c.settings.Crop = !c.settings.Crop
		c.publishState("")
		settingsChanged = true
	case "frame":
		c.setFrameStyle(argument)
		settingsChanged = true
	case "cycle-frame":
		styles := []string{"none", "white", "aged", "black"}
		c.setFrameStyle(styles[(indexOf(styles, c.settings.FrameStyle)+1)%len(styles)])
		settingsChanged = true
	case "frame-size":
		if argument == "thin" || argument == "medium" || argument == "thick" {
			c.settings.FrameSize = argument
			c.publishState("")
			settingsChanged = true
		}
	case "transition":
		c.setTransition(argument)
		settingsChanged = true
	case "cycle-transition":
		transitions := []string{"none", "fade", "slide", "zoom", "tilt"}
		c.setTransition(transitions[(indexOf(transitions, c.settings.Transition)+1)%len(transitions)])
		settingsChanged = true
	case "fullscreen":
		c.settings.Fullscreen = argument == "true"
		c.publishState("")
		settingsChanged = true
	case "refresh":
		c.scan(c.settings.Folder)
	}
	if settingsChanged {
		_ = saveSettings(c.settings)
	}
}

func (c *Controller) setFrameStyle(style string) {
	if style == "none" || style == "white" || style == "black" || style == "aged" {
		c.settings.FrameStyle = style
		c.publishState("")
	}
}

func (c *Controller) setTransition(transition string) {
	if transition == "none" || transition == "fade" || transition == "slide" || transition == "zoom" || transition == "tilt" {
		c.settings.Transition = transition
		c.publishState("")
	}
}

func parseCommand(command string) (action, argument string) {
	parts := strings.SplitN(command, "|", 3)
	if len(parts) == 0 {
		return "", ""
	}
	action = parts[0]
	if len(parts) > 1 {
		argument = parts[1]
	}
	return action, argument
}

func (c *Controller) scan(folder string) {
	if folder == "" {
		return
	}
	c.insert("loading", true)
	c.scanRequest++
	request := c.scanRequest
	go func() {
		images, err := Scan(folder)
		c.scanResults <- scanResult{request: request, folder: folder, images: images, err: err}
	}()
}

func (c *Controller) poll() {
	select {
	case result := <-c.scanResults:
		if result.request != c.scanRequest {
			return
		}
		c.insert("loading", false)
		if result.err != nil {
			c.insert("message", result.err.Error())
			return
		}
		c.settings.Folder = result.folder
		c.images = result.images
		c.deckIndex = 0
		c.reorder(false)
		_ = saveSettings(c.settings)
	default:
	}
}

func (c *Controller) reorder(preserve bool) {
	current := ""
	if preserve && len(c.deck) > 0 {
		current = c.deck[0].Path
	}
	c.ordered = Order(c.images, c.settings.Order, c.settings.Descending, c.settings.ShuffleSeed)
	if current != "" {
		for i := range c.ordered {
			if c.ordered[i].Path == current {
				c.deckIndex = i / c.effectivePerDeck()
				break
			}
		}
	}
	c.updateDeck()
}

func (c *Controller) updateDeck() {
	count := c.deckCount()
	if count == 0 {
		c.deckIndex = 0
	} else {
		c.deckIndex = ((c.deckIndex % count) + count) % count
	}
	start := c.deckIndex * c.effectivePerDeck()
	end := min(len(c.ordered), start+c.effectivePerDeck())
	if start < len(c.ordered) {
		c.deck = c.ordered[start:end]
	} else {
		c.deck = nil
	}
	c.publishDeck()
	c.publishNextDeck()
	c.publishState("")
	c.deckRevision++
	c.insert("deckRevision", c.deckRevision)
}

func (c *Controller) publishDeck() {
	c.state.Insert("deck", deckVariant(c.deck, c.deckIndex))
}

func (c *Controller) publishNextDeck() {
	if c.deckCount() == 0 {
		c.state.Insert("nextDeck", qt.NewQVariant43(nil))
		return
	}
	nextIndex := (c.deckIndex + 1) % c.deckCount()
	start := nextIndex * c.effectivePerDeck()
	end := min(len(c.ordered), start+c.effectivePerDeck())
	c.state.Insert("nextDeck", deckVariant(c.ordered[start:end], nextIndex))
}

func deckVariant(deck []Image, deckIndex int) *qt.QVariant {
	items := make([]qt.QVariant, 0, len(deck))
	for index, image := range deck {
		item := map[string]qt.QVariant{
			"source":  *qt.NewQVariant14(fileURL(image.Path)),
			"name":    *qt.NewQVariant14(image.Name),
			"angle":   *qt.NewQVariant9(montageAngle(deckIndex, index)),
			"offsetX": *qt.NewQVariant9(montageOffset(deckIndex, index, 17)),
			"offsetY": *qt.NewQVariant9(montageOffset(deckIndex, index, 31)),
		}
		items = append(items, *qt.NewQVariant20(item))
	}
	return qt.NewQVariant43(items)
}

func (c *Controller) move(delta int) {
	if c.deckCount() > 0 {
		c.deckIndex += delta
		c.updateDeck()
	}
}
func (c *Controller) effectivePerDeck() int {
	if c.settings.Layout == "single" {
		return 1
	}
	return c.settings.PerDeck
}
func (c *Controller) deckCount() int {
	if len(c.ordered) == 0 {
		return 0
	}
	return int(math.Ceil(float64(len(c.ordered)) / float64(c.effectivePerDeck())))
}

func (c *Controller) setLayout(layout string) {
	if layout == "single" || layout == "grid" || layout == "montage" {
		c.settings.Layout = layout
		c.deckIndex = 0
		c.updateDeck()
	}
}
func (c *Controller) cycleLayout() {
	modes := []string{"single", "grid", "montage"}
	c.settings.Layout = modes[(indexOf(modes, c.settings.Layout)+1)%len(modes)]
	c.deckIndex = 0
	c.updateDeck()
}
func (c *Controller) setOrder(order string) {
	if order == "name" || order == "created" || order == "modified" || order == "random" {
		c.settings.Order = order
		if order == "random" {
			c.settings.ShuffleSeed++
		}
		c.deckIndex = 0
		c.reorder(false)
	}
}
func (c *Controller) cycleOrder() {
	modes := []string{"name", "created", "modified", "random"}
	c.setOrder(modes[(indexOf(modes, c.settings.Order)+1)%len(modes)])
}

func (c *Controller) publishState(message string) {
	c.insert("folder", c.settings.Folder)
	c.insert("folderName", filepath.Base(c.settings.Folder))
	c.insert("layout", c.settings.Layout)
	c.insert("order", c.settings.Order)
	c.insert("descending", c.settings.Descending)
	c.insert("perDeck", c.settings.PerDeck)
	c.insert("interval", c.settings.Interval)
	c.insert("crop", c.settings.Crop)
	c.insert("frameStyle", c.settings.FrameStyle)
	c.insert("frameSize", c.settings.FrameSize)
	c.insert("transition", c.settings.Transition)
	c.insert("fullscreen", c.settings.Fullscreen)
	c.insert("imageCount", len(c.ordered))
	c.insert("deckIndex", c.deckIndex)
	c.insert("deckCount", c.deckCount())
	c.insert("message", message)
}

func (c *Controller) publishTheme() {
	stamp := themeSignature()
	if stamp != "" && stamp == c.themeStamp {
		return
	}
	theme := loadTheme()
	c.themeStamp = stamp
	c.insert("background", theme.Background)
	c.insert("foreground", theme.Foreground)
	c.insert("accent", theme.Accent)
	c.insert("surface", theme.Surface)
	c.insert("border", theme.Border)
	c.insert("muted", theme.Muted)
	c.insert("error", theme.Error)
}

func (c *Controller) refreshTheme() {
	c.publishTheme()
}

func (c *Controller) insert(key string, value any) {
	if previous, ok := c.published[key]; ok && reflect.DeepEqual(previous, value) {
		return
	}
	c.published[key] = value
	var variant *qt.QVariant
	switch typed := value.(type) {
	case string:
		variant = qt.NewQVariant14(typed)
	case bool:
		variant = qt.NewQVariant8(typed)
	case int:
		variant = qt.NewQVariant4(typed)
	default:
		variant = qt.NewQVariant14(fmt.Sprint(typed))
	}
	c.state.Insert(key, variant)
}

func fileURL(path string) string           { return (&url.URL{Scheme: "file", Path: path}).String() }
func montageAngle(deck, index int) float64 { return montageOffset(deck, index, 7) * 0.08 }
func montageOffset(deck, index, salt int) float64 {
	value := (deck*37 + index*53 + salt*19) % 101
	return float64(value-50) / 2.5
}
func indexOf(values []string, needle string) int {
	for i, value := range values {
		if value == needle {
			return i
		}
	}
	return 0
}
