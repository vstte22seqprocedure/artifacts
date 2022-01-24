// checks that all events are handled correctly and also the local assertions in the P machines.
test TestAsyncAgreement_ReorderDelays[main = TestDriverAsyncAgreement_ReorderDelays]: assert Agreement in { TestDriverAsyncAgreement_ReorderDelays, Process, Timer};

test TestAsyncAgreement_ReorderDelaysTimeout[main = TestDriverAsyncAgreement_ReorderDelaysTimeout]: assert Agreement in { TestDriverAsyncAgreement_ReorderDelaysTimeout, Process, Timer};

test TestAsyncAgreement_ArbitraryNetwork[main = TestDriverAsyncAgreement_ArbitraryNetwork]: assert Agreement in { TestDriverAsyncAgreement_ArbitraryNetwork, Process, Timer};

test TestSeqAgreementArbitraryNetwork[main = TestDriverSeqAgreement_ArbitraryNetwork]: assert Agreement in { TestDriverSeqAgreement_ArbitraryNetwork, BenOrSeq_ArbitraryNetwork, Participant };

test TestSeqAgreementGoodNetwork[main = TestDriverSeqAgreement_GoodNetwork]: assert Agreement in { TestDriverSeqAgreement_GoodNetwork, BenOrSeq_GoodNetwork, Participant };
