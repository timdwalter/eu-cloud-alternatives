# Evaluation – STACKIT

Same criteria and scale as [evaluation-azure.md](evaluation-azure.md). Evidence:
[test log](test-log-stackit.md).

## Result: blocked at onboarding

| Step | Outcome |
|---|---|
| Install the CLI | ✅ ZIP from GitHub with checksum. No winget/Chocolatey; on Windows only Scoop is documented |
| User login (portal and CLI) | ✅ Works, e-mail MFA on every portal login |
| Customer account | ❌ **Business customers only**, and only from Germany, Austria or Switzerland |
| Project, resources, deployment | – Not reachable |

## Issues by cause

| # | Issue | Cause | Impact |
|---|---|---|---|
| 1 | Customer account requires a company; private individuals cannot sign up | **STACKIT** | **Blocking** |
| 2 | Customers from DACH only | **STACKIT** | Blocking for most of Europe (not for this test) |
| 3 | A user login without a customer account shows no projects and returns 403 for organisations; the need for a customer account is not obvious | **STACKIT** | Low (confusing) |
| 4 | No winget/Chocolatey package for the CLI; Windows listed last in the installation guide | **STACKIT** | Low |

## Scores

| Criterion | Score | Reasoning |
|---|---|---|
| Account & onboarding | **1** | Blocked: business customers from DACH only |
| All other criteria | – | Not testable |

## Author's view

> Because of this, STACKIT will never be on par. People who want to take a look and try it out, so they
> can decide whether it is good or bad, are gone again right at this point. They should learn from Slack:
> every developer had Slack, so companies simply had to keep using it, and developers told other
> developers about it.

> As a consultant who tells enterprise customers which platform they could use, I simply won't be able to
> recommend STACKIT.

Consultants and architects are a multiplier for exactly the enterprise customers STACKIT targets. If they
cannot evaluate the platform hands-on in advance, it does not make it onto the shortlist.

The point behind both statements is **bottom-up adoption**. Developers try cloud platforms privately or in side projects
and carry their preferences into their companies. A provider that admits only registered businesses
skips this channel completely. Possible reasons on STACKIT's side (assumed, not verified): focus on
enterprise and public-sector customers, contract and compliance requirements (KYC), and avoiding abuse of
free or cheap private accounts.

## What this means for the comparison

- Azure, by comparison: a private pay-as-you-go subscription is enough to test the full stack.
- For companies in DACH, STACKIT stays a candidate. This test simply could not show how it performs.
- Possible follow-ups (not done): repeat with a company account; or compare the STACKIT documentation
  against the [building blocks](building-blocks.md) as desk research, clearly marked as untested.