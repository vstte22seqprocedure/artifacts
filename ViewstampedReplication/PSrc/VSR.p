event eMessage : Message;

event eventSTARTVIEWCHANGE: (phase: Phase, from: machine, payload: data);
event eventDOVIEWCHANGE: (phase: Phase, from: machine, payload: data);
event eventSTARTVIEW: (phase: Phase, from: machine, payload: data);

type Phase = int;
type Mbox = map[Phase, map[Round, set[Message]]];
type Timestamp = (phase: Phase, round: Round);
type Message = (phase: Phase, from: machine, payload: any);

event eConfig: (participants: set[machine], quorum: int);
event LeaderRequest;

enum Round { STARTVIEWCHANGE, DOVIEWCHANGE, STARTVIEW }

machine Replica
{
    var phase : Phase;
    var participants: set[machine];
    var quorum : int;
    var mbox : Mbox;
    var timer : Timer;

    start state Init 
    {
        defer LeaderRequest, eventSTARTVIEWCHANGE, eventDOVIEWCHANGE, eventSTARTVIEW;

        entry
        {
            receive {
                case eConfig: (payload: (participants: set[machine], quorum: int)) { 
                    participants = payload.participants;
                    quorum = payload.quorum;
                }
            }

            phase = 0;
            print(format("{0} enters phase {1}", this, phase));
            
            timer = CreateTimer(this);
            goto WaitForLeaderRequest;
        }
    }

    state WaitForLeaderRequest
    {
        defer eTimeOut, eventDOVIEWCHANGE, eventSTARTVIEWCHANGE, eventSTARTVIEW;

        on LeaderRequest do 
        {
            if(this == primary(phase, participants)){
                UnReliableBroadCast(participants, LeaderRequest, null);
            }

            goto STARTVIEWCHANGE;
        }
    }

    state STARTVIEWCHANGE
    {
        defer LeaderRequest, eventDOVIEWCHANGE, eventSTARTVIEW;

        entry  {
            announce eMonitor_TimestampChange, (id=this, ts=(phase=phase, round=STARTVIEWCHANGE));

            UnReliableBroadCast(participants, eventSTARTVIEWCHANGE, (phase=phase, from=this, payload=null));
            StartTimer(timer);
        }

        on eventSTARTVIEWCHANGE do (m : Message) 
        {
            if(m.phase == phase){
                announce eMonitor_MessageReceived, (localTs=(phase=phase, round=STARTVIEWCHANGE), msgTs=(phase=m.phase, round=STARTVIEWCHANGE));

                announce eMonitor_MailboxUsed, (id=this, mboxTs=(phase=m.phase, round=STARTVIEWCHANGE));
                collectMessage(m, STARTVIEWCHANGE);

                // buggy quorum
                if(sizeof(mbox[m.phase][STARTVIEWCHANGE]) >= quorum-1)
                { 
                    CancelTimer(timer);
                    goto DOVIEWCHANGE;
                }
            }
        }

        on eTimeOut do { 
            timeout();
        }

    }

    state DOVIEWCHANGE
    {
        defer LeaderRequest, eventSTARTVIEWCHANGE, eventSTARTVIEW;

        entry {
            announce eMonitor_TimestampChange, (id=this, ts=(phase=phase, round=DOVIEWCHANGE));

            UnReliableSend(primary(phase, participants), eventDOVIEWCHANGE, (phase = phase, from=this, payload = null));

            if(this == primary(phase, participants)){
                StartTimer(timer);
            }else{
                goto STARTVIEW;
            }
            
        }

        on eventDOVIEWCHANGE do (m : Message) 
        {
            if(this == primary(phase, participants) && m.phase == phase){
                announce eMonitor_MessageReceived, (localTs=(phase=phase, round=DOVIEWCHANGE), msgTs=(phase=m.phase, round=DOVIEWCHANGE));

                announce eMonitor_MailboxUsed, (id=this, mboxTs=(phase=m.phase, round=DOVIEWCHANGE));
                collectMessage(m, DOVIEWCHANGE);

                if(sizeof(mbox[m.phase][DOVIEWCHANGE]) >= quorum-1)
                { 
                    announce eMonitor_NewLeader, (phase=phase, leader=primary(phase, participants));
                    CancelTimer(timer);
                    goto STARTVIEW;
                }
            }
        }

        on eTimeOut do { 
            timeout();
        }

    }

    state STARTVIEW
    {
        defer LeaderRequest, eventSTARTVIEWCHANGE, eventDOVIEWCHANGE;

        entry {
            announce eMonitor_TimestampChange, (id=this, ts=(phase=phase, round=STARTVIEW));

            if(this == primary(phase, participants)){
                UnReliableBroadCast(participants, eventSTARTVIEW, (phase=phase, from=this, payload=null));
            }          
            StartTimer(timer); 
        }

        on eventSTARTVIEW do (m : Message) 
        {
            if(m.phase == phase){
                announce eMonitor_MessageReceived, (localTs=(phase=phase, round=STARTVIEW), msgTs=(phase=m.phase, round=STARTVIEW));

                announce eMonitor_MailboxUsed, (id=this, mboxTs=(phase=m.phase, round=STARTVIEW));
                collectMessage(m, STARTVIEW);

                CancelTimer(timer);

                announce eMonitor_NewLeader, (phase=phase, leader=primary(phase, participants));

                phase = phase+1;
                print(format("{0} enters phase {1}", this, phase));

                goto WaitForLeaderRequest;
            }
        }

        on eTimeOut do { 
            timeout();
        }

    }

    fun initMbox(phase: Phase)
    {
        mbox[phase] = default(map[Round, set[Message]]);

        mbox[phase][STARTVIEWCHANGE] = default(set[Message]);
        mbox[phase][DOVIEWCHANGE] = default(set[Message]);
        mbox[phase][STARTVIEW] = default(set[Message]);
    }

    fun collectMessage(m: Message, r: Round)
    {
        if(!(m.phase in mbox)){
            initMbox(m.phase);
        }
        mbox[m.phase][r] += (m);
    }

    fun timeout()
    {
        CancelTimer(timer);
        phase = phase+1;
        goto STARTVIEWCHANGE;
        //raise halt;
    }

    // buggy primary function
    fun primary(phase: Phase, participants: set[machine]) : machine{
        return choose(participants);
    }
}