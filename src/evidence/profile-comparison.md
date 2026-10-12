# Small and standard: capacity comparison

This file supports the Module 5 profile decision. It is calculated configuration evidence, not measured usage or a billing export. The source is the two files in `platform/profiles/`. Every application component has one replica.

| Profile  | Steady CPU requests | Steady memory requests | Steady CPU limits | Steady memory limits |
| -------- | ------------------- | ---------------------- | ----------------- | -------------------- |
| Small    | 500m                | 640Mi                  | 2500m             | 1792Mi               |
| Standard | 900m                | 1152Mi                 | 2500m             | 3328Mi               |

If every Deployment temporarily has two Pods during a simultaneous rollout, standard requests total 1800m and 2304Mi; limits total 5000m and 6656Mi. The namespace allows requests of 2000m/3Gi and limits of 6000m/8Gi. Injected containers, terminating Pods, actual memory use, and the gateway are not represented by doubling these values. The gateway and platform controllers run outside this namespace.
Use observed startup, restarts, memory peaks, and model latency from rehearsal to decide whether the profiles are appropriate. Do not present these requests as measurements.
Reducing requests does not necessarily reduce the Azure bill. Include the Standard control cluster, Automatic shared capacity and idle overhead, storage, monitoring, and hosted-model tokens when evaluating the complete offering. Model capacity and resource quota are not spending caps. Current price, region, currency, subscription offer, input/output token counts, and a measurement interval are needed for a monetary comparison. None is invented by this worksheet.
Choose one profile for the application's observed demand, explain the trade-off, and record what evidence could change the decision. Same-session billing data is not required.
