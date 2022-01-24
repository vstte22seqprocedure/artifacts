// checks that all events are handled correctly and also the local assertions in the P machines.

test TestPaxosAsync_ReorderDelays[main = TestDriverPaxosAsync_ReorderDelays]: assert LogConsistency in { TestDriverPaxosAsync_ReorderDelays, Process, Timer };

test TestPaxosAsync_Timeouts[main = TestDriverPaxosAsync_Timeouts]: assert LogConsistency in { TestDriverPaxosAsync_Timeouts, Process, Timer };

test TestPaxosAsync_UnreliableNetworkTimeouts[main = TestDriverPaxosAsync_UnreliableNetworkTimeouts]: assert LogConsistency in { TestDriverPaxosAsync_UnreliableNetworkTimeouts, Process, Timer };

test TestPaxosSeq_ArbitraryNetwork[main = TestDriverPaxosSeq_ArbitraryNetwork]: assert LogConsistency in { TestDriverPaxosSeq_ArbitraryNetwork, Participant, PaxosSeq_ArbitraryNetwork };
