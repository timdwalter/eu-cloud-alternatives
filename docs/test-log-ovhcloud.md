# Test log – OVHcloud

Same stack and rules as the [Azure reference](test-log-azure.md). Honest record, including the agent's
own mistakes. Times are the user's wall-clock time.

## Step 0 – Website, account, research (2026-11-28)

**What:** Find the right OVHcloud, create the account, read-only research of the building blocks.
**How:** OVHcloud website and docs, GitHub releases.

**Result:**
- **Which OVHcloud?** The website is split by **country**, not by language. The first page the user
  reached offered only German and Spanish and showed prices in **US dollars** – a sign of the separate
  US company (OVHcloud US, own products and terms). The German site `ovhcloud.com/de/` shows **euro**
  prices. Easy to end up at the wrong legal entity – relevant for the sovereignty question.
- **Payment: PayPal is accepted** (user) – unlike Scaleway, where a debit card was accepted but never
  verified, and IONOS, which needed a credit card.
- Building blocks from the docs (to be confirmed): Managed Kubernetes **Free plan** (control plane free,
  single-zone regions, 99.5 % SLO) vs. Standard plan (3-AZ, SLA, control plane billed); Public Cloud
  Databases for PostgreSQL with a private network via **vRack**; Managed Private Registry (Harbor);
  **Secret Manager** (REST + Vault-compatible API); no OIDC federation for CI found (SAML for humans,
  OAuth2/API keys otherwise).
- Terraform provider `ovh/ovh`: latest 2.26.0 (2026-11-25, too new) → pin **2.24.0** (2026-10-29).
- **Payment method:** credit card added and **confirmed immediately** (user) – no waiting, no test-charge issue.
- **Prices:** the price tables on ovhcloud.com load dynamically and could not be read by the agent; the
  **public price catalogue API** (`eu.api.ovh.com/v1/order/catalog/public/cloud?ovhSubsidiary=DE`, EUR, no
  login) gives every price with technical specs – the most machine-readable price source in this series
  (Scaleway has a similar one).
- Expected (list prices, net): **≈ 110 €/month** – nodes 2 × d2-4 30 €, LB S 6 €, Floating IP 2 €,
  PostgreSQL Essential db1-4 (2 vCPU, 4 GB, 80 GB) 54 €, Harbor registry S 17 €.
- **Secret Manager is available in Terraform** (`ovh_okms`, `ovh_okms_secret`) – the first European
  provider in this series where the DB password can go into a managed secret store.

## Step 1 – Console and project (2026-11-28)

- **Console layout confusing (user):** "Home" shows nothing about Public Cloud projects; you have to switch
  the **tab at the top** (universes such as Public Cloud). No budget alert visible on Home – it lives in the
  project's Cost center.
- **Project creation:** a progress bar, about **1 minute**, and the **terms have to be accepted per
  project**. Unusual compared to Azure/Scaleway/IONOS.
- **CLI:** official `ovhcloud-cli` exists (GitHub `ovh/ovhcloud-cli`), **no winget package** – ZIP or
  Homebrew/Docker. Supports interactive `ovhcloud login` (creates API keys) and **OAuth2 service accounts**.
- `ovhcloud-cli` v0.17.1 installed from the official GitHub release (v0.17.2 only 9 days old), SHA-256 checked, unpacked, user PATH.
- **CLI login failed:** `ovhcloud login` sends the user to a URL to create API credentials; that page asks
  for a **separate login**, which failed with the correct password. "Forgot password" sent **no e-mail**.
  Yet another login surface (console vs. API token page).
- CLI login via the API key page failed, so the user created an **IAM service account** (OAuth2) with a
  policy on the project – the same least-privilege pattern as on the other branches.
- **The service account's client ID starts with `CA.`** and only works against the **Canadian API**
  (`ca.ovh.com`), not the EU API (`invalid_client` there). With the CA endpoint: token OK, exactly 1
  project visible, `/me` forbidden (least privilege works). The account was most likely created through
  the "world" country site seen at the start (German/Spanish only, USD) – which belongs to the CA API.
  To be checked by the user: currency and contracting entity of the account.
