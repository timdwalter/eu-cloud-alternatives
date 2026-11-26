# Test log – STACKIT

Branch `002-stackit`, created from `main` at tag `azure-tested`. Same structure as
[test-log-azure.md](test-log-azure.md).

## Step 0 – Account and CLI (2026-11-27)

**What:** Existing STACKIT account; preparing the CLI for project lookup and the Terraform service account.
**How:** –

**Observations**
- Portal login requires MFA via e-mail on every login. Accepted for a half-day test. Terraform will use a
  service account key, so automation does not depend on it.
- **CLI installation channels (user's observation):** no `winget` and no Chocolatey package. On Windows
  the official installation guide lists only Scoop, as the last section after macOS (Homebrew) and Linux
  (Snap, APT, DNF/Zypper, Nix). Otherwise there is the ZIP from the GitHub releases. Azure CLI, by
  comparison, offers winget, MSI, an MSI via PowerShell, and ZIP. Good for macOS and Linux users, a point
  off for Windows.
- **CLI install (2026-11-27):** ZIP v0.78.0 from the GitHub release, SHA-256 checked against
  `checksums.txt`, extracted to the user's programs folder and added to the user PATH. ~5 min.
- **CLI login** (`stackit auth login`, browser + e-mail MFA) worked first time.
- **Not obvious:** a user login alone is not enough. Without a **customer account (organisation with
  contract/billing data)** the CLI shows no projects (`[]`), and listing organisations returns
  `403 Forbidden`. The customer account has to be created in the portal first, with billing data and
  possibly a review by STACKIT. An agent cannot do this step. With Azure, a pay-as-you-go
  subscription already existed.- **Customer account only for DACH (user's observation during sign-up):** STACKIT accepts customers from
  Germany, Austria and Switzerland only. For a "European alternative" this excludes most of Europe. Not a
  problem for this test (customer in Germany), but a key point for the comparison. The same question will
  be checked for IONOS and Scaleway.- **Blocker – customer account requires a company (2026-11-27):** creating the customer account asks for
  company data. There is no option for private individuals. Without a company there is no customer
  account, no project and no resources. **The hands-on test ends here.** Time spent until this point:
  ~30 min (CLI install, login, sign-up attempt).

## Result

STACKIT could not be tested hands-on: onboarding is limited to **business customers from DACH**. Nothing
was created and nothing was billed. Everything below the onboarding step (Terraform, SKE, PostgreSQL,
registry, …) remains untested.