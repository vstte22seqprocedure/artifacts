# Viewstamped Replication in the P language

## To compile

```
pc -proj:ViewStampedReplication.pproj
```

## Run model checking with 1000 schedulers
```
pmc netcoreapp3.1/ViewStampedReplication.dll -m PImplementation.TestSyncBasic.Execute -i 10000

pmc netcoreapp3.1/ViewStampedReplication.dll -m PImplementation.TestAsyncBasic.Execute -i 10000

pmc netcoreapp3.1/ViewStampedReplication.dll -m PImplementation.TestAsyncSyncTag.Execute -i 10000
```

## Experiments SEQ
```
for i in {1..100}; do pmc netcoreapp3.1/ViewStampedReplication.dll -m PImplementation.TestSyncLogConsistencyBasic.Execute -i 1000; done > experimentSeq
```

## Experiments ASYNC
```
for i in {1..100}; do pmc netcoreapp3.1/ViewStampedReplication.dll -m PImplementation.TestAsyncLogConsistencyBasic.Execute -i 1000; done > experimentAsync
```
