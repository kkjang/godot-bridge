package main

import (
	"context"
	"errors"
	"testing"
	"time"
)

type fakeWebsocketReader struct {
	messages [][]byte
	index    int

	setDeadlineCalls int
}

func (f *fakeWebsocketReader) SetReadDeadline(_ time.Time) error {
	f.setDeadlineCalls++
	return nil
}

func (f *fakeWebsocketReader) ReadMessage() (int, []byte, error) {
	if f.index >= len(f.messages) {
		return 0, nil, errors.New("no more messages")
	}
	msg := f.messages[f.index]
	f.index++
	return 1, msg, nil
}

func TestWaitForResponseSkipsPingMismatchedResponsesAndCollectsEarlyEvents(t *testing.T) {
	reader := &fakeWebsocketReader{messages: [][]byte{
		[]byte(`{"type":"ping"}`),
		[]byte(`{"type":"event","event":"output","data":{"message":"hello"}}`),
		[]byte(`{"id":"other","ok":true,"data":{"ignored":true}}`),
		[]byte(`{"id":"wanted","ok":true,"data":{"ready":true}}`),
	}}

	resp, events, err := waitForResponse(context.Background(), reader, time.Second, "wanted")
	if err != nil {
		t.Fatalf("waitForResponse() error = %v", err)
	}
	if resp.ID != "wanted" {
		t.Fatalf("response id = %q, want wanted", resp.ID)
	}
	if len(events) != 1 || events[0].Event != "output" {
		t.Fatalf("events = %#v, want one output event", events)
	}
}

func TestWaitForResponseReturnsPluginErrors(t *testing.T) {
	reader := &fakeWebsocketReader{messages: [][]byte{
		[]byte(`{"id":"wanted","ok":false,"error":"boom"}`),
	}}

	_, _, err := waitForResponse(context.Background(), reader, time.Second, "wanted")
	if err == nil || err.Error() != "boom" {
		t.Fatalf("waitForResponse() error = %v, want boom", err)
	}
}
