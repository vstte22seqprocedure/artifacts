event eMessage : MessageType;

event PrepareMessage: PrepareType;
event AckMessage: AckType;
event ProposeMessage: ProposeType;
event PromiseMessage: PromiseType;

event Config: (peers: set[machine], quorum: int, failurem: FailureModel);

type Command = int;
type RequestId = int;
type Phase = int;
type Mbox = map[Phase, map[Round, set[MessageType]]];
type Timestamp = (phase: Phase, round: Round);
type Log = seq[any];

type MessageType = (phase: Phase, from: machine, payload: any);

type PrepareType = (phase: Phase, from: machine, payload: Command);
type AckType = (phase: Phase, from: machine, payload: (last: Phase, log: Log));
type ProposeType = (phase: Phase, from: machine, payload: Log);
type PromiseType = (phase: Phase, from: machine, payload: Log);

enum Round { PREPARE, ACK, PROPOSE, PROMISE }

machine Process {   
    var participants : set[machine];
    var quorum : int;
    var phase : Phase;
    var last : Phase;
    var mbox : Mbox;
    var log : Log;
    var timer : Timer;
    var fm : FailureModel;

    var currentRequest : RequestId;

    start state Init {
        defer PrepareMessage, AckMessage, ProposeMessage, PromiseMessage;
        
        entry {
            receive {
                case Config: (payload: (peers: set[machine], quorum: int, failurem: FailureModel)) { 
                    participants = payload.peers;
                    quorum = payload.quorum;
                    fm = payload.failurem;
                }
            }
            timer = CreateTimer(this);
            
            phase = 0;
            last = phase;
            goto Prepare;
        }
    }

    state Prepare {
        defer AckMessage, ProposeMessage, PromiseMessage;

        entry {
            if(primary(phase, participants) == this){
                BroadCast(fm, participants, PrepareMessage, (phase=phase, from=this, payload = null));
            }
            MaybeStartTimer(fm,timer);
        }

        on PrepareMessage do (m : PrepareType) {
            if(m.phase >= phase){
                print(format("roundCompleted PREPARE {0}", this));
                MaybeCancelTimer(fm,timer);
                last = phase; // BUG, remove
                phase = m.phase;
                goto Ack;
            }
        }

        on eShutDown do {
            raise halt;
        }

        on eTimeOut do {
            timeout();
        }
    }

    state Ack {
        defer PrepareMessage, ProposeMessage, PromiseMessage;

        entry { 
            if(primary(phase, participants) != this){
                Send(fm, primary(phase, participants), AckMessage, (phase=phase, from=this, payload = (last=last, log=log)));
                goto Propose;
            }else{
                // primary waits
                MaybeStartTimer(fm,timer);
            }    
        }

        on AckMessage do (m : AckType) {
            var newCommand : Command;

            if(m.phase == phase){
                collectMessage(m, ACK);

                if(sizeof(mbox[phase][ACK]) >= quorum){
                    print(format("roundCompleted ACK {0}", this));
                    MaybeCancelTimer(fm,timer);
                    //log = select_log_from_received_messages(mbox[phase][ACK] as set[(phase: Phase, from: machine, payload: (last: Phase, log: Log))]);
                    log = select_log_from_received_messages(mbox[phase][ACK]);
                    newCommand = new_command();
                    log += (sizeof(log), newCommand);

                    goto Propose;
                }                
            }
        }

        on eShutDown do {
            raise halt;
        }

        on eTimeOut do {
            timeout();
        }
    }

    state Propose {

        defer PrepareMessage, AckMessage, PromiseMessage;

        entry {
            if(primary(phase, participants) == this){
                BroadCast(fm, participants, ProposeMessage, (phase=phase, from=this, payload = log));
            }
            MaybeStartTimer(fm,timer);
        }

        on ProposeMessage do (m : ProposeType) {
            if(m.phase == phase){
                print(format("roundCompleted PROPOSE {0}", this));
                MaybeCancelTimer(fm,timer);

                log = m.payload;
                //last = phase; // BUG, add

                goto Promise;
            }
        }

        on eShutDown do {
            raise halt;
        }

        on eTimeOut do {
            timeout();
        }
    }

    state Promise {

        defer PrepareMessage, AckMessage, ProposeMessage;

        entry {
            BroadCast(fm, participants, PromiseMessage, (phase=phase, from=this, payload = log));
            
            MaybeStartTimer(fm,timer);
        }

        on PromiseMessage do (m : PromiseType) {
            if(m.phase == phase){
                collectMessage(m, PROMISE);

                if(sizeof(mbox[phase][PROMISE]) >= quorum){
                    print(format("roundCompleted PROMISE {0}", this));
                    MaybeCancelTimer(fm,timer);

                    if(logs_are_equal(mbox[phase][PROMISE])){
                        announce eMonitor_NewLog, (id=this, newlog=log);
                    }
                    phase = phase+1;
                    goto Prepare;                 
                }                
            }
        }

        on eShutDown do {
            raise halt;
        }

        on eTimeOut do {
            timeout();
        }
    }

    fun collectMessage(m:MessageType, r: Round) {
        if(!(m.phase in mbox)){
            init_mbox(m.phase);
        }
        
        mbox[m.phase][r] += (m);

        print(format("{0} collected message {1} {2} in phase, MAILBOX {3}", this, r, phase, mbox));
    }

    fun init_mbox(phase: Phase) {
        mbox[phase] = default(map[Round, set[MessageType]]);

        mbox[phase][PROMISE] = default(set[MessageType]);
        mbox[phase][ACK] = default(set[MessageType]);
    }

    fun timeout(){
        phase = phase+1;
        init_mbox(phase);

        print(format("{0} timeouts! move to phase {1}", this, phase));

        goto Prepare;
    }

}

fun select_log_from_received_messages(messages : set[MessageType]) : Log {
    var msg : MessageType;
    var ackmsg : AckType;
    var higherlast, i : int;
    var higherlog : Log;

    //print(format("select_log_from_received_messages logs to compare {0}", messages));

    i = 0;
    higherlast = -1;

    while(i < sizeof(messages)){
        msg = messages[i];
        ackmsg = msg as AckType;

        if(ackmsg.payload.last > higherlast){
            higherlog = ackmsg.payload.log;
            higherlast = ackmsg.payload.last; 
            //print(format("select_log_from_received_messages Higher log found  {0} with last {1}", ackmsg.payload.log, ackmsg.payload.last));
        }
        
        i=i+1;
    }

    return higherlog;
}

fun logs_are_equal(messages : set[MessageType]) : bool{
    var msg : PromiseType;
    var log : Log;
    var i : int;
    
    assert sizeof(messages) > 0;

    i = 0;

    msg = messages[0] as PromiseType;
    log = msg.payload;

    while(i < sizeof(messages)){
        msg = messages[i] as PromiseType;
        
        if(log != msg.payload){
            return false;
        }
        
        i=i+1;
    }

    return true;
}

fun new_command() : Command {
    return choose(5);
}