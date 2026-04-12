package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

const defaultTimeout = 5 * time.Second
const version = "dev"

type config struct {
	host    string
	port    int
	timeout time.Duration
	asJSON  bool
	stdout  *os.File
	stderr  *os.File
}

type request struct {
	ID      string         `json:"id"`
	Command string         `json:"command"`
	Args    map[string]any `json:"args"`
}

type response struct {
	ID    string          `json:"id"`
	OK    bool            `json:"ok"`
	Data  json.RawMessage `json:"data"`
	Error string          `json:"error"`
	Type  string          `json:"type"`
}

type nodeTree struct {
	Name       string     `json:"name"`
	Type       string     `json:"type"`
	Path       string     `json:"path"`
	ChildCount int        `json:"child_count"`
	Children   []nodeTree `json:"children"`
}

type nodeInfo struct {
	Name       string         `json:"name"`
	Type       string         `json:"type"`
	Path       string         `json:"path"`
	ChildCount int            `json:"child_count"`
	Children   []nodeInfo     `json:"children"`
	Properties map[string]any `json:"properties"`
	Signals    []string       `json:"signals"`
	Groups     []string       `json:"groups"`
}

type editorState struct {
	CurrentScene  string   `json:"current_scene"`
	OpenScenes    []string `json:"open_scenes"`
	SelectedNodes []string `json:"selected_nodes"`
	EditorScreen  string   `json:"editor_screen"`
}

type resourceList struct {
	Path  string `json:"path"`
	Files []struct {
		Name string `json:"name"`
		Type string `json:"type"`
		Path string `json:"path"`
	} `json:"files"`
	Subdirs []string `json:"subdirs"`
}

type screenshotInfo struct {
	PNGBase64 string `json:"png_base64"`
	Width     int    `json:"width"`
	Height    int    `json:"height"`
}

type cliSpec struct {
	Name           string        `json:"name"`
	Version        string        `json:"version"`
	Description    string        `json:"description"`
	TransportFlags []flagSpec    `json:"transport_flags"`
	Commands       []commandSpec `json:"commands"`
	Notes          []string      `json:"notes"`
}

type commandSpec struct {
	Path          []string  `json:"path"`
	Usage         string    `json:"usage"`
	PluginCommand string    `json:"plugin_command"`
	RequiredArgs  []string  `json:"required_args"`
	OptionalArgs  []string  `json:"optional_args"`
	Defaults      []string  `json:"defaults"`
	Description   string    `json:"description"`
	OutputModes   []string  `json:"output_modes"`
	Aliases       []string  `json:"aliases,omitempty"`
	Examples      []string  `json:"examples,omitempty"`
	Args          []argSpec `json:"args,omitempty"`
}

type flagSpec struct {
	Name        string `json:"name"`
	Default     string `json:"default"`
	Description string `json:"description"`
}

type argSpec struct {
	Name        string `json:"name"`
	Kind        string `json:"kind"`
	Required    bool   `json:"required"`
	Default     string `json:"default,omitempty"`
	Description string `json:"description"`
}

func main() {
	cfg, args, err := parseGlobalArgs(os.Args[1:])
	if err != nil {
		exitf(os.Stderr, "%v\n", err)
	}

	if len(args) == 0 {
		printUsage(cfg.stderr)
		os.Exit(2)
	}

	if err := run(cfg, args); err != nil {
		exitf(cfg.stderr, "%v\n", err)
	}
}

