# Multi-Connection Minimal Split Plan

## Goal

Allow one long-lived debug stream connection while preserving normal command execution from other clients, with the smallest safe change to the current bridge architecture.

## Current State

- The bridge currently supports a single websocket client.
- `debug watch` holds that connection open.
- Other commands are blocked while a watch session is active.
- Subscriptions are global because there is only one client.

## Minimal Target

Support multiple websocket clients with:

- per-connection debug subscriptions
- shared command handling through the existing editor-control path
- serialized command execution on the server side
- no attempt to provide transactionality or conflict resolution beyond current behavior

## Non-Goals

- fine-grained multi-user conflict management
- interactive command ownership/leases
- fully independent editor mutation sessions
- protocol redesign beyond connection scoping

## Design

1. Replace single `_peer` storage with connection tracking:
   - connection id
   - `WebSocketPeer`
   - per-connection debug subscription state
2. Continue polling all active peers each frame.
3. Route request/response messages to the requesting connection only.
4. Route debug events only to subscribed connections.
5. Keep command execution serialized on the main thread in current dispatch order.

## Proposed Data Model

- `Dictionary[int, WebSocketPeer]` or array of connection records
- connection record fields:
  - `peer`
  - `subscriptions`
  - `last_heartbeat`
  - optional `client_label` for diagnostics

## Implementation Steps

1. Refactor transport layer in `bridge_server.gd`:
   - accept multiple clients
   - poll each open peer
   - remove global single-peer assumptions
2. Change `_send_ok` / `_send_error` / `_send_json` to target a specific connection.
3. Make debug subscription state per connection instead of global.
4. Replay backlog only to the subscribing connection.
5. Keep heartbeat behavior per connection.
6. Disconnect and clean up dead peers independently.

## CLI Compatibility

- Existing CLI commands should continue to work unchanged.
- `debug watch` should no longer block a second CLI invocation.
- No protocol changes should be required for normal request/response messages.

## Validation

1. Existing CLI tests still pass.
2. Existing plugin tests still pass.
3. Manual repro:
   - terminal A: `godot-bridge debug watch --events output,error --json`
   - terminal B: `godot-bridge scene run ...`
   - terminal B: `godot-bridge status`
   - terminal B: `godot-bridge node get ...`
   - confirm watch continues streaming while commands succeed
4. Optional stress case:
   - two watch clients subscribed simultaneously
   - both receive output events

## Risks

- current response helpers assume one active peer and need careful untangling
- command ordering must remain deterministic
- backlog replay and heartbeat handling can accidentally broadcast to the wrong client if not scoped correctly

## Deliverable

A minimal multi-client bridge where one client can watch debug output while another issues normal CLI commands, with per-connection event subscriptions and serialized command handling.
