# Attendee instructions

Start with the [PREL37 workshop guide](../docs/README.md). The current learner material lives in `docs/`, with an overview, six numbered modules, a summary, and troubleshooting.
The same material supports an instructor-guided session and self-paced learning. The proposed guided session is four hours, including two ten-minute breaks, pending live rehearsal. Each technical module protects time for explanation, demonstration, guided practice, debrief, and questions.

Use the prepared `~/prel37` workspace and its two private repositories. Local services, tools, cloud resources, and separate repository credentials are organizer preparation, not additional learner exercises. You review and manually merge allowed pull requests, honoring any externally configured branch checks; no custom validation workflow ships with the lab.

Setup stops with healthy provider/functions, a shared gateway, and a rendered but unapplied instance mapping. Module 2 teaches provider access, delivery permissions, EnvironmentConfig, and root Argo watches before the first environment request. Do not require root sync or an installed `AppEnvironment` API before that module. Its wiring and API-establishment time are included in the proposed agenda, not yet validated.

For self-paced preparation, follow the [setup guide](../setup/README.md) first, including `setup/bootstrap.sh` before the modules and the native UI startup commands. The same guide owns teardown. Implementation assets do not establish that your VM or resources are ready; live rehearsal and per-learner verification remain necessary.
