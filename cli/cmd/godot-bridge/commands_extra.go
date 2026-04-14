package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"sort"
	"strings"
)

type signalConnection struct {
	Signal string `json:"signal"`
	Target string `json:"target"`
	Method string `json:"method"`
	Flags  int    `json:"flags"`
}

type animationSummary struct {
	Name       string  `json:"name"`
	Length     float64 `json:"length"`
	LoopMode   string  `json:"loop_mode"`
	TrackCount int     `json:"track_count"`
}

type animationKeyframe struct {
	Time  float64 `json:"time"`
	Value any     `json:"value"`
}

type animationTrack struct {
	Path      string              `json:"path"`
	Type      string              `json:"type"`
	Keyframes []animationKeyframe `json:"keyframes"`
}

type animationDetail struct {
	Name     string           `json:"name"`
	Length   float64          `json:"length"`
	LoopMode string           `json:"loop_mode"`
	Tracks   []animationTrack `json:"tracks"`
}

type spriteFramesRegion struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
	W float64 `json:"w"`
	H float64 `json:"h"`
}

type spriteFramesFrame struct {
	Texture  string              `json:"texture"`
	Region   *spriteFramesRegion `json:"region,omitempty"`
	Duration float64             `json:"duration"`
}

type spriteFramesAnimation struct {
	Name   string              `json:"name"`
	Speed  float64             `json:"speed"`
	Loop   bool                `json:"loop"`
	Frames []spriteFramesFrame `json:"frames"`
}

type spriteFramesDetail struct {
	Animations []spriteFramesAnimation `json:"animations"`
}

