package main

import (
	"reflect"
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
