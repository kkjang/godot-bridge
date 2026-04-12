// gdscript-lsp-proxy bridges Claude Code's stdio-based LSP client to
// Godot's TCP-based GDScript Language Server.
//
// Usage:
//
//	gdscript-lsp-proxy [--port PORT]
//
// Env:
//
//	GODOT_LSP_PORT  override default port 6005
//
// Claude Code launches language servers as stdio subprocesses, but Godot's
// GDScript LSP listens on a TCP socket. This proxy sits in between:
//
//	Claude Code  --stdio-->  gdscript-lsp-proxy  --TCP-->  Godot :6005
//
// All LSP JSON-RPC messages are passed through verbatim; the proxy only
// handles Content-Length framing and does no message interpretation.
package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"strconv"
	"strings"
)

const defaultPort = "6005"

func main() {
	port := defaultPort
	if p := os.Getenv("GODOT_LSP_PORT"); p != "" {
		port = p
	}
	args := os.Args[1:]
	for i, arg := range args {
		if arg == "--port" && i+1 < len(args) {
			port = args[i+1]
		}
	}

	conn, err := net.Dial("tcp", "127.0.0.1:"+port)
	if err != nil {
		fmt.Fprintf(os.Stderr, "gdscript-lsp-proxy: cannot connect to Godot LSP on port %s: %v\n", port, err)
		// Send an LSP window/showMessage so the client sees a human-readable error.
		errMsg := fmt.Sprintf(
			`{"jsonrpc":"2.0","method":"window/showMessage","params":{"type":1,"message":"Godot editor not running — GDScript LSP unavailable on port %s"}}`,
			port,
		)
		fmt.Printf("Content-Length: %d\r\n\r\n%s", len(errMsg), errMsg)
		os.Exit(1)
	}
	defer conn.Close()

	done := make(chan error, 2)

	// stdin → TCP
	go func() {
		done <- copyFramed(conn, os.Stdin)
	}()

	// TCP → stdout
	go func() {
		done <- copyFramed(os.Stdout, conn)
	}()

	// Exit as soon as either direction closes/errors.
	if err := <-done; err != nil && err != io.EOF {
		fmt.Fprintf(os.Stderr, "gdscript-lsp-proxy: %v\n", err)
		os.Exit(1)
	}
}

// copyFramed reads LSP Content-Length–framed messages from src and writes
// them identically to dst. It returns on the first read or write error.
func copyFramed(dst io.Writer, src io.Reader) error {
	r := bufio.NewReaderSize(src, 1<<20) // 1 MiB read buffer
	for {
		cl, err := readHeaders(r)
		if err != nil {
			return err
		}

		body := make([]byte, cl)
		if _, err := io.ReadFull(r, body); err != nil {
			return fmt.Errorf("reading body (%d bytes): %w", cl, err)
		}

		if _, err := fmt.Fprintf(dst, "Content-Length: %d\r\n\r\n", cl); err != nil {
			return fmt.Errorf("writing header: %w", err)
		}
		if _, err := dst.Write(body); err != nil {
			return fmt.Errorf("writing body: %w", err)
		}
	}
}

// readHeaders reads LSP headers (terminated by a blank line) and returns the
// value of the Content-Length header.
func readHeaders(r *bufio.Reader) (int, error) {
	var cl int
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return 0, err
		}
		line = strings.TrimRight(line, "\r\n")
		if line == "" {
			return cl, nil
		}
		if v, ok := strings.CutPrefix(line, "Content-Length: "); ok {
			n, err := strconv.Atoi(v)
			if err != nil {
				return 0, fmt.Errorf("invalid Content-Length %q: %w", line, err)
			}
			cl = n
		}
	}
}
