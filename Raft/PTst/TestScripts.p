test TestRaftAsync[main = TestDriverRaftAsync]: assert LogConsistency in { TestDriverRaftAsync, Server, Timer };

test TestRaftSeq[main = TestDriverRaftSeq]: assert LogConsistency in { TestDriverRaftSeq, SeqServer, RaftSeq };