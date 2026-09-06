//go:build darwin

package slides

import (
	"time"

	"golang.org/x/sys/unix"
)

func birthTime(path string) (time.Time, bool) {
	var stat unix.Stat_t
	if err := unix.Stat(path, &stat); err != nil {
		return time.Time{}, false
	}
	return time.Unix(stat.Birthtimespec.Sec, stat.Birthtimespec.Nsec), true
}
