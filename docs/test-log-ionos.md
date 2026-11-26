# Test log – IONOS

Same stack and rules as the [Azure reference](test-log-azure.md). Honest record, including the agent's
own mistakes. Times are the user's wall-clock time.

## Step 0 – Account and tools (2026-11-27)

**What:** Check access, install the CLI.
**How:** Customer portal, GitHub release.

**Result:**
- The user already has an IONOS customer account (`mein.ionos.de`, hosting/domains). Its start page
  shows Black Friday advertising for the website builder first.
- **IONOS Cloud is a separate portal** (Data Center Designer) with **its own login**. The customer
  account does not lead directly to Managed Kubernetes. Two portals, two logins for one provider.
- **CLI `ionosctl`:** no winget, no Chocolatey package (checked); the docs mention Scoop, otherwise a
  ZIP from GitHub. Installed v6.10.5 from the official `ionos-cloud/ionosctl` release, SHA-256 checked
  against the release checksum file, unpacked, added to the user PATH. Same stumbling block as STACKIT.
- **The customer-account login does not work for the Data Center Designer.** IONOS Cloud needs its own
  registration/contract, even for an existing IONOS customer.
- **IONOS Cloud registration:** done by the user; no company fields so far (unlike STACKIT). Starts as a
  **test account**. The **€ 200 starting credit** is only granted after unlocking the "full version" of
  the virtual data center.
- **CLI login:** username + password prompt in the terminal or an API token (`--token`); **no browser
  login** (Scaleway: API key; Azure: browser login via `az login`). Typing a password into a terminal
  prompt is uncomfortable for the user.
- **Unlocking the full version** asks for company/organisation and address. To be checked whether a
  private person can complete it.
- Unlocking: a private address was accepted (no company needed so far). **Credit card form does not
  support browser autofill** – card details have to be typed by hand. Small, but annoying.
- Address and credit card submitted. **The full version is reviewed manually – "up to 24 h".** Until then
  only the test account. Second provider in a row (after Scaleway) where onboarding blocks the start.
- **Token Manager is only available in the full version.** No API token, so no CLI/Terraform access
  during the review either – nothing can even be checked read-only.

## Step 1 – Research and plan (2026-11-27, no account access)

**What:** Map the building blocks to IONOS from the docs and the price list, while the contract is under review.
**How:** IONOS docs and German price list (version 2026-10-29), GitHub releases.

**Result (to be confirmed after the unlock):**
- **No cloud load balancer** for `Service type=LoadBalancer`: IONOS attaches a public IP to one worker
  node. Simpler and cheaper, but a single ingress node.
- **DB certificate from Let's Encrypt** – the unchanged app should verify it (unlike Scaleway's own CA).
- **No native secret store**, **no OIDC for CI**, **no keyless image pull** – three gaps vs. Azure.
- **Cost Alert** exists (notification only, no cap).
- The price list says it applies to **business customers** – although a private address was accepted.
- Expected ≈ 131–141 €/month net, mainly the database (54 €: DBaaS cores cost 0.06 €/h). Most expensive
  of the three so far; the € 200 credit covers the test easily.
