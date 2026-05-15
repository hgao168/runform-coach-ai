# Frontend Sprint 1 Issue Backlog (movenova.ai)

Date: 2026-05-13
Owner: Frontend Developer
Primary Repo: https://github.com/hgao168/movenova.ai
Priority Rule: Website first, Web App later
Scope Rule: Website messaging and modules must map to existing iOS capabilities

## Usage

- Create one GitHub issue per ticket below in movenova.ai.
- Use labels: type/feature, priority/P0-P2, sprint/S1, platform/web.
- Use milestone: Sprint 1 - Website MVP.

## iOS Feature Mapping (Source of Truth)

- AnalysisResultView.swift -> AI running form analysis section
- CompareView.swift -> Compare section (me vs elite/history)
- HistoryView.swift -> Progress tracking section
- PlanBuilderView.swift, MarathonPlanDetailView.swift -> Personalized plan section
- LiveGuidanceRecorderView.swift -> Live coaching section
- ProfileStravaCard.swift -> Strava integration section

## Ticket 1 - Bootstrap project and CI baseline

Title: Initialize Next.js website foundation in movenova.ai
Priority: P0
Estimate: 0.5 day

Description:
Initialize Next.js (App Router) with TypeScript strict mode, Tailwind, ESLint, and Prettier. Add basic CI check (lint + build).

Acceptance Criteria:
- Repo contains a working Next.js app with TypeScript strict mode enabled.
- Tailwind is configured and used by at least one page section.
- ESLint and Prettier scripts are available in package scripts.
- CI runs lint and build on pull_request.
- README includes local run steps and required Node version.

## Ticket 2 - Design tokens from iOS visual language

Title: Add design token system mapped from iOS app style
Priority: P0
Estimate: 0.5 day

Description:
Create reusable color, spacing, radius, and typography tokens that reflect iOS visual tone.

Acceptance Criteria:
- CSS variables are defined for primary/secondary/background/text/surface states.
- Tailwind theme references CSS variables instead of hardcoded colors.
- Button, card, and section spacing use tokenized values.
- A short token table is documented in README or docs/design-tokens.md.

## Ticket 3 - Information architecture and routes

Title: Implement Sprint 1 website route skeleton
Priority: P0
Estimate: 0.5 day

Description:
Create website routes for Home, Features, Pricing, Blog, Privacy, and Support.

Acceptance Criteria:
- Routes exist: /, /features, /pricing, /blog, /privacy, /support.
- Each route has production-safe metadata title and description.
- Unknown routes resolve to a branded 404 page.
- Navigation links to all Sprint 1 routes.

## Ticket 4 - Hero section with iOS-aligned value prop

Title: Build Hero section for Website MVP
Priority: P0
Estimate: 0.5 day

Description:
Implement high-impact hero that states iOS-backed value proposition and primary CTA.

Acceptance Criteria:
- Headline communicates form analysis + injury prevention outcome.
- Subtext reflects existing iOS capabilities only.
- Primary CTA and secondary CTA are present and visible on mobile and desktop.
- Hero layout is responsive and passes Lighthouse accessibility checks (no critical issues).

## Ticket 5 - How it works section

Title: Build 3-step flow section (upload, analyze, improve)
Priority: P0
Estimate: 0.5 day

Description:
Add a 3-step explanation section aligned with current product flow.

Acceptance Criteria:
- Three steps are rendered with clear titles and concise copy.
- Icons or visual markers are consistent with token system.
- Copy is reviewed against iOS feature set (no unsupported claims).
- Section stacks correctly on small screens.

## Ticket 6 - iOS feature mapping modules on Features page

Title: Implement iOS capability modules on /features
Priority: P0
Estimate: 1 day

Description:
Build feature modules for analysis, compare, history, plans, live guidance, and Strava integration.

Acceptance Criteria:
- /features includes 6 modules mapped to listed iOS source features.
- Each module includes: feature title, user benefit, and evidence line.
- Evidence line references availability status (available now vs coming soon).
- No module claims non-existent web runtime features.

## Ticket 7 - Social proof and platform section

Title: Add trust and platform support sections
Priority: P1
Estimate: 0.5 day

Description:
Add testimonials placeholder and supported platforms block.

Acceptance Criteria:
- Platform block includes iOS, Android, WeChat Mini Program, and Web roadmap wording.
- Testimonials section supports placeholder cards for Sprint 1.
- Section content is editable from a local data config file.
- Layout remains readable at 320px width.

## Ticket 8 - Pricing preview page

Title: Build pricing preview page with safe placeholders
Priority: P1
Estimate: 0.5 day

Description:
Create pricing page with Free/Pro structure and placeholder details until final pricing is approved.

Acceptance Criteria:
- /pricing has at least two plans with feature bullets.
- No hardcoded final price if business decision is pending.
- CTA routes are valid and do not dead-end.
- Page metadata and OG fields are configured.

## Ticket 9 - SEO and metadata baseline

Title: Implement SEO baseline for Sprint 1
Priority: P0
Estimate: 0.5 day

Description:
Set up metadata, OG image placeholder, sitemap, robots, and canonical basics.

Acceptance Criteria:
- Global metadata template exists and is inherited by all routes.
- sitemap.xml and robots.txt are generated.
- OG image fallback is configured.
- Canonical URLs are set for primary pages.

## Ticket 10 - Analytics and conversion events

Title: Add privacy-friendly analytics instrumentation
Priority: P1
Estimate: 0.5 day

Description:
Integrate analytics and track key CTA interactions.

Acceptance Criteria:
- Analytics provider is integrated (Plausible or Umami).
- Events tracked: hero_primary_cta_click, features_cta_click, pricing_cta_click.
- Event helper function centralizes event names.
- Tracking can be disabled by environment variable.

## Ticket 11 - Accessibility and responsive QA pass

Title: Run accessibility and responsive hardening pass
Priority: P0
Estimate: 0.5 day

Description:
Validate keyboard accessibility, contrast, and mobile responsiveness across key pages.

Acceptance Criteria:
- All interactive elements are keyboard reachable.
- Color contrast passes WCAG AA for body text.
- No content overlap on common breakpoints (320, 375, 768, 1024, 1440).
- Lighthouse accessibility score >= 90 on Home and Features.

## Ticket 12 - Vercel deployment and env setup

Title: Configure preview and production deployment on Vercel
Priority: P0
Estimate: 0.5 day

Description:
Set up project deployment pipeline and required environment variables.

Acceptance Criteria:
- Preview deployments are created for pull requests.
- Production deployment is connected to main branch.
- Required env vars are documented in .env.example.
- Deployment URL is added to README.

## Ticket 13 - Content QA against iOS claims

Title: Validate all website copy against iOS feature truth
Priority: P0
Estimate: 0.5 day

Description:
Perform claim audit to ensure website copy is aligned with current iOS implementation.

Acceptance Criteria:
- A checklist exists mapping each claim to an iOS source file or product decision.
- Unsupported claims are removed or labeled as roadmap.
- Audit output is attached to PR as markdown table.
- Final review confirms no over-promising language.

## Definition of Done (Sprint 1)

- Home and Features pages are production-ready and deployed.
- Core iOS-mapped messaging is visible and consistent.
- SEO baseline and analytics are active.
- Accessibility checks pass agreed thresholds.
- No critical broken links or console errors in production.
