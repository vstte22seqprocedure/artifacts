
/*
This machine creates the 2 participants, 1 coordinator, and 2 clients 
*/

machine TestDriverAsyncAgreement_ReorderDelays {
    start state Init {
        entry {
            launchASync((n=5, quorum=3, fm=ReliableNetwork));
        }
    }
}

machine TestDriverAsyncAgreement_ReorderDelaysTimeout {
    start state Init {
        entry {
            launchASync((n=3, quorum=2, fm=ReliableNetworkWithTimeouts));
        }
    }
}

machine TestDriverAsyncAgreement_ArbitraryNetwork {
    start state Init {
        entry {
            launchASync((n=3, quorum=2, fm=UnreliableNetworkWithTimeouts));
        }
    }
}


machine Participant{
    start state Init {}
}

machine TestDriverSeqAgreement_ArbitraryNetwork {
    start state Init {
        entry {
            
            var system : BenOrSeq_ArbitraryNetwork;
            var i : int;
            var p : machine;
            var participants: set[Participant];
            
            i = 0;
            while (i < 3) {
                participants += (new Participant());
                i = i + 1;
            }    
            
            system = new BenOrSeq_ArbitraryNetwork((peers=participants, quorum=2));
            
        }
    }
}

machine TestDriverSeqAgreement_GoodNetwork {
    start state Init {
        entry {
            
            var system : BenOrSeq_GoodNetwork;
            var i : int;
            var p : machine;
            var participants: set[Participant];
            
            i = 0;
            while (i < 3) {
                participants += (new Participant());
                i = i + 1;
            }    
            
            system = new BenOrSeq_GoodNetwork((peers=participants, quorum=2));
            
        }
    }
}

fun launchASync(config: (n: int, quorum: int, fm: FailureModel))
{
    var participants: set[Process];
    var i: int;

    assert(config.quorum >= config.n/2);

    i = 0;
    while (i < config.n) {
        participants += (new Process());
        i = i + 1;
    }

    i = 0;
    while (i < config.n) {
        send participants[i], Config, (peers=participants, quorum=config.quorum, failurem=config.fm, i=i);
        i=i+1;
    }

}