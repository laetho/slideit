//go:build linux

package slides

import (
	"time"

	"golang.org/x/sys/unix"
)

func birthTime(path string) (time.Time, bool) {
	var stat unix.Statx_t
	err := unix.Statx(unix.AT_FDCWD, path, unix.AT_STATX_SYNC_AS_STAT, unix.STATX_BTIME, &stat)
	if err != nil || stat.Mask&unix.STATX_BTIME == 0 {
		return time.Time{}, false
	}
	return time.Unix(stat.Btime.Sec, int64(stat.Btime.Nsec)), true
}
