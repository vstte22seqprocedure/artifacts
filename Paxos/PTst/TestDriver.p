
/*
This machine creates the 2 participants, 1 coordinator, and 2 clients 
*/

machine TestDriverPaxosAsync_ReorderDelays {
    start state Init {
        entry {
            launchASync((n=3, quorum=2, f=0, fm=ReliableNetwork));
        }
    }
}

machine TestDriverPaxosAsync_Timeouts {
    start state Init {
        entry {
            launchASync((n=3, quorum=2, f=0, fm=ReliableNetworkWithTimeouts));
        }
    }
}

machine TestDriverPaxosAsync_UnreliableNetworkTimeouts {
    start state Init {
        entry {
            launchASync((n=3, quorum=2, f=0, fm=UnreliableNetworkWithTimeouts));
        }
    }
}

machine Participant{
    start state Init {}
}

machine TestDriverPaxosSeq_ArbitraryNetwork {
    start state Init {
        entry {
            launchSeq((n=3, quorum=2, f=0));
        }
    }
}

fun launchASync(config: (n: int, quorum: int, f: int, fm: FailureModel))
{
    var participants: set[Process];
    var i, j: int;

    assert(config.quorum >= config.n/2);
    assert(config.f < config.quorum);

    i = 0;
    while (i < config.n) {
        participants += (new Process());
        i = i + 1;
    }

    i = 0;
    while (i < config.n) {
        send participants[i], Config, (peers=participants, quorum=config.quorum, failurem=config.fm);
        i=i+1;
    }

    announce eMonitor_Initialize, config.f; 

}

fun launchSeq(config: (n: int, quorum: int, f: int))
{
    var system : PaxosSeq_ArbitraryNetwork;
    var i, j : int;
    var p : machine;
    var participants: set[Participant];

    assert(config.quorum >= config.n/2);
    assert(config.f < config.quorum);
    
    i = 0;
    while (i < config.n) {
        participants += (new Participant());
        i = i + 1;
    }    

    announce eMonitor_Initialize, config.f;
    
    system = new PaxosSeq_ArbitraryNetwork((peers=participants, quorum=config.quorum));
 
}