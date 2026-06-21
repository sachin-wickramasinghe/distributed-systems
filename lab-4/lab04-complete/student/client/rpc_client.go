package main

// ============================================================
// Lab 04 — RPC and Web Services
// File: rpc_client.go  (net/rpc client)
// Role: Connect to net/rpc server and call methods
//
// TASK IN THIS FILE:
//   Task 4 — Implement RPCClient
// ============================================================

// ── HOW net/rpc CLIENT WORKS ──────────────────────────────
//
// net/rpc client workflow:
//   1. rpc.Dial("tcp", "server:7000")  → connect
//   2. client.Call("Handler.Method", args, &reply)  → call
//   3. client.Close()  → disconnect
//
// "KVHandler.Put" means:
//   - Type registered with rpc.Register: KVHandler
//   - Method name: Put
//
// ──────────────────────────────────────────────────────────

import (
	"fmt"
	"net/rpc"
)

// RPCClient wraps a net/rpc connection
type RPCClient struct {
	addr   string
	client *rpc.Client
}

// ============================================================
// TASK 4 — Implement RPCClient
// ============================================================
//
// ── Connect ───────────────────────────────────────────────
// Dial the server and store the connection in r.client
// Use: rpc.Dial("tcp", r.addr)
// Print: [net/rpc] Connected to addr
//
// TODO: implement
func (r *RPCClient) Connect() error {
	// YOUR CODE HERE
	client, err := rpc.Dial("tcp", r.addr)
	if err != nil {
		return err
	}
	r.client = client
	fmt.Printf("[net/rpc] Connected to %s\n", r.addr)
	return nil
}

// ── Put ───────────────────────────────────────────────────
// Call "KVHandler.Put" with PutArgs{Key: key, Value: value}
// Return error if call fails or Success is false
//
// TODO: implement
func (r *RPCClient) Put(key, value string) error {
	// YOUR CODE HERE
	if r.client == nil {
		return fmt.Errorf("not connected")
	}

	args := &PutArgs{Key: key, Value: value}
	var reply PutReply
	if err := r.client.Call("KVHandler.Put", args, &reply); err != nil {
		return err
	}
	if !reply.Success {
		return fmt.Errorf("put failed")
	}
	return nil
}

// ── Get ───────────────────────────────────────────────────
// Call "KVHandler.Get" with GetArgs{Key: key}
// Return reply.Value, reply.Found, error
//
// TODO: implement
func (r *RPCClient) Get(key string) (string, bool, error) {
	// YOUR CODE HERE
	if r.client == nil {
		return "", false, fmt.Errorf("not connected")
	}

	args := &GetArgs{Key: key}
	var reply GetReply
	if err := r.client.Call("KVHandler.Get", args, &reply); err != nil {
		return "", false, err
	}
	return reply.Value, reply.Found, nil
}

// ── Delete ────────────────────────────────────────────────
// Call "KVHandler.Delete" with DeleteArgs{Key: key}
// Return reply.Deleted, error
//
// TODO: implement
func (r *RPCClient) Delete(key string) (bool, error) {
	// YOUR CODE HERE
	if r.client == nil {
		return false, fmt.Errorf("not connected")
	}

	args := &DeleteArgs{Key: key}
	var reply DeleteReply
	if err := r.client.Call("KVHandler.Delete", args, &reply); err != nil {
		return false, err
	}
	return reply.Deleted, nil
}

// ── List ──────────────────────────────────────────────────
// Call "KVHandler.List" with ListArgs{}
// Return reply.Keys, error
//
// TODO: implement
func (r *RPCClient) List() ([]string, error) {
	// YOUR CODE HERE
	if r.client == nil {
		return nil, fmt.Errorf("not connected")
	}

	args := &ListArgs{}
	var reply ListReply
	if err := r.client.Call("KVHandler.List", args, &reply); err != nil {
		return nil, err
	}
	return reply.Keys, nil
}

// ── Close ─────────────────────────────────────────────────
// Close the connection: r.client.Close()
//
// TODO: implement
func (r *RPCClient) Close() {
	// YOUR CODE HERE
	if r.client != nil {
		r.client.Close()
	}
}

// NewRPCClient creates a new RPCClient for the given address
func NewRPCClient(addr string) *RPCClient {
	return &RPCClient{addr: addr}
}
