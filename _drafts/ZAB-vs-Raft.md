---
title: ZAB vs Raft
---

As a way to refresh myself on the two protocols, I wanted to write up a comparison between ZAB (Zookeeper
Atomic Braodcast (protocol)) and Raft (the concensus algorithm behind etcd, consul, etc). First let's get an
overview of each.

## ZAB

<!--

  - What is a broadcast protocol? Is it a class of algorithms?
  - Is designed as a "primary backup system" (vs paxos which is state-replication). Differnce?
      - There _may_ be some ordering difference

  - Used for leader election.
  - Leader broadcasts all changes to followers.

-->

## Raft

## Key Differences

<!-- TODO: write about what really makes these algorithms different -->

### Chart all the things!

<!-- TODO:
        I think this would be a good place to put a comparison chart of ZAB and Raft with various attributes
        to quickly summarize which ones does what. Maybe even color code it with red/yellow/orange/green to
        get an idea of what may or may not be desirable (although that can be very subjective).
-->
