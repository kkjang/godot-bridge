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

func TestBuildSpecIncludesGameScreenshot(t *testing.T) {
	spec := buildSpec()
	for _, cmd := range spec.Commands {
		if cmd.Usage != "godot-bridge game screenshot [--out FILE]" {
			continue
		}
		if cmd.PluginCommand != "game_screenshot" {
			t.Fatalf("game screenshot plugin command = %q, want %q", cmd.PluginCommand, "game_screenshot")
		}
		return
	}
	t.Fatal("game screenshot command missing from spec")
}

func TestBuildSpecIncludesSpriteFramesModify(t *testing.T) {
	spec := buildSpec()
	for _, cmd := range spec.Commands {
		if cmd.Usage != "godot-bridge sprite-frames modify PATH --data JSON [--mode merge|replace]" {
			continue
		}
		if cmd.PluginCommand != "sprite_frames_modify" {
			t.Fatalf("sprite-frames modify plugin command = %q, want %q", cmd.PluginCommand, "sprite_frames_modify")
		}
		return
	}
	t.Fatal("sprite-frames modify command missing from spec")
}

func TestBuildSpecIncludesSpriteFramesFromManifest(t *testing.T) {
	spec := buildSpec()
	for _, cmd := range spec.Commands {
		if cmd.Usage != "godot-bridge sprite-frames from-manifest --sheet res://sheet.png --manifest PATH --out res://frames.tres [--node PATH] [--default-fps N]" {
			continue
		}
		if cmd.PluginCommand != "sprite_frames_from_manifest" {
			t.Fatalf("sprite-frames from-manifest plugin command = %q, want %q", cmd.PluginCommand, "sprite_frames_from_manifest")
		}
		return
	}
	t.Fatal("sprite-frames from-manifest command missing from spec")
}
