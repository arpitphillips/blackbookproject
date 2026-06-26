# Creative Professionals Platform — Master Product Specification (Version 1.0)

## Vision

Build the definitive platform for discovering, evaluating, and connecting
creative professionals.

The platform should initially function as a searchable directory but must be
architected from day one to evolve into an intelligent recommendation engine,
collaboration network, hiring platform and industry operating system.

It should not be designed as a portfolio website, a freelance marketplace, or a
social network. Instead, it should become the canonical structured database of
the creative industry.

Every design and architectural decision must prioritize scalability, search
quality, data integrity, recommendation capability and future monetization.

## Technology Constraints

**Current stack**

- Frontend: platform agnostic
- User onboarding: forms.app
- Operational database: Airtable

The implementation should remain platform-agnostic so Airtable can eventually be
replaced with PostgreSQL or another relational database with minimal redesign.
Avoid Airtable-specific assumptions.

## Core Design Principles

The system must be designed around: structured data, relational database design,
searchability, recommendation, trust, scalability, and future monetization.

Every piece of data collected must satisfy one or more of: improve search
relevance, recommendations, discoverability, trust, SEO, analytics,
monetization, or collaboration matching.

## User Types

- **Professional** — register, login, edit profile, upload portfolio, manage
  availability, purchase promotions, view analytics, receive leads, manage
  notification preferences, submit verification documents.
- **Visitor** — browse, search, filter, view profiles, contact professionals.
  No account required.
- **Client (future)** — create account, save professionals, create projects,
  request quotations, hire, leave verified reviews.
- **Administrator** — approve/reject profiles, edit listings, suspend users,
  verify professionals, manage taxonomy/promotions/campaigns, view analytics,
  moderate content.

## System Architecture — Five Layers

1. **Public Discovery Platform** — SEO pages, directory, category & location
   pages, profiles, search, filters, featured & sponsored placements.
2. **Professional Portal** — login, profile/portfolio/availability management,
   notification preferences, analytics, lead inbox, verification, subscription &
   promotion management, saved searches.
3. **Recommendation Engine** — recommend the most relevant professionals using
   more than keyword matching: category, profession, specializations, services,
   portfolio, experience, verification, availability, distance, languages, past
   engagement, completeness, activity, future reviews, promotion weight.
   Modular so factors evolve without redesigning the database.
4. **Communication System** — timely, relevant, event-driven messages:
   transactional, opportunity alerts, and promotional. Never generic marketing.
   Users control notification preferences; every message delivers measurable
   value.
5. **Monetization Engine** — revenue through visibility, intelligence and
   premium tools, not by restricting basic discovery: free profiles, premium
   subscriptions, featured profiles, sponsored placements, recommendation
   boosts, category/city sponsorships, analytics upgrades, verification
   services, lead products, email campaigns, future booking & payment
   commissions. Independent of profile management.

## Database Design

The database is the primary asset. It must be normalized. Avoid duplicated text,
giant tables, and free-text where relationships should exist. Use unique IDs
throughout. Everything should support future migration away from Airtable.

### Core tables

Users · Professional Profiles · Categories · Professions · Specializations ·
Services · Industries · Portfolio Projects · Portfolio Media · Clients · Awards ·
Equipment · Locations · Areas Served · Languages · Verification Records ·
Availability · Tags · Search Keywords · Search Logs · Recommendation Scores ·
Recommendation Events · Profile Views · Saved Searches · Leads · Promotion
Products · Promotion Purchases · Campaigns · Subscriptions · Invoices ·
Notifications · Reviews (future) · Projects (future) · Messages (future) ·
Bookings (future) · Payments (future) · Collaborations (future)

### Relationship model

One user → one or more profiles. One profile → many services, projects,
portfolio items, awards, equipment records, areas served, languages, tags,
recommendation scores, leads, promotion purchases, and search events.
Everything is linked through IDs.

## Professional Onboarding

Minimize friction; collect only essentials first; complete the rest in the
dashboard. Steps: (1) account creation, (2) professional information,
(3) profile, (4) portfolio, (5) verification, (6) optional enhancements. Support
incomplete profiles while encouraging completion via progress indicators.

## Search Engine

Searchable by name, studio, profession, category, subcategory, industry,
services, location, area, experience, languages, equipment, software,
availability, travel, verification, keywords, tags, awards, clients, and
portfolio content. Modular; should later support semantic search and AI-assisted
discovery without structural database changes.

## Recommendation & Matching

Treated as a separate product. Supports search ranking, similar professionals,
frequently-hired-together, suggested collaborators/assistants/specialists/teams,
opportunity matching, and saved-search alerts. Relevance is computed from
weighted factors; the weighting system should be configurable without code
changes wherever possible.

## Profile Quality Score

Each professional receives an internal quality score from completion, portfolio,
verification, services, projects, recent activity, availability, awards,
clients, languages, and contact methods. It influences recommendations.

## Analytics

Track profile views, search impressions and position, lead conversions, contact
clicks, popular search terms, saved searches, promotion and email performance,
recommendation clicks, referral sources, and geographic demand. These power
future recommendation improvements.

## Email System

Event-driven; never generic newsletters. Categories: transactional, opportunity
alerts, recommendation alerts, promotion campaigns, search alerts, profile
improvement suggestions. Email marketing becomes a premium, highly targeted
promotional product (by profession, category, geography, intent).

## Promotion System

Purchasable: featured profile, homepage feature, category feature, city feature,
recommendation boost, email spotlight, search boost, sponsored placement. All
integrate naturally with search and recommendation while remaining clearly
identified as sponsored where appropriate.

## Future Products

Messaging, reviews, bookings, payments, contracts, invoices, escrow, job board,
project management, creative teams, agency & studio accounts, marketplace, AI
recommendations, semantic search, knowledge graph, API, mobile apps, CRM and
calendar integrations.

## Success Metrics

High-quality profiles, search success rate, recommendation relevance, lead
generation, profile completion, professional retention, repeat visitors, organic
traffic, paid conversion rate, revenue per professional, CAC, and LTV.

## Product Philosophy

This platform is fundamentally a structured data and discovery engine. Profiles
are the interface. The database is the product. Search is the primary
experience. Recommendations are the differentiator. Trust is the competitive
advantage. Monetization is built on increasing visibility, relevance, and
conversion — not restricting access. Every decision should make the platform
more intelligent as more professionals, searches, interactions, and
collaborations are added; value compounds through network effects and
accumulated structured data.