- **Confirmed:** the user's console is `console.ca.ovhcloud.com` – the account was created in OVHcloud's
  **Canadian account region** (via the "world" site with USD prices), although the user is in Germany and
  later browsed the German site. Nothing warned about it during sign-up. For a test of *European*
  alternatives this account is not valid → new account through `ovhcloud.com/de/` (EU region,
  `www.ovh.com` / EU console, EUR).
- **New EU account not possible with the same e-mail address** (user): the address is already taken by
  the CA account, but the EU login does not accept it either – which also explains the failed login on the
  API key page and the missing password-reset e-mails. One e-mail address, two account regions, neither
  explained anywhere.
- **Correction (user's analysis):** the German site *does* know the e-mail address – it refuses the login
  instead of offering a sign-up, without saying that the account belongs to another region. The **USD
  prices** at the very first visit most likely came from being logged in to the CA account (the site shows
  the account's currency), not from a "world" country site as the agent first assumed. How the account
  ended up in the CA region cannot be reconstructed afterwards.
- **`ovhcloud login` is hard to use** (user, Git Bash on Windows): an interactive form with three placeholder fields. It looked frozen – in fact each value has to be confirmed with Enter before the next field becomes editable, which the form does not say.
- **New account with a second e-mail address** through the German site: CLI login (API key, read-only)
  against `ovh-eu` works. Account check: subsidiary **DE**, currency **EUR**, country DE, legal form
  `individual` – the EU account region, as required. The CLI saved its config as `./ovh.conf` in the
  current directory (the repository) – moved to `~/.ovh.conf`; `ovh.conf` was added to `.gitignore` before.
- **Project activation** (needed before any resource): after activating, the console shows *"Überprüfung
  erforderlich – Wir müssen Ihre Angaben überprüfen, bevor wir Ihr Projekt bereitstellen"*. The link to
  the order details returns **404 Not Found**. Manual verification of a new account, duration unknown –
  the third provider in this series with a manual review before the first resource (Scaleway: capacity
  block, IONOS: 24 h).
- The console states that the review **can take up to 48 hours** (user). IONOS: up to 24 h.
- **Cleaning up the CA account:** the empty discovery project has no settings/delete option in the console. Termination requested through the API (`POST /cloud/project/{id}/terminate`, CA service account); OVH confirms by e-mail.
- Removing the payment method in the CA account fails: *"impossible to delete the last payment_method with active services"* – although the only project was terminated (OVH apparently still counts a service).
- After cancelling a second listed service, the payment method could be removed; account deletion requested by the user through the console ("request deletion").
- The second service was a **vRack** (created automatically with the project). Status "terminated", yet the account deletion is refused because "a service is still running". Probably counted until the termination becomes effective.
- Old CA credentials removed from the user environment.

## Step 2 – Code while the account is reviewed (2026-11-28)

**What:** `modules/ovhcloud`, root switch, `providers/ovhcloud.sh`, `values/ovhcloud.yaml`, `deploy.sh`
hook, workflow login step. **How:** provider schema (`ovh/ovh` 2.24.0) read first.

**Result:**
- `terraform validate`: valid; first version used `ovh_cloud_project_network_private*` /
  `ovh_cloud_project_gateway` – **deprecated** (provider warning, API v1). Switched to the current
  `ovh_cloud_network_private_vrack`, `…_subnet`, `ovh_cloud_gateway` (API v2); now 0 warnings. Two
  generations of resources side by side, like IONOS PostgreSQL v1/v2.
- **Both databases (`app`, `keycloak`) and the DB user can be created by Terraform** – no workaround as on
  IONOS. The DB user's password is generated by OVHcloud.
- **Secret Manager:** the password goes into OKMS (`ovh_okms_secret`). Creating an OKMS is an *order* at
  account level, so the user creates it once in the console (free; a secret costs 0.03 €/month) and the
  service account's policy covers the project + this OKMS. `get_secret` reads it through the API v2 with
  the service account's OAuth2 token.
- **Gateway S** (≈ 2 €/month) added: the subnet needs a router for the load balancer's Floating IP.
- **Registry users** need an e-mail address (kept in tfvars); their Harbor role cannot be set through the
  Terraform provider – to check after creation.
- Total estimate now ≈ **112 €/month** (incl. gateway).
