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

func TestBuildSpecIncludesResourceReimport(t *testing.T) {
	spec := buildSpec()
	for _, cmd := range spec.Commands {
		if cmd.Usage != "godot-bridge resource reimport [PATH]" {
			continue
		}
		if cmd.PluginCommand != "resource_reimport" {
			t.Fatalf("resource reimport plugin command = %q, want %q", cmd.PluginCommand, "resource_reimport")
		}
		return
	}
	t.Fatal("resource reimport command missing from spec")
}
