
/*
This machine creates the 2 participants, 1 coordinator, and 2 clients 
*/

machine TestDriverSync0 {
    start state Init {
        entry {
            launchSync(3, 2, 10000);
        }
    }
}

fun launchSync(n: int, quorum: int, requests: int)
{
    var system : ViewStampedReplicationSync;
    var i : int;
    var participants: set[SyncReplica];
    
    i = 0;
    while (i < n) {
        participants += (new SyncReplica());
        i = i + 1;
    }
    
    system = new ViewStampedReplicationSync((participants=participants, quorum=quorum));
    
    i = 0;
    while(i < requests){
        send system, LeaderRequest;
        i = i + 1;
    }
}

machine SyncReplica {
    start state Init {
    }
}

machine TestDriverAsync0 {
    start state Init {
        entry {
            launchASync(3, 2, 10000);
        }
    }
}

fun launchASync(n: int, quorum: int, requests: int)
{
    var participants: set[machine];
    var i : int;
 
    i = 0;
    while (i < n) {
        participants += (new Replica());
        i = i + 1;
    }

    announce eMonitor_Initialize, participants;
    
    i = 0;
    while (i < n) {
        send participants[i], eConfig, (participants=participants, quorum=quorum);
        i=i+1;
    }

    i = 0;
    while(i < requests){
        send primary(0, participants), LeaderRequest;
        i = i + 1;
    }
}


