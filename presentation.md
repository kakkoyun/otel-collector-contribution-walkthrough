---
marp: true
theme: otel
paginate: true
size: 16:9
html: true
header: 'Navigating the Collector: A Contributor''s Field Guide'
style: |
    .columns {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 1rem;
    }
    .small {
        font-size: 0.75em;
    }
    .tiny {
        font-size: 0.6em;
    }
---

<!-- _class: lead -->
<!-- _paginate: skip -->
<!-- _header: '' -->

# Navigating the Collector

## A Contributor's Field Guide

Kemal Akkoyun · OpenTelemetry Maintainer · Datadog

---

# Why Does a 7-Line PR Take 6 Weeks?

A real contributor's mdatagen PR. Eight comments over three weeks:

```
May 07  ✔ CLA signed
May 07  → "should I also implement multipleOf?"
May 08  ← "no use case yet, wait"
May 09  → "fixed linter — forgot to run make fmt"
May 11  ← "please rebase and fix CI failures"
May 12  → "done, can you re-run the CI?"
May 15  → "can you help me start the CI workflows?"
May 26  ✔ merged
```

This is **not** a Bloomberg problem. It is the ecosystem.

<span class="small">

[opentelemetry-collector#15270](https://github.com/open-telemetry/opentelemetry-collector/pull/15270)

</span>

---

# Three Axes of Complexity

| Architectural | Social | Historical |
|---|---|---|
| multi-module repo | CODEOWNERS sprawl | accreted APIs |
| `go.mod` per component | maintainer math | renamed types |
| codegen / mdatagen | review SLOs | why does this exist? |
| stability tiers | stale-bot churn | |

**The Collector is complicated for structural reasons, not accidental ones.**

> The way through is to work *with* the constraints — not around them.

---

<!-- _class: lead -->

# Why Is It Complicated?
## Architectural

---

# One Repository. ~25 Go Modules. 250+ Components.

**opentelemetry-collector-contrib** — each component is its own `go.mod`:

```
receiver/hostmetricsreceiver/go.mod
receiver/kafkareceiver/go.mod
processor/attributesprocessor/go.mod
extension/basicauthextension/go.mod
...
```

Why? **Version isolation.** A security fix in one receiver's dependency
should not force a version bump across unrelated components.

The cost: **every component is an independent module release.**

<span class="small">

[versions.yaml · 0093005](https://github.com/open-telemetry/opentelemetry-collector/blob/009300517f680bae6ebf0640f3d8213ec888e4ab/versions.yaml)

</span>

---

# The Module Version Map

`versions.yaml` defines release sets — two parallel versioning tracks:

```yaml
module-sets:
  stable:
    version: v1.59.0      # ← semver stability guaranteed
    modules:
      - go.opentelemetry.io/collector/pdata
      - go.opentelemetry.io/collector/component
      - go.opentelemetry.io/collector/confmap
      - go.opentelemetry.io/collector/pipeline
      ...
  beta:
    version: v0.153.0     # ← may break between minor releases
    modules:
      - go.opentelemetry.io/collector
      - go.opentelemetry.io/collector/internal/memorylimiter
      ...
```

**Stable APIs move slower. Beta can break.** Know which track you are on.

<span class="small">

[versions.yaml · 0093005](https://github.com/open-telemetry/opentelemetry-collector/blob/009300517f680bae6ebf0640f3d8213ec888e4ab/versions.yaml)

</span>

---

# The Lockstep Problem

Change a core interface → must update every contrib module that depends on it.

```
  opentelemetry-collector (core)      opentelemetry-collector-contrib
  ──────────────────────────────      ───────────────────────────────
  1. PR-A: change API
  2. cut release  ────────────────►   (waits for release tag)
                                      3. PR-B: bump go.mod
                                           replace directives
                                           in N component modules
```

A **single API change** requires coordinated PRs across two repositories,
N `go.mod` files, weeks of stagger.

This is why large refactors are rare and slow.
**Scope your work to stay within one module boundary.**

---

# Codegen Is the Source of Truth

Every component has a `metadata.yaml` — the single source of truth for identity, stability, owners, and feature gates:

```yaml
# receiver/hostmetricsreceiver/metadata.yaml
type: host_metrics
status:
  class: receiver
  stability:
    beta:        [metrics]
    development: [logs]
  codeowners:
    active: [dmitryax, braydonk, rogercoll]
feature_gates:
  - id: receiver.hostmetricsreceiver.UseLinuxMemAvailable
    stage: beta
```

<span class="small">

[receiver/hostmetricsreceiver/metadata.yaml · 3c4f53a](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/3c4f53a6a69e5c971b4ed39da605bc98b80c138b/receiver/hostmetricsreceiver/metadata.yaml)

</span>

---

# Codegen Is the Source of Truth

`mdatagen` reads `metadata.yaml` and generates Go code you never edit by hand:

```
metadata.yaml  →  internal/metadata/generated_metrics.go
               →  internal/metadata/generated_config.go
               →  internal/metadata/generated_status.go
```

**Edit `metadata.yaml`. Never edit the generated files.**

The feature-gate migration PRs are doing exactly this — moving feature gate declarations from hand-written Go into `metadata.yaml` so `mdatagen` owns the output.

---

# Stability Tiers Set Expectations

| Tier | Meaning | API guarantees | Review pace |
|------|---------|---------------|-------------|
| **Development** | experimental | none | slow / may not merge |
| **Alpha** | usable, not stable | breaking ok | moderate |
| **Beta** | stable API intended | no breaks | moderate–fast |
| **Stable** | production-grade | no breaks | fast (high scrutiny) |
| **Deprecated** | scheduled removal | — | — |

`hostmetricsreceiver`: **beta for metrics, development for logs** —
same component, different stability per signal type.

**Know the tier before you PR. It sets realistic expectations.**

---

<!-- _class: lead -->

# Why Is It Complicated?
## Social

---

# CODEOWNERS Is the Org Chart

Each component declares its owners in `metadata.yaml`:

```yaml
# receiver/hostmetricsreceiver/metadata.yaml
codeowners:
  active: [dmitryax, braydonk, rogercoll]
```

When you open a PR, GitHub routes review to those humans —
across multiple companies, time zones, day jobs.

```
  Your PR
    │
    └──► GitHub assigns → dmitryax  (Datadog,  UTC-8)
                          braydonk  (Google,   UTC-5)
                          rogercoll (Grafana,  UTC+2)
```

**Review latency is not indifference. It is calendar math.**

---

# Maintainer Math

250+ components in contrib. A handful of core maintainers who can approve anything.
Component approvers who can only approve their slice.

The "priority components" list exists because maintainers had to triage **themselves**:

```
  PRs/week across all components → ~30–50
  Maintainer review capacity     → finite
  ────────────────────────────────────────────
  Non-priority component PR wait → days to weeks
  Priority component PR wait     → 1–3 days
```

**This is not a broken process. It is a governance model under load.**

Find the priority list: [contrib#44130](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/44130)

---

# The Welcome Bot Encodes the Culture

Every first-time contributor PR to contrib gets this — **verbatim:**

> First-time contributors should have **at most one PR not marked as draft**
> until their first PR is merged.
>
> If your change isn't one of our **priority components**, reviews may take more time.
>
> Give reviewers **at least a few days** before pinging them for feedback.
>
> If you need help... raise the topic on **#otel-collector-dev** or a
> **Collector SIG meeting**.

The rules are already written down. **Read them.**

<span class="small">

[opentelemetry-collector-contrib#48716](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48716) · first-time contributor welcome

</span>

---

# Stale-Bot Is a Tool, Not a Verdict

~3,000 open issues in contrib. Without the stale-bot, noise drowns signal.

Issues and PRs inactive for **60 days** → `stale` label. After 30 more days → **auto-close.**

When your PR goes quiet for 7 days:

* Rebase on `main`
* Ping the CODEOWNER — once, politely, with context

---

# Stale-Bot Is a Tool, Not a Verdict

Still quiet after 30 days:

* Raise in `#otel-collector-dev`
* Add to Collector SIG meeting agenda
* Two full cycles with no movement? **Come back with a smaller scope.**
* An 8-month gap before a codeowner replied is real ([contrib#35305](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/35305)). **Plan for it.**

---

<!-- _class: lead -->

# Deciphering Convoluted Issues

---

# Read the Labels First

GitHub labels tell you the invitation level before reading a single line of the body:

| Label | What it signals |
|-------|----------------|
| `good first issue` | Bounded scope, codeowner-tagged, clear acceptance |
| `help wanted` | Maintainers want this but don't have bandwidth |
| `needs triage` | No owner yet — lower urgency |
| `priority:p1` / `p2` | Actively tracked |
| `lifecycle:unmaintained` | No active owners — may not merge |
| `area:confmap` / `receiver/` | Routes to subsystem or component |

**Labels encode the invitation level. Start there.**

---

# Trace Config → Component → Owner

Given any pipeline fragment — here is the path to the right human:

```yaml
receivers:
  hostmetrics:
    collection_interval: 10s
```

1) `"hostmetrics"` → `receiver/hostmetricsreceiver/`
2) Open `metadata.yaml` → read `status.stability` and `codeowners.active`
3) Check last merged PR by those handles — active recently?
4) Open an issue: describe the problem, not the solution. Ping the owner.

**You can do this for any component in the repo.**

---

# Recognize a Good First Issue in the Wild

**[internal/aws] migrate to AWS v2 SDK** · [contrib#37728](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/37728)

| | |
|---|---|
| **Scope** | One package — bounded, no cross-module blast |
| **Owner** | @mx-psi actively engaged in umbrella [#36699](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36699) |
| **Shape** | "remove v1 imports, add v2 equivalents" — clear acceptance criteria |
| **Tier** | Not stable — API changes allowed |

---

# Recognize a Good First Issue in the Wild

**[cmd/mdatagen] Move feature gates to metadata.yaml** · [#46116](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/46116)

| | |
|---|---|
| **Scope** | One component at a time — take as many as you want |
| **Shape** | Mechanical migration — hard to get catastrophically wrong |
| **Pattern** | Every feature gate needs this — a stack of work is available |

**The shape of a good entry door: bounded, owner-engaged, clear acceptance.**

---

<!-- _class: lead -->

# The Playbook
## Signal Intent First

---

# Signal Intent First

The single most important thing Pierre and I want you to take from this session:

* **Ask before building.**
* **Build the smallest thing that proves the idea.**
* **Make it easy for the maintainer to say yes.**

---

# Signal Intent First

A PR that surprises a maintainer is one they must evaluate from scratch.

A PR that follows a tracked issue and a prior conversation
is one they can approve in 10 minutes.

**The work is often the same. The outcome is not.**

---

# Four Questions Before You Write Code

Before opening a PR — or writing a single line:

* **Is this a priority component?**
  → [contrib#44130](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/44130)

* **Has this been discussed before?**
  → Search closed PRs *and* SIG meeting notes — closed ≠ rejected

* **Who are the CODEOWNERS and are they active recently?**
  → `metadata.yaml` → `codeowners.active` → check their last merged PR

* **Should I open an issue first?**
  → "I'd like to implement X because Y. Does this direction make sense?"

---

# Where to Signal

<div class="columns">

<div>

**GitHub issue**
Use when: new idea, feature request, bug report
Do: describe the *problem*, not the solution
Link: related issues, prior art, your use case

**Draft PR**
Use when: you have a prototype worth discussing
Do: open as draft, mark "not for review yet"
Signals: you're serious, here's the shape of my thinking

</div>

<div>

**#otel-collector-dev** (CNCF Slack)
Use when: quick sanity-check, "is this the right approach?"
Do: one message with context + link to your issue

**Collector SIG meeting**
Use when: blocked PR, cross-cutting RFC, design question
Do: add to agenda 48h in advance
→ [SIG calendar](https://github.com/open-telemetry/community?tab=readme-ov-file#sig-collector)

</div>

</div>

---

# Case Study A: The Secret Manager Saga

The problem — Thomas's RFC ([contrib#48277](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/48277)):

> "A lot of production infrastructure stores and rotates secrets through managed stores.
> The gap means teams end up **running a sidecar just to fetch the secret and write it
> to disk** so the file watcher can pick it up."

Happy to contribute this upstream if there's appetite for it.

---

# Case Study A: What Happened

* Pavel opens [#48380](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48380) — full AWS impl inside `basicauthextension`

* Thomas: *"separate ext avoids pulling AWS SDK into basicauthextension"*

* Pavel closes #48380, opens [#48414](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48414) — extract shared logic → `extension/internal/basicauth` **(MERGED)**

* Thomas → [#48406](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48406) · Mikiyas → [#48474](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48474) + [#48477](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48477) · Larry → [#48484](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48484)

---

# Case Study A: The Lesson

Four engineers. Four cloud providers. Four parallel PRs. All mergeable.

<div class="columns">

<div>

**Without early coordination**
- 4 PRs duplicating basicauth logic
- each pulling a different cloud SDK
- maintainer: dependency graph wrong, can't accept

</div>

<div>

**With early coordination**
- 1 shared internal pkg (Pavel) — MERGED
- 3 cloud-specific extensions, each reviewable alone
- clean dependency graph, maintainer says yes

</div>

</div>

**Pavel:** *"Yes, a shared internal module sounds like the right approach."*
**Thomas:** *"Thanks! We'll update our PR to be built on top of your changes now!"*

<span class="small">

[contrib#48277](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/48277) · [contrib#48414](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48414) · [contrib#48474](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48474) · [contrib#48484](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48484)

</span>

---

# Case Study B: The 7-Line PR

Abhimanyu's depguard rule ([contrib#48716](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48716)):

```diff
+  [linters-settings.depguard.rules.aws-sdk-v1]
+    deny = [{ pkg = "github.com/aws/aws-sdk-go",
+              desc = "use AWS SDK v2 instead, see #36699" }]
```

The PR description opens with:

> "Per discussion with @mx-psi in #36699, this is the **recommended first step**
> to prevent regression while remaining component migrations complete."

Seven lines. One sentence linking to the prior conversation. **Immediately reviewable.**

Contrast: a 500-line cross-component migration, no prior discussion, lands cold
in a maintainer's queue → weeks of back-and-forth, possible rejection.

**Small PRs with prior context are the fast lane.**

<span class="small">

[contrib#48716](https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/48716) · [contrib#36699](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36699)

</span>

---

# Case Study C: When the Workflow Fights You

A real mdatagen PR — every newcomer friction, in one thread:

```
May 07  CLA bot fires
May 07  contributor: "should I also implement multipleOf?"   ← scope question  ✓
May 08  maintainer:  "no use case yet, don't bother"         ← scope locked, proceed
May 09  contributor: "forgot make fmt, fixed"                ← linter bite
May 11  maintainer:  "please rebase and fix CI failures"
May 12  contributor: "done — can you re-run the CI?"         ← CI needs maintainer
May 15  contributor: "can you help me start the CI workflows?"
May 26  merged
```

Three weeks. 452 additions. **Not unusual. Not a failure.**

The scope question on day one was exactly right —
it saved a revision cycle later.

<span class="small">

[opentelemetry-collector#15270](https://github.com/open-telemetry/opentelemetry-collector/pull/15270)

</span>

---

# The Survival Moves: During a PR

| Situation | Action |
|-----------|--------|
| CLA bot fires | Sign once at [identity.linuxfoundation.org](https://identity.linuxfoundation.org/projects/cncf) — never again |
| CI needs a re-run | Comment: `@<codeowner> could you trigger CI?` |
| "rebase" request | `git fetch upstream && git rebase upstream/main` — do it same day |
| Linter failure | `make fmt lint` before every push |

---

# The Survival Moves: When It Goes Quiet

| Situation | Action |
|-----------|--------|
| No response 7 days | One polite ping to the CODEOWNER named in `metadata.yaml` |
| No response 30 days | Raise in `#otel-collector-dev` or Collector SIG agenda |
| Stale-bot fires | Comment to reset; rebase if behind |
| Two cycles, still stuck | Reconsider scope — is there a smaller first step? |

**One PR at a time until your first merge.** The welcome-bot rule exists for a reason.

---

# What Contributions Are Most Welcome Right Now

| Contribution type | Why it moves fast |
|---|---|
| Bug fixes on priority components | Fast review lane |
| Component README / doc gaps | Low risk, always welcome |
| `metadata.yaml` feature-gate migrations | Mechanical, maintainers need help |
| Semconv attribute updates | Contributor-friendly, active community |
| AWS SDK v1 → v2 migration | Active umbrella [#36699](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36699), owner engaged |

---

# Before You Start

**Check three things before writing a line of code:**

1. Is it on the priority list? → [contrib#44130](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/44130)
2. Does an umbrella issue exist? → claim it, don't create a parallel one
3. Is the codeowner active? → check their last merged PR in that component

**Avoid as a first PR:** new component from scratch, cross-repo API changes,
anything touching `pdata` or `confmap` core internals.

---

<!-- _class: lead -->

# Closing

---

# The Maintainer's Plea

Speaking as one:

* **Small PRs.** One idea. One module. Reviewable in one sitting.

* **Intent first.** Open an issue. Start a thread. *"Does this direction make sense?"* before *"Here is my 800-line PR."*

* **Patience with pings.** A few days. Not a few hours. We are not ignoring you.

---

# Your Next Step Tonight

Pick **one** component you have used or are working on.

1) Find `receiver/<name>/metadata.yaml` or `extension/<name>/metadata.yaml`
2) Read `status.stability` + `codeowners.active`
3) Search open issues labeled `good first issue` scoped to that component
4) Comment: *"I'd like to take a look at this."*

---

# Your Next Step Tonight

That comment tells the codeowner a human is alive and interested.
It starts the conversation before the code exists.

**The contribution starts before the code.**

---

<!-- _paginate: skip -->

# References

<div class="columns">

<div class="small">

**Your work — keep going:**
- Secret-manager cluster: [contrib#48277](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/48277)
- AWS SDK v2 migration: [contrib#36699](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36699)
- Priority components: [contrib#44130](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/44130)

**Community:**
- [#otel-collector-dev](https://cloud-native.slack.com/archives/C07CCCMRXBK) (CNCF Slack)
- [Collector SIG meeting](https://github.com/open-telemetry/community?tab=readme-ov-file#sig-collector)
- [CONTRIBUTING.md](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/CONTRIBUTING.md)
- [mdatagen README](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/cmd/mdatagen/README.md)

</div>

<div class="small">

**Curated issues (mentorship spreadsheet):**
→ drop link in chat

**Reading:**
- [Bloomberg: Sustaining OpenTelemetry](https://www.bloomberg.com/company/stories/sustaining-opentelemetry-why-bloomberg-joined-the-opentelemetry-project/)
- [CNCF Blog: Bloomberg × OTel](https://www.cncf.io/blog/2024/10/17/bloomberg-and-opentelemetry-sustaining-open-source-through-engineering-excellence/)

**First deck (architecture & internals):**
→ available on request


</div>

</div>
