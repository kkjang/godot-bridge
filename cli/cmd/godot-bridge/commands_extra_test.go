package main

import (
	"os"
	"reflect"
	"strings"
	"testing"
)

func TestParseCSVListNormalizesAndDeduplicates(t *testing.T) {
	got := parseCSVList(" output,error, output , ,error ")
	want := []string{"output", "error"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseCSVList() = %#v, want %#v", got, want)
	}
}

func TestBuildProjectGetPayloadOmitsEmptyFields(t *testing.T) {
	got := buildProjectGetPayload("display/window/size/viewport_width,input/jump", "")
	keys, ok := got["keys"].([]string)
	if !ok {
		t.Fatalf("keys missing or wrong type: %#v", got)
	}
	want := []string{"display/window/size/viewport_width", "input/jump"}
	if !reflect.DeepEqual(keys, want) {
		t.Fatalf("keys = %#v, want %#v", keys, want)
	}
	if _, ok := got["prefix"]; ok {
		t.Fatalf("unexpected prefix in payload: %#v", got)
	}
}

func TestBuildAnimationPayloadProtectsPathAndRequiresName(t *testing.T) {
	payload, err := buildAnimationPayload("/root/Main/AnimationPlayer", "", `{"path":"ignored","name":"walk","length":1.0}`)
	if err != nil {
		t.Fatalf("buildAnimationPayload() error = %v", err)
	}
	if got := payload["path"]; got != "/root/Main/AnimationPlayer" {
		t.Fatalf("path = %#v, want root path", got)
	}
	if got := payload["name"]; got != "walk" {
		t.Fatalf("name = %#v, want walk", got)
	}

	if _, err := buildAnimationPayload("/root/Main/AnimationPlayer", "", `{"length":1.0}`); err == nil {
		t.Fatal("expected missing animation name error")
	}
}

func TestBuildSpriteFramesFromManifestPayloadRejectsHostSheetPaths(t *testing.T) {
	_, err := buildSpriteFramesFromManifestPayload("/tmp/hero.png", "res://art/hero_frames.tres", []byte(`{"version":1,"frames":[]}`), "", 10)
	if err == nil {
		t.Fatal("expected host sheet path error")
	}
	if !strings.Contains(err.Error(), "place the file inside the Godot project first") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestBuildSpriteFramesFromManifestPayloadBuildsExpectedShape(t *testing.T) {
	payload, err := buildSpriteFramesFromManifestPayload(
		"res://art/hero.png",
		"res://art/hero_frames.tres",
		[]byte(`{"version":1,"sheet":"hero.png","sheet_size":{"w":256,"h":64},"frames":[{"name":"idle_0","x":0,"y":0,"w":32,"h":32,"duration_ms":100,"tag":"idle"}]}`),
		"/root/Main/AnimatedSprite2D",
		10,
	)
	if err != nil {
		t.Fatalf("buildSpriteFramesFromManifestPayload() error = %v", err)
	}
	want := map[string]any{
		"sheet_path":  "res://art/hero.png",
		"out_path":    "res://art/hero_frames.tres",
		"node_path":   "/root/Main/AnimatedSprite2D",
		"default_fps": 10.0,
		"manifest": map[string]any{
			"version": 1.0,
			"sheet":   "hero.png",
			"sheet_size": map[string]any{
				"w": 256.0,
				"h": 64.0,
			},
			"frames": []any{
				map[string]any{
					"name":        "idle_0",
					"x":           0.0,
					"y":           0.0,
					"w":           32.0,
					"h":           32.0,
					"duration_ms": 100.0,
					"tag":         "idle",
				},
			},
		},
	}
	if !reflect.DeepEqual(payload, want) {
		t.Fatalf("payload = %#v, want %#v", payload, want)
	}
}

func TestRunSpriteFramesFromManifestRequiresSheet(t *testing.T) {
	cfg := config{stderr: os.Stderr}
	err := runSpriteFrames(cfg, []string{"from-manifest", "--manifest", "hero.json", "--out", "res://art/hero_frames.tres"})
	if err == nil {
		t.Fatal("expected missing sheet usage error")
	}
	if !strings.Contains(err.Error(), "usage: godot-bridge sprite-frames from-manifest") {
		t.Fatalf("unexpected error: %v", err)
	}
}