func runSignal(cfg config, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: godot-bridge signal <connect|disconnect|list> ...")
	}

	switch args[0] {
	case "connect", "disconnect":
		fs := flag.NewFlagSet("signal "+args[0], flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		source := fs.String("source", "", "")
		signalName := fs.String("signal", "", "")
		target := fs.String("target", "", "")
		method := fs.String("method", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "source", "signal", "target", "method")); err != nil {
			return err
		}
		if fs.NArg() != 0 || *source == "" || *signalName == "" || *target == "" || *method == "" {
			return fmt.Errorf("usage: godot-bridge signal %s --source PATH --signal NAME --target PATH --method NAME", args[0])
		}
		command := "signal_" + args[0]
		payload := map[string]any{"source": *source, "signal": *signalName, "target": *target, "method": *method}
		_, data, err := sendCommand(cfg, command, payload)
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		verb := map[string]string{"connect": "connected", "disconnect": "disconnected"}[args[0]]
		_, err = fmt.Fprintf(cfg.stdout, "%s %s.%s -> %s.%s\n", verb, *source, *signalName, *target, *method)
		return err
	case "list":
		if len(args) != 2 {
			return errors.New("usage: godot-bridge signal list PATH")
		}
		_, data, err := sendCommand(cfg, "signal_connections", map[string]any{"path": args[1]})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Connections []signalConnection `json:"connections"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		for _, conn := range payload.Connections {
			if _, err := fmt.Fprintf(cfg.stdout, "- %s -> %s.%s flags=%d\n", conn.Signal, conn.Target, conn.Method, conn.Flags); err != nil {
				return err
			}
		}
		return nil
	default:
		return fmt.Errorf("unknown signal command %q", args[0])
	}
}

func runProject(cfg config, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: godot-bridge project <get|set> ...")
	}

	switch args[0] {
	case "get":
		fs := flag.NewFlagSet("project get", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		keysText := fs.String("keys", "", "")
		prefix := fs.String("prefix", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "keys", "prefix")); err != nil {
			return err
		}
		if fs.NArg() != 0 {
			return errors.New("usage: godot-bridge project get [--keys KEY,...] [--prefix PREFIX]")
		}
		payload := buildProjectGetPayload(*keysText, *prefix)
		if len(payload) == 0 {
			return errors.New("usage: godot-bridge project get [--keys KEY,...] [--prefix PREFIX]")
		}
		_, data, err := sendCommand(cfg, "project_get", payload)
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var resp struct {
			Settings map[string]any `json:"settings"`
		}
		if err := json.Unmarshal(data, &resp); err != nil {
			return err
		}
		keys := make([]string, 0, len(resp.Settings))
		for key := range resp.Settings {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			encoded, err := json.Marshal(resp.Settings[key])
			if err != nil {
				return err
			}
			if _, err := fmt.Fprintf(cfg.stdout, "%s=%s\n", key, encoded); err != nil {
				return err
			}
		}
		return nil
	case "set":
		fs := flag.NewFlagSet("project set", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		settingsText := fs.String("settings", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "settings")); err != nil {
			return err
		}
		if fs.NArg() != 0 || *settingsText == "" {
			return errors.New("usage: godot-bridge project set --settings JSON")
		}
		settings, err := parseJSONObject(*settingsText, "--settings")
		if err != nil {
			return err
		}
		_, data, err := sendCommand(cfg, "project_set", map[string]any{"settings": settings})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var resp struct {
			Updated []string `json:"updated"`
		}
		if err := json.Unmarshal(data, &resp); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "updated %d setting(s)\n", len(resp.Updated))
		return err
	default:
		return fmt.Errorf("unknown project command %q", args[0])
	}
}

func buildProjectGetPayload(keysText string, prefix string) map[string]any {
	payload := map[string]any{}
	if keys := parseCSVList(keysText); len(keys) > 0 {
		payload["keys"] = keys
	}
	if prefix != "" {
		payload["prefix"] = prefix
	}
	return payload
}

func runAnimation(cfg config, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: godot-bridge animation <list|get|new|modify> ...")
	}

	switch args[0] {
	case "list":
		if len(args) != 2 {
			return errors.New("usage: godot-bridge animation list PATH")
		}
		_, data, err := sendCommand(cfg, "animation_list", map[string]any{"path": args[1]})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Animations []animationSummary `json:"animations"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		for _, animation := range payload.Animations {
			if _, err := fmt.Fprintf(cfg.stdout, "- %s len=%.3f loop=%s tracks=%d\n", animation.Name, animation.Length, animation.LoopMode, animation.TrackCount); err != nil {
				return err
			}
		}
		return nil
	case "get":
		fs := flag.NewFlagSet("animation get", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		animationName := fs.String("animation", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "animation")); err != nil {
			return err
		}
		if fs.NArg() != 1 || *animationName == "" {
			return errors.New("usage: godot-bridge animation get PATH --animation NAME")
		}
		_, data, err := sendCommand(cfg, "animation_get", map[string]any{"path": fs.Arg(0), "animation": *animationName})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var detail animationDetail
		if err := json.Unmarshal(data, &detail); err != nil {
			return err
		}
		return printAnimationDetail(cfg, detail)
	case "new":
		fs := flag.NewFlagSet("animation new", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		dataText := fs.String("data", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "data")); err != nil {
			return err
		}
		if fs.NArg() != 1 || *dataText == "" {
			return errors.New("usage: godot-bridge animation new PATH --data JSON")
		}
		payload, err := buildAnimationPayload(fs.Arg(0), "", *dataText)
		if err != nil {
			return err
		}
		_, data, err := sendCommand(cfg, "animation_new", payload)
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var resp struct {
			Name string `json:"name"`
		}
		if err := json.Unmarshal(data, &resp); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "created animation %s\n", resp.Name)
		return err
	case "modify":
		fs := flag.NewFlagSet("animation modify", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		animationName := fs.String("animation", "", "")
		dataText := fs.String("data", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "animation", "data")); err != nil {
			return err
		}
		if fs.NArg() != 1 || *animationName == "" || *dataText == "" {
			return errors.New("usage: godot-bridge animation modify PATH --animation NAME --data JSON")
		}
		payload, err := buildAnimationPayload(fs.Arg(0), *animationName, *dataText)
		if err != nil {
			return err
		}
		_, data, err := sendCommand(cfg, "animation_modify", payload)
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		_, err = fmt.Fprintf(cfg.stdout, "modified animation %s\n", *animationName)
		return err
	default:
		return fmt.Errorf("unknown animation command %q", args[0])
	}
}

