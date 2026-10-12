# Source

These are the raw materials of the platform: the repositories, API, templates, and evidence that learners wire together. Organizers personalize these assets using the explicit commands in [`setup/README.md`](../setup/README.md#4-prepare-the-repositories-and-platform). The learner's `setup/bootstrap.sh` only loads environment variables and cluster access. Setup installs packages and the shared gateway, connects credentials and the workload cluster, and renders `config/environment.yaml` without applying it. [Module 2](../docs/2-environment-contract.md) uses the committed wiring manifests to connect provider access, delivery permissions, trusted mapping, and root watches before the first request.

- `platform/`: the private platform repository, Crossplane API/module, charts,
  baseline, approved profiles, catalog, and native Backstage template.
- `app-deploy/`: the initially empty private application repository.
- `exercises/`: the three learner application files.
- `backstage/`: overlays for the existing pinned Backstage app, not another scaffold.
- `queries/`: the real-model correlation query.
- `evidence/`: qualified, calculated profile comparison, not measured billing.
- `answers/`: the learner's product worksheet.

The published application image and pinned Backstage source are recorded in [`setup/artifact-lock.json`](../setup/artifact-lock.json). The baseline supplies native cloud OTLP endpoints without an AKS monitoring CRD. The Fourth Coffee image and upstream OCI chart are pinned to the verified `0.1.0-12.1.ge412f12` release. The lab deploys the local `platform/charts/fourth-coffee` adapter so the platform retains identity, digest-pinning, and Gateway boundaries. The [artifact prerequisite](../setup/README.md#application-artifact-prerequisite) separates release capability from live deployment evidence. Use the [preparation runbook](../setup/README.md), then the [learner guide](../docs/README.md). Live rehearsal remains required.
