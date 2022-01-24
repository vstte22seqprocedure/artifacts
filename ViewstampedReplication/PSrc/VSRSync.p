type Messages = map[machine, Mbox];

machine ViewStampedReplicationSync
{
    var quorum : int;
    var PHASE : Phase;
    var participants : set[machine];
    var failures : map[machine, map[Phase, bool]];

    var messages : Messages;

    var msg_sent: int;
    var command: any;

    var i, j : int;
    var p, dst : machine;

    start state Init 
    {
        entry (payload: (participants: set[machine], quorum: int)){

            participants = payload.participants;
            quorum = payload.quorum;
            
            PHASE = 0; 
            Init(PHASE);

            announce eMonitor_Initialize, participants;
        }

        on LeaderRequest do 
        {
            goto STARTVIEWCHANGE;
        }
    }

    state STARTVIEWCHANGE
    {
        entry 
        {
            i = 0;
            while (i < sizeof(participants)){
                p = participants[i];
                if(!failures[p][PHASE]){
                    j = 0;
                    while (j < sizeof(participants)){
                        if($){
                            send this, eMessage, (phase = PHASE, from=p, payload=null);
                            dst = participants[j];
                            receiveMessageBlocking(dst, STARTVIEWCHANGE);
                        }
                        j = j + 1;
                    }
                }
                i = i + 1;
            }

            i = 0;
            while (i < sizeof(participants)) {
                p = participants[i];

                // buggy quorum
                if(sizeof(messages[p][PHASE][STARTVIEWCHANGE]) >= quorum-1){
                    // NoOp
                }else{
                    failures[p][PHASE] = true;
                    announce eMonitor_NewLeader, (phase=PHASE, leader=primary(PHASE, participants));
                }
                i=i+1;
            }

            goto DOVIEWCHANGE;
        }

    }

    state DOVIEWCHANGE
    {
        entry 
        {
            while (i < sizeof(participants)){
                p = participants[i];
                if(!failures[p][PHASE]){
                    if($){
                        send this, eMessage, (phase = PHASE, from=p, payload = null);
                        receiveMessageBlocking(primary(PHASE, participants), DOVIEWCHANGE);
                    }
                }
                i = i + 1;
            }

            // Update
            i = 0;
            while (i < sizeof(participants)) {
                p = participants[i];

                if(p == primary(PHASE, participants)){
                    // buggy quorum
                    if(sizeof(messages[p][PHASE][DOVIEWCHANGE]) >= quorum-1){
                        announce eMonitor_NewLeader, (phase=PHASE, leader=primary(PHASE, participants));
                    }else{
                        failures[p][PHASE] = true;
                        announce eMonitor_NewLeader, (phase=PHASE, leader=primary(PHASE, participants));
                    }
                }else{
                    // Follower NoOp
                }
                i=i+1;
            }
            
            // Primary decides using votes
            goto STARTVIEW;
        }

    }

    state STARTVIEW
    {
        entry 
        {
            while (i < sizeof(participants)){
                p = participants[i];
                if(!failures[p][PHASE]){
                    if($){
                        send this, eMessage, (phase = PHASE, from=primary(PHASE, participants), payload = true);
                        receiveMessageBlocking(p, STARTVIEW);
                    }
                }
                i = i + 1;
            }

            // Update
            i = 0;
            while (i < sizeof(participants)) {
                p = participants[i];

                if(sizeof(messages[p][PHASE][STARTVIEW]) == 1){
                    if(p != primary(PHASE, participants)){
                        announce eMonitor_NewLeader, (phase=PHASE, leader=primary(PHASE, participants));
                    }
                }else{
                    failures[p][PHASE] = true;
                    announce eMonitor_NewLeader, (phase=PHASE, leader=primary(PHASE, participants));
                }
                i=i+1;
            }

            if(!failures[primary(PHASE, participants)][PHASE]){
                print(format("primary(PHASE, participants) finish succesfully phase {0}, failures {1}", PHASE, failures));
            }
            

            PHASE = PHASE+1;
            Init(PHASE);

        }

        on LeaderRequest do
        {
            goto STARTVIEWCHANGE;
        }

    }


    fun Init(phase: Phase)
    {
        var i: int; 
        var p: machine;
        
        i = 0;

        failures = default(map[machine,map[Phase, bool]]);

        messages = default(Messages);
        
        while (i < sizeof(participants)) {
            p = participants[i];

            failures[p] = default(map[Phase, bool]);
            failures[p][PHASE] = false;

            messages[p] = default(Mbox);
            messages[p][PHASE] = default(map[Round, set[Message]]);

            messages[p][PHASE][STARTVIEWCHANGE] = default(set[Message]);
            messages[p][PHASE][DOVIEWCHANGE] = default(set[Message]);
            messages[p][PHASE][STARTVIEW] = default(set[Message]);

            i = i+1;
        }

    }

    fun receiveMessageBlocking(pdest: machine, r : Round)
    {
        receive {
            case eMessage: (m: Message) { 
                messages[pdest][PHASE][r] += (m); 
            }
        }
    }

    // buggy primary function
    fun primary(phase: Phase, participants: set[machine]) : machine{
        return choose(participants);
    }

}
