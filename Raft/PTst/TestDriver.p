machine TestDriverRaftAsync {
    start state Init {
        entry {
            var servers: set[Server];
            var emptyset: set[Server];
            var s5, s6 : Server;
            var i, n: int;
            var log: Log;

            // Servers
            n = 4;

            i = 0;
            while (i < n) {
                servers += (new Server());
                i=i+1;
            }

            log = default(Log);
            add_to_log(log, servers, true);

            i = 0;
            while (i < n) {
                send servers[i], InitMessage, servers;
                i=i+1;
            }

        }
    }
}

machine SeqServer{
    start state Init {}
}

machine TestDriverRaftSeq {
    start state Init {
        entry {
            var system : RaftSeq;
            var i, j : int;
            var servers: set[machine];
            
            i = 0;
            while (i < 4) {
                servers += (new SeqServer());
                i = i + 1;
            }    
            
            system = new RaftSeq(servers);
        }
    }
}
