package main

// ============================================================
// Lab 05 — Event Queues and Pub/Sub
// File: worker.go  (Event Queue system)
// Role: Worker pool — multiple workers pulling concurrently
//
// TASK IN THIS FILE:
//   Task 7 — RunWorkerPool()
// ============================================================

import (
	"fmt"
	"math/rand"
	"time"
)

// ============================================================
// TASK 7 — RunWorkerPool
// ============================================================
// Launch numWorkers goroutines that each continuously:
//   1. Dequeue a task from queueName (via RPC to the broker)
//   2. "Process" it (simulate work with a short sleep)
//   3. Ack it (via RPC)
//
// This must guarantee NO TWO WORKERS process the same task —
// because Dequeue removes the task from the channel, only one
// worker can ever receive a given task. Your job is to make
// sure each worker runs this loop independently and concurrently.
//
// Steps:
//   1. For i := 0 to numWorkers-1:
//        launch a goroutine (go func(workerID string) { ... }(...))
//        each goroutine loops forever:
//          a. Call Dequeue RPC with a unique workerID (e.g. "worker-1")
//          b. Print: [WORKER workerID] Processing task=ID payload="..."
//          c. Simulate work: time.Sleep(time.Duration(rand.Intn(200)) * time.Millisecond)
//          d. Call Ack RPC with the task ID
//          e. Print: [WORKER workerID] Done task=ID
//   2. This function should return immediately after launching
//      the goroutines (it does not block)
//
// HINT: each goroutine needs its OWN connection or use callRPC()
//       which dials fresh each time (simpler, slightly less efficient)
//
// TODO: implement this function
func RunWorkerPool(brokerAddr, queueName string, numWorkers int) {
	// YOUR CODE HERE
	for i := 0; i < numWorkers; i++ {
		workerID := fmt.Sprintf("worker-%d", i+1)
		go func(workerID string) {
			for {
				var deqReply DequeueReply
				err := callRPC(brokerAddr, "QueueRPC.Dequeue",
					&DequeueArgs{QueueName: queueName, WorkerID: workerID}, &deqReply)
				if err != nil {
					fmt.Printf("[WORKER %s] Dequeue failed: %v\n", workerID, err)
					time.Sleep(200 * time.Millisecond)
					continue
				}

				task := deqReply.Task
				fmt.Printf("[WORKER %s] Processing task=%s payload=%q\n", workerID, task.ID, task.Payload)
				time.Sleep(time.Duration(rand.Intn(200)) * time.Millisecond)

				var ackReply AckReply
				err = callRPC(brokerAddr, "QueueRPC.Ack", &AckArgs{TaskID: task.ID}, &ackReply)
				if err != nil {
					fmt.Printf("[WORKER %s] Ack failed for task=%s: %v\n", workerID, task.ID, err)
					continue
				}
				if !ackReply.Success {
					fmt.Printf("[WORKER %s] Ack rejected for task=%s\n", workerID, task.ID)
					continue
				}

				fmt.Printf("[WORKER %s] Done task=%s\n", workerID, task.ID)
			}
		}(workerID)
	}
}
