package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
)

type eventMessage struct {
	Type  string          `json:"type"`
	Event string          `json:"event"`
	Data  json.RawMessage `json:"data"`
}

func sendCommand(cfg config, command string, args map[string]any) (response, json.RawMessage, error) {
	ctx, cancel := context.WithTimeout(context.Background(), cfg.timeout)
	defer cancel()

	conn, id, err := dialCommand(ctx, cfg, command, args)
	if err != nil {
		return response{}, nil, err
	}
	defer conn.Close()

	respMsg, _, err := waitForResponse(ctx, conn, cfg.timeout, id)
	if err != nil {
		return response{}, nil, err
	}
	return respMsg, respMsg.Data, nil
}

func sendAndStream(cfg config, command string, args map[string]any, onEvent func(eventMessage) error) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	conn, id, err := dialCommand(ctx, cfg, command, args)
	if err != nil {
		return err
	}
	defer conn.Close()

	_, earlyEvents, err := waitForResponse(ctx, conn, cfg.timeout, id)
	if err != nil {
		return err
	}
	for _, msg := range earlyEvents {
		if err := onEvent(msg); err != nil {
			return err
		}
	}

	for {
		msg, err := readMessage(ctx, conn, 0)
		if err != nil {
			if errors.Is(err, context.Canceled) {
				return nil
			}
			return err
		}
		if msg.Type != "event" {
			continue
		}
		if err := onEvent(eventMessage{Type: msg.Type, Event: msg.Event, Data: msg.Data}); err != nil {
			return err
		}
	}
}

func dialCommand(ctx context.Context, cfg config, command string, args map[string]any) (*websocket.Conn, string, error) {
	u := url.URL{Scheme: "ws", Host: fmt.Sprintf("%s:%d", cfg.host, cfg.port)}
	dialer := websocket.Dialer{HandshakeTimeout: cfg.timeout}
	conn, _, err := dialer.DialContext(ctx, u.String(), http.Header{})
	if err != nil {
		return nil, "", fmt.Errorf("cannot connect to Godot bridge at %s: %w", u.String(), err)
	}

	id := strconv.FormatInt(time.Now().UnixNano(), 10)
	if err := conn.SetWriteDeadline(time.Now().Add(cfg.timeout)); err != nil {
		conn.Close()
		return nil, "", err
	}
	if err := conn.WriteJSON(request{ID: id, Command: command, Args: args}); err != nil {
		conn.Close()
		return nil, "", fmt.Errorf("sending %s command: %w", command, err)
	}
	return conn, id, nil
}

func waitForResponse(ctx context.Context, conn websocketReader, timeout time.Duration, id string) (response, []eventMessage, error) {
	events := []eventMessage{}
	for {
		msg, err := readMessage(ctx, conn, timeout)
		if err != nil {
			return response{}, nil, err
		}
		if msg.Type == "event" {
			events = append(events, eventMessage{Type: msg.Type, Event: msg.Event, Data: msg.Data})
			continue
		}
		if msg.ID != id {
			continue
		}
		if !msg.OK {
			return response{}, nil, errors.New(msg.Error)
		}
		return msg, events, nil
	}
}

type websocketReader interface {
	SetReadDeadline(time.Time) error
	ReadMessage() (int, []byte, error)
}

func readMessage(ctx context.Context, conn websocketReader, timeout time.Duration) (response, error) {
	if err := ctx.Err(); err != nil {
		return response{}, err
	}
	if timeout > 0 {
		if err := conn.SetReadDeadline(time.Now().Add(timeout)); err != nil {
			return response{}, err
		}
	} else {
		if err := conn.SetReadDeadline(time.Time{}); err != nil {
			return response{}, err
		}
	}
	_, payload, err := conn.ReadMessage()
	if err != nil {
		if err := ctx.Err(); err != nil {
			return response{}, err
		}
		return response{}, fmt.Errorf("reading websocket message: %w", err)
	}
	var respMsg response
	if err := json.Unmarshal(payload, &respMsg); err != nil {
		return response{}, fmt.Errorf("decoding response: %w", err)
	}
	if respMsg.Type == "ping" {
		return readMessage(ctx, conn, timeout)
	}
	return respMsg, nil
}

func parseCSVList(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	values := make([]string, 0, len(parts))
	seen := map[string]struct{}{}
	for _, part := range parts {
		value := strings.TrimSpace(part)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		values = append(values, value)
	}
	if len(values) == 0 {
		return nil
	}
	return values
}

func mergeArgs(base map[string]any, data map[string]any, protectedKeys ...string) map[string]any {
	merged := make(map[string]any, len(base)+len(data))
	for key, value := range base {
		merged[key] = value
	}
	protected := make(map[string]struct{}, len(protectedKeys))
	for _, key := range protectedKeys {
		protected[key] = struct{}{}
	}
	for key, value := range data {
		if _, ok := protected[key]; ok {
			continue
		}
		merged[key] = value
	}
	return merged
}