func runSpriteFrames(cfg config, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: godot-bridge sprite-frames <new|get|modify> ...")
	}

	switch args[0] {
	case "new":
		fs := flag.NewFlagSet("sprite-frames new", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		dataText := fs.String("data", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "data")); err != nil {
			return err
		}
		if fs.NArg() != 1 || *dataText == "" {
			return errors.New("usage: godot-bridge sprite-frames new PATH --data JSON")
		}
		payload, err := buildSpriteFramesPayload(fs.Arg(0), *dataText)
		if err != nil {
			return err
		}
		_, data, err := sendCommand(cfg, "sprite_frames_new", payload)
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var detail spriteFramesDetail
		if err := json.Unmarshal(data, &detail); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "created sprite frames resource with %d animation(s)\n", len(detail.Animations))
		return err
	case "get":
		if len(args) != 2 {
			return errors.New("usage: godot-bridge sprite-frames get PATH")
		}
		_, data, err := sendCommand(cfg, "sprite_frames_get", map[string]any{"path": args[1]})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var detail spriteFramesDetail
		if err := json.Unmarshal(data, &detail); err != nil {
			return err
		}
		return printSpriteFramesDetail(cfg, detail)
	case "modify":
		fs := flag.NewFlagSet("sprite-frames modify", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		dataText := fs.String("data", "", "")
		mode := fs.String("mode", "merge", "")
		if err := fs.Parse(reorderFlags(args[1:], "data", "mode")); err != nil {
			return err
		}
		if fs.NArg() != 1 || *dataText == "" {
			return errors.New("usage: godot-bridge sprite-frames modify PATH --data JSON [--mode merge|replace]")
		}
		payload, err := buildSpriteFramesPayload(fs.Arg(0), *dataText)
		if err != nil {
			return err
		}
		payload["mode"] = *mode
		_, data, err := sendCommand(cfg, "sprite_frames_modify", payload)
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var detail spriteFramesDetail
		if err := json.Unmarshal(data, &detail); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "updated sprite frames resource with %d animation(s)\n", len(detail.Animations))
		return err
	default:
		return fmt.Errorf("unknown sprite-frames command %q", args[0])
	}
}

func buildAnimationPayload(path string, animationName string, dataText string) (map[string]any, error) {
	data, err := parseJSONObject(dataText, "--data")
	if err != nil {
		return nil, err
	}
	payload := mergeArgs(map[string]any{"path": path}, data, "path")
	if animationName != "" {
		payload["animation"] = animationName
		delete(payload, "name")
	} else if _, ok := payload["name"]; !ok {
		return nil, errors.New("animation data must include \"name\"")
	}
	return payload, nil
}

func buildSpriteFramesPayload(path string, dataText string) (map[string]any, error) {
	data, err := parseJSONObject(dataText, "--data")
	if err != nil {
		return nil, err
	}
	if _, ok := data["animations"]; !ok {
		return nil, errors.New("sprite frame data must include \"animations\"")
	}
	return mergeArgs(map[string]any{"path": path}, data, "path"), nil
}

