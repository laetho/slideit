//go:build windows

package slides

import (
	"syscall"
	"time"
)

func birthTime(path string) (time.Time, bool) {
	pointer, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return time.Time{}, false
	}
	handle, err := syscall.CreateFile(pointer, 0, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE|syscall.FILE_SHARE_DELETE, nil, syscall.OPEN_EXISTING, syscall.FILE_FLAG_BACKUP_SEMANTICS, 0)
	if err != nil {
		return time.Time{}, false
	}
	defer syscall.CloseHandle(handle)
	var info syscall.ByHandleFileInformation
	if err := syscall.GetFileInformationByHandle(handle, &info); err != nil {
		return time.Time{}, false
	}
	return time.Unix(0, info.CreationTime.Nanoseconds()), true
}
