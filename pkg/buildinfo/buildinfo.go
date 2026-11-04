// Package buildinfo holds the build metadata stamped in at link time with
// -ldflags -X. The defaults identify an unstamped build.
package buildinfo

var (
	// Version is the release version without the leading v, or "dev".
	Version = "dev"
	// Commit is the short commit hash the binary was built from.
	Commit = "none"
	// Date is the commit date the binary was built from.
	Date = "unknown"
)