func parseGlobalArgs(args []string) (config, []string, error) {
	cfg := config{
		host:    "127.0.0.1",
		port:    6505,
		timeout: defaultTimeout,
		stdout:  os.Stdout,
		stderr:  os.Stderr,
	}

	filtered := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--json":
			cfg.asJSON = true
		case arg == "--host":
			i++
			if i >= len(args) {
				return cfg, nil, errors.New("missing value for --host")
			}
			cfg.host = args[i]
		case strings.HasPrefix(arg, "--host="):
			cfg.host = strings.TrimPrefix(arg, "--host=")
		case arg == "--port":
			i++
			if i >= len(args) {
				return cfg, nil, errors.New("missing value for --port")
			}
			port, err := strconv.Atoi(args[i])
			if err != nil {
				return cfg, nil, fmt.Errorf("invalid --port value %q", args[i])
			}
			cfg.port = port
		case strings.HasPrefix(arg, "--port="):
			port, err := strconv.Atoi(strings.TrimPrefix(arg, "--port="))
			if err != nil {
				return cfg, nil, fmt.Errorf("invalid %s", arg)
			}
			cfg.port = port
		case arg == "--timeout":
			i++
			if i >= len(args) {
				return cfg, nil, errors.New("missing value for --timeout")
			}
			timeout, err := time.ParseDuration(args[i])
			if err != nil {
				return cfg, nil, fmt.Errorf("invalid --timeout value %q", args[i])
			}
			cfg.timeout = timeout
		case strings.HasPrefix(arg, "--timeout="):
			timeout, err := time.ParseDuration(strings.TrimPrefix(arg, "--timeout="))
			if err != nil {
				return cfg, nil, fmt.Errorf("invalid %s", arg)
			}
			cfg.timeout = timeout
		case arg == "--help" || arg == "-h":
			filtered = append(filtered, "help")
		default:
			filtered = append(filtered, arg)
		}
	}

	return cfg, filtered, nil
}

func run(cfg config, args []string) error {
	switch args[0] {
	case "help":
		printUsage(cfg.stdout)
		return nil
	case "status":
		_, data, err := sendCommand(cfg, "editor_state", map[string]any{})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeJSON(cfg.stdout, map[string]any{"status": "connected", "data": data})
		}
		_, err = fmt.Fprintln(cfg.stdout, "connected")
		return err
	case "spec":
		return runSpec(cfg, args[1:])
	case "editor":
		return runEditor(cfg, args[1:])
	case "node":
		return runNode(cfg, args[1:])
	case "scene":
		return runScene(cfg, args[1:])
	case "script":
		return runScript(cfg, args[1:])
	case "screenshot":
		return runScreenshot(cfg, args[1:])
	case "resource":
		return runResource(cfg, args[1:])
	default:
		return fmt.Errorf("unknown command %q", strings.Join(args, " "))
	}
}

func runSpec(cfg config, args []string) error {
	fs := flag.NewFlagSet("spec", flag.ContinueOnError)
	fs.SetOutput(cfg.stderr)
	markdown := fs.Bool("markdown", false, "")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 0 {
		return errors.New("usage: godot-bridge spec [--markdown]")
	}

	spec := buildSpec()
	if *markdown {
		_, err := fmt.Fprint(cfg.stdout, renderSpecMarkdown(spec))
		return err
	}
	return writeJSON(cfg.stdout, spec)
}

func runEditor(cfg config, args []string) error {
	if len(args) != 1 || args[0] != "state" {
		return errors.New("usage: godot-bridge editor state")
	}
	_, data, err := sendCommand(cfg, "editor_state", map[string]any{})
	if err != nil {
		return err
	}
	if cfg.asJSON {
		return writeRawJSON(cfg.stdout, data)
	}
	var state editorState
	if err := json.Unmarshal(data, &state); err != nil {
		return err
	}
	return printEditorState(cfg.stdout, state)
}

