package main

// ============================================================
// Lab 04 — RPC and Web Services
// File: types.go  (client)
// Role: Mirrors the net/rpc request/reply structs from the server.
//       net/rpc uses encoding/gob so both sides must define the
//       same exported fields — the package names can differ.
// ============================================================

type PutArgs struct {
	Key   string
	Value string
}

type PutReply struct {
	Success bool
}

type GetArgs struct {
	Key string
}

type GetReply struct {
	Value string
	Found bool
}

type DeleteArgs struct {
	Key string
}

type DeleteReply struct {
	Deleted bool
}

type ListArgs struct{}

type ListReply struct {
	Keys []string
}
