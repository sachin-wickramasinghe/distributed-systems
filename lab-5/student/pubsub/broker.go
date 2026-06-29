package main

// ============================================================
// Lab 05 — Event Queues and Pub/Sub
// File: broker.go  (Pub/Sub system)
// Role: Core broker — topic registry and fan-out delivery
//
// TASKS IN THIS FILE:
//   Task 8  — NewBroker()
//   Task 9  — Subscribe()
//   Task 10 — Unsubscribe()
//   Task 11 — Publish()
//   Task 14 — multiple topics support (built into the above)
// ============================================================

import (
	"fmt"
	"sync"
)

// Event is a structured message — has a topic, a key, and a value.
type Event struct {
	Topic string
	Key   string
	Value string
	Seq   int64
}

// Subscriber represents one subscriber's connection info.
type Subscriber struct {
	ID   string
	Addr string
}

// Broker manages MULTIPLE topics. Each topic has its own
// independent list of subscribers.
type Broker struct {
	mu          sync.RWMutex
	subscribers map[string][]Subscriber
	seqCounters map[string]int64
}

// ============================================================
// TASK 8 — NewBroker
// ============================================================
// Create and return a new Broker.
//
// Steps:
//   1. Create a Broker with:
//        subscribers: make(map[string][]Subscriber)
//        seqCounters: make(map[string]int64)
//   2. Return a pointer to it
//
// TODO: implement this function
func NewBroker() *Broker {
	// YOUR CODE HERE
	return &Broker{
		subscribers: make(map[string][]Subscriber),
		seqCounters: make(map[string]int64),
	}
}

// ============================================================
// TASK 9 — Subscribe
// ============================================================
// Register a subscriber for a topic.
//
// Steps:
//   1. Lock: b.mu.Lock() / defer b.mu.Unlock()
//   2. Append the subscriber to b.subscribers[topic]
//   3. Print: [BROKER] Subscriber sub.ID joined topic="..."
//
// TODO: implement this function
func (b *Broker) Subscribe(topic string, sub Subscriber) {
	// YOUR CODE HERE
	b.mu.Lock()
	defer b.mu.Unlock()
	b.subscribers[topic] = append(b.subscribers[topic], sub)
	fmt.Printf("[BROKER] Subscriber %s joined topic=%q\n", sub.ID, topic)
}

// ============================================================
// TASK 10 — Unsubscribe
// ============================================================
// Remove a subscriber from a topic.
//
// Steps:
//   1. Lock: b.mu.Lock() / defer b.mu.Unlock()
//   2. Build a new slice excluding the subscriber with matching ID
//   3. Print: [BROKER] Subscriber subID left topic="..."
//
// TODO: implement this function
func (b *Broker) Unsubscribe(topic, subID string) {
	// YOUR CODE HERE
	b.mu.Lock()
	defer b.mu.Unlock()

	current := b.subscribers[topic]
	filtered := make([]Subscriber, 0, len(current))
	for _, sub := range current {
		if sub.ID != subID {
			filtered = append(filtered, sub)
		}
	}
	b.subscribers[topic] = filtered
	fmt.Printf("[BROKER] Subscriber %s left topic=%q\n", subID, topic)
}

// ============================================================
// TASK 11 — Publish
// ============================================================
// Fan-out a message to ALL subscribers of a topic.
//
// Steps:
//   1. Lock, increment seq counter, copy subscriber list, unlock
//   2. Create the event
//   3. For EACH subscriber, deliver concurrently via goroutine + RPC
//   4. Print: [BROKER] Published topic="..." key="..." -> N subscribers
//   5. Return the number of subscribers notified
//
// TODO: implement this function
func (b *Broker) Publish(topic, key, value string) int {
	// YOUR CODE HERE
	b.mu.Lock()
	b.seqCounters[topic]++
	seq := b.seqCounters[topic]
	subs := append([]Subscriber(nil), b.subscribers[topic]...)
	b.mu.Unlock()

	event := Event{Topic: topic, Key: key, Value: value, Seq: seq}

	var wg sync.WaitGroup
	for _, sub := range subs {
		wg.Add(1)
		go func(sub Subscriber) {
			defer wg.Done()
			var reply DeliverReply
			err := callRPC(sub.Addr, "SubscriberRPC.Deliver", &DeliverArgs{Event: event}, &reply)
			if err != nil {
				fmt.Printf("[BROKER] Deliver to subscriber=%s at %s failed: %v\n", sub.ID, sub.Addr, err)
			}
		}(sub)
	}
	wg.Wait()

	fmt.Printf("[BROKER] Published topic=%q key=%q -> %d subscribers\n", topic, key, len(subs))
	return len(subs)
}

// ============================================================
// Below this line — already implemented, do not change
// ============================================================

func (b *Broker) SubscriberCount(topic string) int {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return len(b.subscribers[topic])
}

func (b *Broker) Topics() []string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	topics := make([]string, 0, len(b.subscribers))
	for t := range b.subscribers {
		topics = append(topics, t)
	}
	return topics
}

func (b *Broker) String() string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return fmt.Sprintf("Broker{topics:%d}", len(b.subscribers))
}
