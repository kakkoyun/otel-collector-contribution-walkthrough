# Navigating the Collector: A Contributor's Field Guide

Follow-up talk for the **Bloomberg "Sustaining OpenTelemetry" Mentorship Program**, June 2026.

## Talk metadata

| | |
|---|---|
| **Title** | Navigating the Collector: A Contributor's Field Guide |
| **Series** | ⚙️ Deep Dive: Advanced Collector Contribution Walkthrough |
| **Presenter** | Kemal Akkoyun · OpenTelemetry Maintainer · Datadog |
| **Audience** | Bloomberg mentees actively contributing to Collector PRs |
| **Duration** | ~25 min (20 min speaking + 5 min Q&A) |
| **Slides** | ~28 content slides |
| **Format** | Marp, slide-only, no live demo |

## Context

The [first talk](../otel-collector-deep-dive/) covered Collector architecture — component types,
the DAG, the factory pattern, OCB, and contribution scaffolding. This follow-up addresses the
question the first talk raised but did not answer: *how do you actually get work merged in a
maintainer-bottlenecked, multi-module, socially complex open-source project?*

The thesis: **signal intent first — don't build in isolation.**

## Build

```bash
make install   # install Marp CLI (once)
make watch     # live preview in browser
make html      # build presentation.html
make pdf       # build presentation.pdf
make serve     # serve at http://localhost:8000
make validate  # check for PERMALINK_PLACEHOLDERs and slide count
make clean     # remove build artifacts
```

## Mentee cohort (June 2026)

| Name | GitHub | Work |
|------|--------|------|
| Thomas Baldwin | @thomasbaldwin | AWS secret-manager basicauth extension |
| Mikiyas Bokan | @meebok | AWS + GCP secret-manager extensions |
| Larry Zebaze | @donny-z | Azure Key Vault basicauth extension |
| Pavel Lazureykis | @lazureykis | confmap, feature-gate migrations, shared basicauth pkg |
| Abhimanyu Narwal | @anarwal | AWS SDK v1→v2 migration |

## Key artifacts referenced in the deck

| Artifact | What it illustrates |
|----------|---------------------|
| [contrib#48277](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/48277) | Secret-manager RFC — real production pain quote |
| [contrib#48414](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48414) | Pavel's shared pkg — coordination payoff (merged) |
| [contrib#48716](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48716) | Abhimanyu's 7-line depguard PR — small + prior context |
| [contrib#36699](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36699) | AWS SDK v2 migration umbrella |
| [collector#15270](https://github.com/open-telemetry/opentelemetry-collector/pull/15270) | Anonymized friction case study — newcomer workflow |
| [contrib#44130](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/44130) | Priority components list |