func printAnimationDetail(cfg config, detail animationDetail) error {
	if _, err := fmt.Fprintf(cfg.stdout, "name: %s\nlength: %.3f\nloop_mode: %s\ntracks: %d\n", detail.Name, detail.Length, detail.LoopMode, len(detail.Tracks)); err != nil {
		return err
	}
	for _, track := range detail.Tracks {
		if _, err := fmt.Fprintf(cfg.stdout, "- %s [%s]\n", track.Path, track.Type); err != nil {
			return err
		}
		for _, keyframe := range track.Keyframes {
			encoded, err := json.Marshal(keyframe.Value)
			if err != nil {
				return err
			}
			if _, err := fmt.Fprintf(cfg.stdout, "  %.3f -> %s\n", keyframe.Time, encoded); err != nil {
				return err
			}
		}
	}
	return nil
}

func printSpriteFramesDetail(cfg config, detail spriteFramesDetail) error {
	if _, err := fmt.Fprintf(cfg.stdout, "animations: %d\n", len(detail.Animations)); err != nil {
		return err
	}
	for _, animation := range detail.Animations {
		if _, err := fmt.Fprintf(cfg.stdout, "- %s speed=%.3f loop=%t frames=%d\n", animation.Name, animation.Speed, animation.Loop, len(animation.Frames)); err != nil {
			return err
		}
		for index, frame := range animation.Frames {
			if frame.Region != nil {
				if _, err := fmt.Fprintf(cfg.stdout, "  %d %s region=(%.0f,%.0f,%.0f,%.0f) duration=%.3f\n", index, frame.Texture, frame.Region.X, frame.Region.Y, frame.Region.W, frame.Region.H, frame.Duration); err != nil {
					return err
				}
				continue
			}
			if _, err := fmt.Fprintf(cfg.stdout, "  %d %s duration=%.3f\n", index, frame.Texture, frame.Duration); err != nil {
				return err
			}
		}
	}
	return nil
}

func runDebug(cfg config, args []string) error {
	if len(args) == 0 || args[0] != "watch" {
		return errors.New("usage: godot-bridge debug watch [--events output,error] [--json]")
	}
	fs := flag.NewFlagSet("debug watch", flag.ContinueOnError)
	fs.SetOutput(cfg.stderr)
	eventsText := fs.String("events", "", "")
	if err := fs.Parse(reorderFlags(args[1:], "events")); err != nil {
		return err
	}
	if fs.NArg() != 0 {
		return errors.New("usage: godot-bridge debug watch [--events output,error] [--json]")
	}
	payload := map[string]any{}
	if events := parseCSVList(*eventsText); len(events) > 0 {
		payload["events"] = events
	}
	return sendAndStream(cfg, "debug_subscribe", payload, func(msg eventMessage) error {
		if cfg.asJSON {
			return writeJSONLine(cfg.stdout, msg)
		}
		return printDebugEvent(cfg, msg)
	})
}

func printDebugEvent(cfg config, msg eventMessage) error {
	var payload map[string]any
	if err := json.Unmarshal(msg.Data, &payload); err != nil {
		return fmt.Errorf("decode %s event: %w", msg.Event, err)
	}
	message := strings.TrimSpace(fmt.Sprint(payload["message"]))
	switch msg.Event {
	case "error":
		severity := strings.TrimSpace(fmt.Sprint(payload["severity"]))
		if severity == "" {
			severity = "error"
		}
		location := strings.TrimSpace(fmt.Sprint(payload["script"]))
		position := ""
		if rawLine, ok := payload["line"]; ok {
			line := fmt.Sprint(rawLine)
			if line != "" && line != "0" {
				position = ":" + line
				if rawColumn, ok := payload["column"]; ok {
					column := fmt.Sprint(rawColumn)
					if column != "" && column != "0" {
						position += ":" + column
					}
				}
			}
		}
		if location != "" {
			_, err := fmt.Fprintf(cfg.stdout, "[%s] %s%s %s\n", severity, location, position, message)
			return err
		}
		_, err := fmt.Fprintf(cfg.stdout, "[%s] %s\n", severity, message)
		return err
	default:
		_, err := fmt.Fprintf(cfg.stdout, "[%s] %s\n", msg.Event, message)
		return err
	}
}
