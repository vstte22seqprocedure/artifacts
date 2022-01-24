# Paxos in the P language

## To compile

```
pc -proj:Paxos.pproj
```
## Experiments SYNC
```
pmc POutput/netcoreapp3.1/Paxos.dll -m PImplementation.TestPaxosSeq_ArbitraryNetwork.Execute -i 10000

for i in {1..100}; do pmc POutput/netcoreapp3.1/Paxos.dll -m PImplementation.TestPaxosSeq_ArbitraryNetwork.Execute -i 10000; done > experimentSeqArbitraryNetwork
```

## Experiments ASYNC
```
pmc POutput/netcoreapp3.1/Paxos.dll -m PImplementation.TestPaxosAsync_ReorderDelays.Execute -i 10000
```

```
pmc POutput/netcoreapp3.1/Paxos.dll -m PImplementation.TestPaxosAsync_Timeouts.Execute -i 10000
```

```
pmc POutput/netcoreapp3.1/Paxos.dll -m PImplementation.TestPaxosAsync_UnreliableNetworkTimeouts.Execute -i 10000
```