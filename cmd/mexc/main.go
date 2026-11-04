// Command mexc-rehearsal is the smallest program the release pipeline can
// carry: it reports its build and greets.
package main

import (
	"fmt"
	"os"
	"runtime"

	"github.com/OVELLIC-com/test/pkg/buildinfo"
)

func main() {
	if len(os.Args) > 1 && (os.Args[1] == "--version" || os.Args[1] == "version") {
		fmt.Printf("mexc-rehearsal version %s (commit %s, built %s)\n", buildinfo.Version, buildinfo.Commit, buildinfo.Date)
		return
	}
	fmt.Printf("hello from %s/%s\n", runtime.GOOS, runtime.GOARCH)
}
