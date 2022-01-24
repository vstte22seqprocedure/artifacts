// We would like to assert the atomicity property that if a transaction is committed by the coordinator then it was agreed on by all participants

event eMonitor_TimestampChange : (id: machine, ts: Timestamp);
event eMonitor_MessageReceived : (localTs: Timestamp, msgTs: Timestamp);
event eMonitor_Send : (localTs : Timestamp, sentTs: Timestamp);
event eMonitor_MailboxUsed : (id: machine, mboxTs: Timestamp);

spec SyncTagInvariant observes eMonitor_Initialize, eMonitor_TimestampChange, eMonitor_MessageReceived, eMonitor_MailboxUsed, eventSTARTVIEWCHANGE, eventDOVIEWCHANGE, eventSTARTVIEW
{
    // a map saving the current phase for every participant
    var participants : set[machine];
    var participantsTimestamp: map[machine, Timestamp];
    var numParticipants: int;
    start state Init {
        on eMonitor_Initialize goto WaitForEvents with (participants: set[machine]) {
            var i: int; 

            participants = participants;
            numParticipants = sizeof(participants);

            i = 0;
            while (i < numParticipants) 
            {
                participantsTimestamp[participants[i]] = (phase=0, round=STARTVIEWCHANGE);
                i = i + 1;
            }
        }
    }

    state WaitForEvents {
        on eMonitor_TimestampChange do (payload: (id: machine, ts: Timestamp)){
            assertStateMonotonicallyIncreasing(payload.id, payload.ts);
        }

        on eMonitor_MessageReceived do (payload: (localTs: Timestamp, msgTs: Timestamp)){
            assertReceivedMessageIsFromGeqTime(payload.localTs, payload.msgTs);
        }

        on eMonitor_MailboxUsed do (payload: (id: machine, mboxTs: Timestamp)){
            assertUsedMessageIsFromLocalTime(payload.id, payload.mboxTs);
        }
        
        on eventSTARTVIEWCHANGE do (m: Message) {
            assertSendWithCurrentTimestamp(m.from, (phase=m.phase, round=STARTVIEWCHANGE));
        }

        on eventDOVIEWCHANGE do (m: Message){
            assertSendWithCurrentTimestamp(m.from, (phase=m.phase, round=DOVIEWCHANGE));
        }

        on eventSTARTVIEW do (m: Message) {
            assertSendWithCurrentTimestamp(m.from, (phase=m.phase, round=STARTVIEW));
        }

    }

    fun assertReceivedMessageIsFromGeqTime(localTs : Timestamp, msgTs : Timestamp)
    {
         assert (geqTimestamp(localTs,msgTs)), format ("Received and stored message with past timestamp. Timestamp local state {0}, received message {1}", localTs, msgTs);
    }

    fun assertSendWithCurrentTimestamp(id : machine, sendTs : Timestamp)
    {
        var currentTs : Timestamp;
        currentTs = participantsTimestamp[id];

        assert (equalTimestamp(currentTs,sendTs)), format ("{0} sent with different timestamp. Timestamp before {1}, new {2}", id, currentTs, sendTs);

    }

    fun assertStateMonotonicallyIncreasing(id : machine, newTs : Timestamp)
    {
        var currentTs : Timestamp;

        currentTs = participantsTimestamp[id];
        
        assert (geqTimestamp(currentTs,newTs)),
        format ("{0} Participant decreased its local timestamp. Timestamp before {1}, new {2}", id, currentTs, newTs);

        participantsTimestamp[id] = newTs;
    }

    fun assertUsedMessageIsFromLocalTime(id : machine, mboxTs : Timestamp)
    {
        var currentTs : Timestamp;
        currentTs = participantsTimestamp[id];

        assert (equalTimestamp(currentTs,mboxTs)), format ("Participant used mbox in timestamp {0} being in time {1}", mboxTs, currentTs);

    }    

    // Check if ts1 <= ts2
    fun geqTimestamp(ts1 : Timestamp, ts2 : Timestamp) : bool
    {
        return ts2.phase > ts1.phase || (ts2.phase == ts1.phase && roundInt(ts1.round) <= roundInt(ts2.round));
    }

    fun equalTimestamp(ts1 : Timestamp, ts2 : Timestamp) : bool
    {
        return ts2.phase == ts1.phase && roundInt(ts1.round) == roundInt(ts2.round);
    }

    fun roundInt(r : Round) : int
    {
        if(r == STARTVIEWCHANGE){
            return 0;
        }else if(r == DOVIEWCHANGE){
            return 1;
        }else {
            return 2;
        }
    }
}