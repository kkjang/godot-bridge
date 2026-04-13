package main

import "testing"

func TestBuildSpecUsesBinaryVersion(t *testing.T) {
	previousVersion := version
	version = "v0.1.1"
	defer func() { version = previousVersion }()

	spec := buildSpec()
	if spec.Version != "v0.1.1" {
		t.Fatalf("spec version = %q, want v0.1.1", spec.Version)
	}
}
