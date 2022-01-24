
type Phase = int;
type Mbox = map[Phase, map[Round, set[MessageType]]];
type Log = seq[(commited: bool, logentry: any)];
type ConfigEntry = set[machine];

type InitMessageType = set[machine];
event InitMessage : InitMessageType; 

type MessageType = (phase: Phase, from: machine, payload: any);
event eMessage : MessageType;

type ProposeMessageType = (phase: Phase, from: machine, payload: Log);
event ProposeMessage: ProposeMessageType;

type AckMessageType = (phase: Phase, from: machine, payload: Log);
event AckMessage: AckMessageType;

type CommitMessageType = (phase: Phase, from: machine, payload: Log);
event CommitMessage: CommitMessageType;

enum Round { PROPOSE, ACK, COMMIT }

machine Server {   
    var servers : set[machine];
    var phase : int;
    var mbox : Mbox;
    var log : Log;
    var timer : Timer;
    var ack : bool;
    var commit : bool;
    var initialconfig : ConfigEntry;

    start state Init {
        defer ProposeMessage, AckMessage, CommitMessage;
        
        entry {
            var newserver : machine;

            init_phase(0);
            
            timer = CreateTimer(this);

            receive {
                case InitMessage: (payload: InitMessageType) { 
                    servers = payload;
                    initialconfig = servers;
                    log = add_to_log(log, servers, true);

                    if(this == primary(phase, initialconfig)){
                        newserver = new Server();
                        servers += (newserver);
                        log = add_to_log(log, servers, false);
                    }
                }
            }

            goto Propose;
        }
    }

    state Propose {

        defer AckMessage, CommitMessage;

        entry {
            var lastconfig : ConfigEntry;

            if(this == primary(phase, initialconfig)){
                lastconfig = get_last_config(log);

                UnReliableBroadCast(lastconfig, ProposeMessage, (phase=phase, from=this, payload=log));
                //ReliableBroadCast(lastconfig, ProposeMessage, (phase=phase, from=this, payload=log));
                ack = true;

                goto Ack;
            }

            StartTimer(timer);
        }

        on ProposeMessage do (m: ProposeMessageType) {
            CancelTimer(timer);

            if(m.phase == phase && validExtendedLog(log, m.payload as Log)){
                ack = true;
            }else{
                ack = false;
            }
            goto Ack;
        }

        on eTimeOut do {
            goto Ack;
        }
    }

    state Ack {

        defer ProposeMessage, CommitMessage;

        entry {
            if(ack){
                if($){
                    send primary(phase, initialconfig), AckMessage, (phase=phase, from=this, payload=log);
                }
            }

            if(this != primary(phase, initialconfig)){
                goto Commit;
            }
            StartTimer(timer);
        }

        on AckMessage do (m: AckMessageType) {
            var lastconfig : ConfigEntry;
            lastconfig = get_last_config(log);

            if(m.phase == phase && this == primary(phase, initialconfig)){
                mbox[m.phase][ACK] += (m);

                print(format("SERVER {0} RECEIVED {1} ACK MESSAGES, EXPECTING: {2} ", this, sizeof(mbox[m.phase][ACK]), sizeof(servers)/2 + 1));

                if(sizeof(mbox[m.phase][ACK]) >= sizeof(lastconfig)/2 + 1){
                    CancelTimer(timer);

                    commit = true;
                    goto Commit;
                }
            }
        }

        on eTimeOut do {
            goto Commit;
        }

    }

    state Commit {

        defer ProposeMessage, AckMessage;

        entry {
            var lastconfig : ConfigEntry;
            lastconfig = get_last_config(log);

            if(this == primary(phase, initialconfig) && commit){
                UnReliableBroadCast(lastconfig, CommitMessage, (phase=phase, from=this, payload=log));
                //ReliableBroadCast(lastconfig, CommitMessage, (phase=phase, from=this, payload=log));
                init_phase(phase+1);
                goto Propose;
            }

            StartTimer(timer);
        }

        on CommitMessage do (m: CommitMessageType) {
            if(m.phase == phase){
                CancelTimer(timer);

                log = m.payload;

                announce eMonitor_NewLog, (id=this, newlog=log);
                
                init_phase(phase+1);
                goto Propose;
            }
        }

        on eTimeOut do {
            init_phase(phase+1);
            goto Propose;
        }
    }

    fun init_phase(p: Phase){
        phase = p;
        ack = false;
        commit = false;

        mbox[p] = default(map[Round, set[MessageType]]);

        mbox[p][PROPOSE] = default(set[MessageType]);
        mbox[p][ACK] = default(set[MessageType]);
        mbox[p][COMMIT] = default(set[MessageType]);
    }

    fun primary(phase: int, participants: set[machine]) : machine {
        var candidates : set[machine];
        var m : machine;
       
        candidates += (participants[0]);
        candidates += (participants[1]);

        m = roundrobin(phase, candidates);

        return m;
    }

}

fun add_to_log(l: Log, element: any, commited: bool) : Log {
    if(sizeof(l) == 0 || element != l[sizeof(l)-1]){
        l += (sizeof(l), (commited=commited, logentry=element));
    }  
    
    return l;
}

// Returns the last config that is commited
fun get_last_config(l: Log) : ConfigEntry {
    // var i : int;
    // i = sizeof(l)-1;

    assert(sizeof(l)>0);

    // while(i > 0){
        
    //     if(l[i].commited){
    //         return l[i].logentry as ConfigEntry;
    //     }
    //     i = i-1;
    // }

    // return l[0].logentry as ConfigEntry;

    return l[sizeof(l)-1].logentry as ConfigEntry;
}

fun commit_log(l: Log) {
    var i : int;
    i = 0;

    while(i < sizeof(l)){
        l[i].commited = true;
        i = i+1;
    }
}

fun validExtendedLog(oldlog: Log, newlog: Log) : bool {
    var i: int;

    if(sizeof(newlog) < sizeof(oldlog)){
        return false;
    }

    i = 0;

    while(i < sizeof(oldlog)){
        if (oldlog[i].logentry != newlog[i].logentry){
            return false;
        }
        i=i+1;
    }

    return true;
}