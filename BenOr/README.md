# BenOr in the P language

## To compile

```
pc -proj:BenOr.pproj
```

## SyncTag test

```
pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestAsyncSyncTag.Execute -i 10000
```

## Experiments SYNC
```
pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestSeqAgreementArbitraryNetwork.Execute -i 10000

for i in {1..100}; do pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestSeqAgreementArbitraryNetwork.Execute -i 10000; done > experimentSeqArbitraryNetwork


pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestSeqAgreementGoodNetwork.Execute -i 10000

for i in {1..100}; do pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestSeqAgreementGoodNetwork.Execute -i 10000; done > experimentSeqGoodNetwork
```

## Experiments ASYNC
```
pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestAsyncAgreement_ReorderDelays.Execute -i 10000

pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestAsyncAgreement_ReorderDelaysTimeout.Execute -i 10000

pmc POutput/netcoreapp3.1/BenOr.dll -m PImplementation.TestAsyncAgreement_ArbitraryNetwork.Execute -i 10000
```