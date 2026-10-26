# Recover the application through Git

This runbook keeps recovery on the same Git path as every other change, so the fix is reviewed and auditable. Read the Argo CD error and the desired Git revision before changing anything. For the intended Module 5 failure, only `image.tag` changed to `latest`. Restore the immutable tag from `~/prel37/config/artifact-lock.json` in the application repository's `apps/fourth-coffee/values.yaml`, submit a pull request, review the diff, honor any externally configured branch checks, and merge normally. The chart schema allows the locked tag or `latest`; runtime admission rejects `latest`. There is no custom lab CI exception or validation workflow.

Keep the selected profile, ServiceAccounts, ConfigMap binding, Argo project, destination, and source revisions unchanged. A healthy ReplicaSet from an earlier revision does not prove the rejected revision was delivered. Match the recovered source revision and verify a fresh application interaction.

Do not delete the namespace, apply the namespace Terraform from the VM, remove controller finalizers, broaden permissions, or grant a pod a model API key as a recovery shortcut. Preparation failures belong with the organizer.
