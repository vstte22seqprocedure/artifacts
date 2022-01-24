test TestAsyncSyncTag[main = TestDriverAsync0]: assert SyncTagInvariant in { TestDriverAsync0, Replica, Timer };

test TestAsyncLogConsistencyBasic[main = TestDriverAsync0]: assert LeadersConsistencyInvariant in { TestDriverAsync0, Replica, Timer };

test TestSyncLogConsistencyBasic[main = TestDriverSync0]: assert LeadersConsistencyInvariant in { TestDriverSync0, ViewStampedReplicationSync, SyncReplica };