func runNode(cfg config, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: godot-bridge node <tree|get|add|modify|delete|move> ...")
	}

	switch args[0] {
	case "tree":
		fs := flag.NewFlagSet("node tree", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		depth := fs.Int("depth", 4, "")
		if err := fs.Parse(reorderFlags(args[1:], "depth")); err != nil {
			return err
		}
		path := ""
		if fs.NArg() > 1 {
			return errors.New("usage: godot-bridge node tree [PATH] [--depth N]")
		}
		if fs.NArg() == 1 {
			path = fs.Arg(0)
		}
		_, data, err := sendCommand(cfg, "node_tree", map[string]any{"path": path, "depth": *depth})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Tree nodeTree `json:"tree"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		printNodeTree(cfg.stdout, payload.Tree, 0)
		return nil
	case "get":
		fs := flag.NewFlagSet("node get", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		detail := fs.String("detail", "brief", "")
		if err := fs.Parse(reorderFlags(args[1:], "detail")); err != nil {
			return err
		}
		if fs.NArg() != 1 {
			return errors.New("usage: godot-bridge node get PATH [--detail brief|full]")
		}
		_, data, err := sendCommand(cfg, "node_get", map[string]any{"path": fs.Arg(0), "detail": *detail})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var info nodeInfo
		if err := json.Unmarshal(data, &info); err != nil {
			return err
		}
		return printNodeInfo(cfg.stdout, info, *detail)
	case "add":
		fs := flag.NewFlagSet("node add", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		parent := fs.String("parent", "", "")
		name := fs.String("name", "", "")
		propsText := fs.String("props", "{}", "")
		if err := fs.Parse(reorderFlags(args[1:], "parent", "name", "props")); err != nil {
			return err
		}
		if fs.NArg() != 1 {
			return errors.New("usage: godot-bridge node add TYPE [--parent PATH] [--name NAME] [--props JSON]")
		}
		props, err := parseJSONObject(*propsText, "--props")
		if err != nil {
			return err
		}
		_, data, err := sendCommand(cfg, "node_add", map[string]any{"type": fs.Arg(0), "parent": *parent, "name": *name, "props": props})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Path string `json:"path"`
			Name string `json:"name"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "added %s at %s\n", payload.Name, payload.Path)
		return err
	case "modify":
		fs := flag.NewFlagSet("node modify", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		propsText := fs.String("props", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "props")); err != nil {
			return err
		}
		if fs.NArg() != 1 || *propsText == "" {
			return errors.New("usage: godot-bridge node modify PATH --props JSON")
		}
		props, err := parseJSONObject(*propsText, "--props")
		if err != nil {
			return err
		}
		_, data, err := sendCommand(cfg, "node_modify", map[string]any{"path": fs.Arg(0), "props": props})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Modified string `json:"modified"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "modified %s\n", payload.Modified)
		return err
	case "delete":
		if len(args) != 2 {
			return errors.New("usage: godot-bridge node delete PATH")
		}
		_, data, err := sendCommand(cfg, "node_delete", map[string]any{"path": args[1]})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Deleted string `json:"deleted"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "deleted %s\n", payload.Deleted)
		return err
	case "move":
		fs := flag.NewFlagSet("node move", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		newParent := fs.String("new-parent", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "new-parent")); err != nil {
			return err
		}
		if fs.NArg() != 1 || *newParent == "" {
			return errors.New("usage: godot-bridge node move PATH --new-parent PATH")
		}
		_, data, err := sendCommand(cfg, "node_move", map[string]any{"path": fs.Arg(0), "new_parent": *newParent})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Moved string `json:"moved"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "moved %s\n", payload.Moved)
		return err
	default:
		return fmt.Errorf("unknown node command %q", args[0])
	}
}

func runScene(cfg config, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: godot-bridge scene <new|open|save|run|stop> ...")
	}

	switch args[0] {
	case "new":
		fs := flag.NewFlagSet("scene new", flag.ContinueOnError)
		fs.SetOutput(cfg.stderr)
		rootType := fs.String("root-type", "Node2D", "")
		rootName := fs.String("root-name", "", "")
		if err := fs.Parse(reorderFlags(args[1:], "root-type", "root-name")); err != nil {
			return err
		}
		if fs.NArg() != 1 {
			return errors.New("usage: godot-bridge scene new PATH [--root-type TYPE] [--root-name NAME]")
		}
		_, data, err := sendCommand(cfg, "scene_new", map[string]any{"path": fs.Arg(0), "root_type": *rootType, "root_name": *rootName})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Path     string `json:"path"`
			RootType string `json:"root_type"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "created %s with root %s\n", payload.Path, payload.RootType)
		return err
	case "open":
		if len(args) != 2 {
			return errors.New("usage: godot-bridge scene open PATH")
		}
		_, data, err := sendCommand(cfg, "scene_open", map[string]any{"path": args[1]})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Opened string `json:"opened"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "opened %s\n", payload.Opened)
		return err
	case "save":
		if len(args) != 1 {
			return errors.New("usage: godot-bridge scene save")
		}
		_, data, err := sendCommand(cfg, "scene_save", map[string]any{})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		var payload struct {
			Saved string `json:"saved"`
		}
		if err := json.Unmarshal(data, &payload); err != nil {
			return err
		}
		_, err = fmt.Fprintf(cfg.stdout, "saved %s\n", payload.Saved)
		return err
	case "run":
		if len(args) > 2 {
			return errors.New("usage: godot-bridge scene run [PATH]")
		}
		path := ""
		if len(args) == 2 {
			path = args[1]
		}
		_, data, err := sendCommand(cfg, "scene_run", map[string]any{"path": path})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		_, err = fmt.Fprintln(cfg.stdout, "running scene")
		return err
	case "stop":
		if len(args) != 1 {
			return errors.New("usage: godot-bridge scene stop")
		}
		_, data, err := sendCommand(cfg, "scene_stop", map[string]any{})
		if err != nil {
			return err
		}
		if cfg.asJSON {
			return writeRawJSON(cfg.stdout, data)
		}
		_, err = fmt.Fprintln(cfg.stdout, "stopped scene")
		return err
	default:
		return fmt.Errorf("unknown scene command %q", args[0])
	}
}

func runScript(cfg config, args []string) error {
	if len(args) != 2 || args[0] != "open" {
		return errors.New("usage: godot-bridge script open PATH")
	}
	_, data, err := sendCommand(cfg, "script_open", map[string]any{"path": args[1]})
	if err != nil {
		return err
	}
	if cfg.asJSON {
		return writeRawJSON(cfg.stdout, data)
	}
	var payload struct {
		Opened string `json:"opened"`
	}
	if err := json.Unmarshal(data, &payload); err != nil {
		return err
	}
	_, err = fmt.Fprintf(cfg.stdout, "opened %s\n", payload.Opened)
	return err
}

func runScreenshot(cfg config, args []string) error {
	if len(args) != 0 {
		return errors.New("usage: godot-bridge screenshot")
	}
	_, data, err := sendCommand(cfg, "screenshot", map[string]any{})
	if err != nil {
		return err
	}
	if cfg.asJSON {
		return writeRawJSON(cfg.stdout, data)
	}
	var info screenshotInfo
	if err := json.Unmarshal(data, &info); err != nil {
		return err
	}
	_, err = fmt.Fprintf(cfg.stdout, "captured %dx%d screenshot (%d base64 bytes)\n", info.Width, info.Height, len(info.PNGBase64))
	return err
}

func runResource(cfg config, args []string) error {
	if len(args) == 0 || args[0] != "list" {
		return errors.New("usage: godot-bridge resource list [DIR]")
	}
	if len(args) > 2 {
		return errors.New("usage: godot-bridge resource list [DIR]")
	}
	path := "res://"
	if len(args) == 2 {
		path = args[1]
	}
	_, data, err := sendCommand(cfg, "resource_list", map[string]any{"path": path})
	if err != nil {
		return err
	}
	if cfg.asJSON {
		return writeRawJSON(cfg.stdout, data)
	}
	var listing resourceList
	if err := json.Unmarshal(data, &listing); err != nil {
		return err
	}
	return printResourceList(cfg.stdout, listing)
}

func sendCommand(cfg config, command string, args map[string]any) (response, json.RawMessage, error) {
	ctx, cancel := context.WithTimeout(context.Background(), cfg.timeout)
	defer cancel()

	u := url.URL{Scheme: "ws", Host: fmt.Sprintf("%s:%d", cfg.host, cfg.port)}
	dialer := websocket.Dialer{HandshakeTimeout: cfg.timeout}
	conn, resp, err := dialer.DialContext(ctx, u.String(), http.Header{})
	if err != nil {
		if resp != nil {
			return response{}, nil, fmt.Errorf("cannot connect to Godot bridge at %s: %w", u.String(), err)
		}
		return response{}, nil, fmt.Errorf("cannot connect to Godot bridge at %s: %w", u.String(), err)
	}
	defer conn.Close()

	id := strconv.FormatInt(time.Now().UnixNano(), 10)
	if err := conn.SetWriteDeadline(time.Now().Add(cfg.timeout)); err != nil {
		return response{}, nil, err
	}
	if err := conn.WriteJSON(request{ID: id, Command: command, Args: args}); err != nil {
		return response{}, nil, fmt.Errorf("sending %s command: %w", command, err)
	}

	for {
		if err := conn.SetReadDeadline(time.Now().Add(cfg.timeout)); err != nil {
			return response{}, nil, err
		}
		_, payload, err := conn.ReadMessage()
		if err != nil {
			return response{}, nil, fmt.Errorf("waiting for %s response: %w", command, err)
		}

		var respMsg response
		if err := json.Unmarshal(payload, &respMsg); err != nil {
			return response{}, nil, fmt.Errorf("decoding response: %w", err)
		}
		if respMsg.Type == "ping" {
			continue
		}
		if respMsg.ID != id {
			continue
		}
		if !respMsg.OK {
			return response{}, nil, errors.New(respMsg.Error)
		}
		return respMsg, respMsg.Data, nil
	}
}

func parseJSONObject(text string, label string) (map[string]any, error) {
	var out map[string]any
	if err := json.Unmarshal([]byte(text), &out); err != nil {
		return nil, fmt.Errorf("invalid %s JSON: %w", label, err)
	}
	if out == nil {
		out = map[string]any{}
	}
	return out, nil
}

func buildSpec() cliSpec {
	return cliSpec{
		Name:        "godot-bridge",
		Version:     version,
		Description: "Thin CLI wrapper around the Godot Bridge editor plugin.",
		TransportFlags: []flagSpec{
			{Name: "--host", Default: "127.0.0.1", Description: "Godot bridge host."},
			{Name: "--port", Default: "6505", Description: "Godot bridge port."},
			{Name: "--timeout", Default: defaultTimeout.String(), Description: "Maximum time to connect and wait for a response."},
			{Name: "--json", Default: "false", Description: "Print structured JSON instead of compact text for normal commands."},
		},
		Commands: []commandSpec{
			{
				Path:          []string{"status"},
				Usage:         "godot-bridge status",
				PluginCommand: "editor_state",
				OptionalArgs:  []string{"--json"},
				Defaults:      []string{"text output"},
				Description:   "Checks that the bridge plugin is reachable and responsive.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"spec"},
				Usage:         "godot-bridge spec [--markdown]",
				PluginCommand: "",
				OptionalArgs:  []string{"--markdown"},
				Defaults:      []string{"json output"},
				Description:   "Prints the machine-readable CLI spec. Use --markdown to render the README command table from the same source.",
				OutputModes:   []string{"json", "markdown"},
			},
			{
				Path:          []string{"editor", "state"},
				Usage:         "godot-bridge editor state",
				PluginCommand: "editor_state",
				OptionalArgs:  []string{"--json"},
				Defaults:      []string{"text output"},
				Description:   "Shows current scene, open scenes, selected nodes, and active editor screen.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"node", "tree"},
				Usage:         "godot-bridge node tree [PATH] [--depth N]",
				PluginCommand: "node_tree",
				OptionalArgs:  []string{"PATH", "--depth INT", "--json"},
				Defaults:      []string{"PATH=\"\"", "depth=4"},
				Description:   "Prints the node tree rooted at the given path, or the current scene root when omitted.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"node", "get"},
				Usage:         "godot-bridge node get PATH [--detail brief|full]",
				PluginCommand: "node_get",
				RequiredArgs:  []string{"PATH"},
				OptionalArgs:  []string{"--detail brief|full", "--json"},
				Defaults:      []string{"detail=brief"},
				Description:   "Shows node information. Full detail includes editor-visible properties, signals, groups, and children.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"node", "add"},
				Usage:         "godot-bridge node add TYPE [--parent PATH] [--name NAME] [--props JSON]",
				PluginCommand: "node_add",
				RequiredArgs:  []string{"TYPE"},
				OptionalArgs:  []string{"--parent PATH", "--name NAME", "--props JSON", "--json"},
				Defaults:      []string{"parent=\"\"", "name=TYPE", "props={}"},
				Description:   "Adds a node under the target parent or the scene root when no parent is provided.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"node", "modify"},
				Usage:         "godot-bridge node modify PATH --props JSON",
				PluginCommand: "node_modify",
				RequiredArgs:  []string{"PATH", "--props JSON"},
				OptionalArgs:  []string{"--json"},
				Description:   "Updates properties on an existing node using JSON-encoded values.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"node", "delete"},
				Usage:         "godot-bridge node delete PATH",
				PluginCommand: "node_delete",
				RequiredArgs:  []string{"PATH"},
				OptionalArgs:  []string{"--json"},
				Description:   "Deletes the specified node.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"node", "move"},
				Usage:         "godot-bridge node move PATH --new-parent PATH",
				PluginCommand: "node_move",
				RequiredArgs:  []string{"PATH", "--new-parent PATH"},
				OptionalArgs:  []string{"--json"},
				Description:   "Reparents a node under a new parent.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"scene", "new"},
				Usage:         "godot-bridge scene new PATH [--root-type TYPE] [--root-name NAME]",
				PluginCommand: "scene_new",
				RequiredArgs:  []string{"PATH"},
				OptionalArgs:  []string{"--root-type TYPE", "--root-name NAME", "--json"},
				Defaults:      []string{"root-type=Node2D"},
				Description:   "Creates a new scene file and opens it in the editor.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"scene", "open"},
				Usage:         "godot-bridge scene open PATH",
				PluginCommand: "scene_open",
				RequiredArgs:  []string{"PATH"},
				OptionalArgs:  []string{"--json"},
				Description:   "Opens an existing scene in the editor.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"scene", "save"},
				Usage:         "godot-bridge scene save",
				PluginCommand: "scene_save",
				OptionalArgs:  []string{"--json"},
				Description:   "Saves the currently open scene.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"scene", "run"},
				Usage:         "godot-bridge scene run [PATH]",
				PluginCommand: "scene_run",
				OptionalArgs:  []string{"PATH", "--json"},
				Defaults:      []string{"PATH=\"\""},
				Description:   "Runs the main scene, or opens and runs the specified scene.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"scene", "stop"},
				Usage:         "godot-bridge scene stop",
				PluginCommand: "scene_stop",
				OptionalArgs:  []string{"--json"},
				Description:   "Stops the running scene.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"script", "open"},
				Usage:         "godot-bridge script open PATH",
				PluginCommand: "script_open",
				RequiredArgs:  []string{"PATH"},
				OptionalArgs:  []string{"--json"},
				Description:   "Opens a script in the Godot script editor.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"screenshot"},
				Usage:         "godot-bridge screenshot",
				PluginCommand: "screenshot",
				OptionalArgs:  []string{"--json"},
				Defaults:      []string{"text output"},
				Description:   "Captures the current 2D editor viewport.",
				OutputModes:   []string{"text", "json"},
			},
			{
				Path:          []string{"resource", "list"},
				Usage:         "godot-bridge resource list [DIR]",
				PluginCommand: "resource_list",
				OptionalArgs:  []string{"DIR", "--json"},
				Defaults:      []string{"DIR=res://"},
				Description:   "Lists files and subdirectories from Godot's resource filesystem view.",
				OutputModes:   []string{"text", "json"},
			},
		},
		Notes: []string{
			"This CLI only covers plugin-backed editor commands.",
			"The README command spec table should be regenerated from `godot-bridge spec --markdown` whenever the command surface changes.",
		},
	}
}

func renderSpecMarkdown(spec cliSpec) string {
	var b strings.Builder
	b.WriteString("| CLI command | Plugin command | Required args | Optional args | Defaults | Description |\n")
	b.WriteString("|---|---|---|---|---|---|\n")
	for _, cmd := range spec.Commands {
		plugin := "-"
		if cmd.PluginCommand != "" {
			plugin = "`" + cmd.PluginCommand + "`"
		}
		required := joinSpecField(cmd.RequiredArgs)
		optional := joinSpecField(cmd.OptionalArgs)
		defaults := joinSpecField(cmd.Defaults)
		fmt.Fprintf(&b, "| `%s` | %s | %s | %s | %s | %s |\n",
			cmd.Usage,
			plugin,
			required,
			optional,
			defaults,
			escapeTableText(cmd.Description),
		)
	}
	return b.String()
}

func joinSpecField(values []string) string {
	if len(values) == 0 {
		return "none"
	}
	parts := make([]string, 0, len(values))
	for _, value := range values {
		parts = append(parts, "`"+escapeTableText(value)+"`")
	}
	return strings.Join(parts, ", ")
}

func escapeTableText(text string) string {
	return strings.ReplaceAll(text, "|", `\|`)
}

func reorderFlags(args []string, flagNames ...string) []string {
	allowed := make(map[string]struct{}, len(flagNames))
	for _, name := range flagNames {
		allowed[name] = struct{}{}
	}

	flags := make([]string, 0, len(args))
	positionals := make([]string, 0, len(args))

	for i := 0; i < len(args); i++ {
		arg := args[i]
		if name, value, ok := strings.Cut(arg, "="); ok && strings.HasPrefix(name, "--") {
			if _, exists := allowed[strings.TrimPrefix(name, "--")]; exists {
				flags = append(flags, arg)
				continue
			}
			_ = value
		}

		if strings.HasPrefix(arg, "--") {
			name := strings.TrimPrefix(arg, "--")
			if _, exists := allowed[name]; exists {
				flags = append(flags, arg)
				if i+1 < len(args) && !strings.HasPrefix(args[i+1], "--") {
					flags = append(flags, args[i+1])
					i++
				}
				continue
			}
		}

		positionals = append(positionals, arg)
	}

	return append(flags, positionals...)
}

func printEditorState(out *os.File, state editorState) error {
	if _, err := fmt.Fprintf(out, "current_scene: %s\n", emptyFallback(state.CurrentScene, "<none>")); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(out, "editor_screen: %s\n", state.EditorScreen); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(out, "open_scenes: %d\n", len(state.OpenScenes)); err != nil {
		return err
	}
	for _, scene := range state.OpenScenes {
		if _, err := fmt.Fprintf(out, "- %s\n", scene); err != nil {
			return err
		}
	}
	if _, err := fmt.Fprintf(out, "selected_nodes: %d\n", len(state.SelectedNodes)); err != nil {
		return err
	}
	for _, path := range state.SelectedNodes {
		if _, err := fmt.Fprintf(out, "- %s\n", path); err != nil {
			return err
		}
	}
	return nil
}

func printNodeTree(out *os.File, node nodeTree, depth int) {
	indent := strings.Repeat("  ", depth)
	fmt.Fprintf(out, "%s%s [%s] %s\n", indent, node.Name, node.Type, node.Path)
	for _, child := range node.Children {
		printNodeTree(out, child, depth+1)
	}
}

func printNodeInfo(out *os.File, info nodeInfo, detail string) error {
	if _, err := fmt.Fprintf(out, "name: %s\n", info.Name); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(out, "type: %s\n", info.Type); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(out, "path: %s\n", info.Path); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(out, "children: %d\n", info.ChildCount); err != nil {
		return err
	}
	for _, child := range info.Children {
		if _, err := fmt.Fprintf(out, "- %s [%s] %s\n", child.Name, child.Type, child.Path); err != nil {
			return err
		}
	}
	if detail == "full" {
		if _, err := fmt.Fprintf(out, "signals: %s\n", strings.Join(info.Signals, ", ")); err != nil {
			return err
		}
		if _, err := fmt.Fprintf(out, "groups: %s\n", strings.Join(info.Groups, ", ")); err != nil {
			return err
		}
		if _, err := fmt.Fprintln(out, "properties:"); err != nil {
			return err
		}
		keys := make([]string, 0, len(info.Properties))
		for key := range info.Properties {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			value, err := json.Marshal(info.Properties[key])
			if err != nil {
				return err
			}
			if _, err := fmt.Fprintf(out, "- %s=%s\n", key, value); err != nil {
				return err
			}
		}
	}
	return nil
}

func printResourceList(out *os.File, listing resourceList) error {
	if _, err := fmt.Fprintf(out, "path: %s\n", listing.Path); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(out, "subdirs: %d\n", len(listing.Subdirs)); err != nil {
		return err
	}
	for _, dir := range listing.Subdirs {
		if _, err := fmt.Fprintf(out, "- dir %s\n", dir); err != nil {
			return err
		}
	}
	if _, err := fmt.Fprintf(out, "files: %d\n", len(listing.Files)); err != nil {
		return err
	}
	for _, file := range listing.Files {
		if _, err := fmt.Fprintf(out, "- file %s (%s) %s\n", file.Name, file.Type, file.Path); err != nil {
			return err
		}
	}
	return nil
}

func writeRawJSON(out *os.File, data json.RawMessage) error {
	if !json.Valid(data) {
		return errors.New("response payload is not valid JSON")
	}
	_, err := out.Write(append(data, '\n'))
	return err
}

func writeJSON(out *os.File, value any) error {
	encoder := json.NewEncoder(out)
	encoder.SetIndent("", "  ")
	return encoder.Encode(value)
}

func emptyFallback(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func printUsage(out *os.File) {
	fmt.Fprintln(out, "Usage: godot-bridge [--host HOST] [--port PORT] [--timeout DURATION] [--json] <command>")
	fmt.Fprintln(out, "")
	fmt.Fprintln(out, "Commands:")
	fmt.Fprintln(out, "  status")
	fmt.Fprintln(out, "  spec [--markdown]")
	fmt.Fprintln(out, "  editor state")
	fmt.Fprintln(out, "  node tree [PATH] [--depth N]")
	fmt.Fprintln(out, "  node get PATH [--detail brief|full]")
	fmt.Fprintln(out, "  node add TYPE [--parent PATH] [--name NAME] [--props JSON]")
	fmt.Fprintln(out, "  node modify PATH --props JSON")
	fmt.Fprintln(out, "  node delete PATH")
	fmt.Fprintln(out, "  node move PATH --new-parent PATH")
	fmt.Fprintln(out, "  scene new PATH [--root-type TYPE] [--root-name NAME]")
	fmt.Fprintln(out, "  scene open PATH")
	fmt.Fprintln(out, "  scene save")
	fmt.Fprintln(out, "  scene run [PATH]")
	fmt.Fprintln(out, "  scene stop")
	fmt.Fprintln(out, "  script open PATH")
	fmt.Fprintln(out, "  screenshot")
	fmt.Fprintln(out, "  resource list [DIR]")
}

func exitf(out *os.File, format string, args ...any) {
	fmt.Fprintf(out, format, args...)
	os.Exit(1)
}
