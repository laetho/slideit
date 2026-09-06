package main

import (
	"embed"
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/qml"

	"slideit/internal/slides"
)

//go:embed qml/Main.qml
var qmlFiles embed.FS

func main() {
	runtime.LockOSThread()

	// Request multisampling before Qt creates the window/rendering backend. QML
	// layer.samples alone cannot guarantee an MSAA-capable render target.
	format := qt.NewQSurfaceFormat()
	format.SetSamples(4)
	qt.QSurfaceFormat_SetDefaultFormat(format)

	qt.NewQApplication(os.Args)
	qt.QCoreApplication_SetOrganizationName("Slideit")
	qt.QCoreApplication_SetApplicationName("Slideit")
	qt.QGuiApplication_SetApplicationDisplayName("Slideit")

	controller, err := slides.NewController(folderArgument(os.Args[1:]))
	if err != nil {
		fmt.Fprintln(os.Stderr, "slideit:", err)
		os.Exit(1)
	}
	defer controller.Close()

	engine := qml.NewQQmlApplicationEngine()
	engine.OnWarnings(func(warnings []qml.QQmlError) {
		for i := range warnings {
			fmt.Fprintln(os.Stderr, "slideit qml:", warnings[i].ToString())
		}
	})
	engine.RootContext().SetContextProperty("slideit", controller.State().QObject)

	mainQML, err := qmlFiles.ReadFile("qml/Main.qml")
	if err != nil {
		fmt.Fprintln(os.Stderr, "slideit:", err)
		os.Exit(1)
	}
	engine.LoadData(mainQML)
	if len(engine.RootObjects()) == 0 {
		fmt.Fprintln(os.Stderr, "slideit: QML failed to create the main window")
		os.Exit(1)
	}

	qt.QApplication_Exec()
}

func folderArgument(arguments []string) string {
	if len(arguments) == 0 || arguments[0] == "" || arguments[0][0] == '-' {
		return ""
	}
	folder, err := filepath.Abs(arguments[0])
	if err != nil {
		return arguments[0]
	}
	return folder
}
