# Entity-Relationship Diagrams

Rendered with Mermaid (GitHub renders these natively). Split by domain for
readability; junction tables are shown as the many-to-many crossings they
implement. See [DATA_MODEL.md](./DATA_MODEL.md) for full column detail.

Cardinality: `||` one · `o{` zero-or-many · `|{` one-or-many · `o|` zero-or-one.

## Taxonomy backbone

```mermaid
erDiagram
    categories      ||--o{ categories       : "sub-category"
    categories      ||--o{ professions      : "has"
    professions     ||--o{ specializations  : "has"
    categories      ||--o{ services         : "groups"
    industries      ||--o{ clients          : "classifies"
    locations       ||--o{ locations        : "contains"
    categories      ||--o{ search_keywords  : "maps to"
    professions     ||--o{ search_keywords  : "maps to"
    specializations ||--o{ search_keywords  : "maps to"
    industries      ||--o{ search_keywords  : "maps to"
```

## Identity & profile core

```mermaid
erDiagram
    users                 ||--o{ professional_profiles : "owns"
    locations             ||--o{ professional_profiles : "based in"
    professional_profiles ||--o{ profile_categories      : ""
    professional_profiles ||--o{ profile_professions     : ""
    professional_profiles ||--o{ profile_specializations : ""
    professional_profiles ||--o{ profile_industries      : ""
    professional_profiles ||--o{ profile_services        : ""
    professional_profiles ||--o{ profile_languages       : ""
    professional_profiles ||--o{ profile_tags            : ""
    professional_profiles ||--o{ profile_areas_served    : ""
    professional_profiles ||--o{ profile_equipment       : ""
    professional_profiles ||--o{ profile_clients         : ""
    professional_profiles ||--o{ profile_links           : ""
    professional_profiles ||--o{ awards                  : ""
    professional_profiles ||--o| availability            : "1:1"
    professional_profiles ||--o{ verification_records    : ""
    professional_profiles ||--o{ profile_score_snapshots : ""

    categories      ||--o{ profile_categories      : ""
    professions     ||--o{ profile_professions     : ""
    specializations ||--o{ profile_specializations : ""
    industries      ||--o{ profile_industries      : ""
    services        ||--o{ profile_services        : ""
    languages       ||--o{ profile_languages       : ""
    tags            ||--o{ profile_tags            : ""
    locations       ||--o{ profile_areas_served    : ""
    equipment       ||--o{ profile_equipment       : ""
    clients         ||--o{ profile_clients         : ""
```

## Portfolio

```mermaid
erDiagram
    professional_profiles ||--o{ portfolio_projects     : "has"
    portfolio_projects    ||--o{ portfolio_media        : "contains"
    portfolio_projects    ||--o{ portfolio_project_tags : ""
    tags                  ||--o{ portfolio_project_tags : ""
    clients               ||--o{ portfolio_projects     : "for"
    categories            ||--o{ portfolio_projects     : "in"
    industries            ||--o{ portfolio_projects     : "in"
    portfolio_media       ||--o| portfolio_projects     : "cover"
```

## Engagement, search & recommendation

```mermaid
erDiagram
    professional_profiles ||--o{ search_impressions    : "appears in"
    search_logs           ||--o{ search_impressions    : "produces"
    professional_profiles ||--o{ profile_views         : "viewed"
    professional_profiles ||--o{ leads                 : "receives"
    professional_profiles ||--o{ recommendation_scores : "scored"
    professional_profiles ||--o{ recommendation_events : "recommended"
    search_logs           ||--o{ recommendation_events : "context"
    users                 ||--o{ saved_searches        : "saves"
    users                 ||--o{ search_logs           : "runs"
    users                 ||--o{ profile_views         : "as viewer"
    services              ||--o{ leads                 : "requested"
    locations             ||--o{ leads                 : "in"
```

`ranking_factor_weights` has no FKs — it is a standalone, admin-tunable config
table read by the matching engine, keyed by `(factor_key, context)`.

## Monetization

```mermaid
erDiagram
    subscription_plans    ||--o{ subscriptions        : "instantiated as"
    users                 ||--o{ subscriptions        : "subscribes"
    professional_profiles ||--o{ subscriptions        : "for"
    promotion_products    ||--o{ promotion_purchases  : "sold as"
    professional_profiles ||--o{ promotion_purchases  : "buys"
    campaigns             ||--o{ promotion_purchases  : "part of"
    categories            ||--o{ promotion_purchases  : "scope"
    locations             ||--o{ promotion_purchases  : "scope"
    users                 ||--o{ invoices             : "billed"
    invoices              ||--o{ invoice_line_items   : "itemizes"
    subscriptions         ||--o{ invoice_line_items   : "billed via"
    promotion_purchases   ||--o{ invoice_line_items   : "billed via"
```

## Communication

```mermaid
erDiagram
    users                 ||--o{ notification_preferences : "controls"
    users                 ||--o{ notifications            : "receives"
    professional_profiles ||--o{ notifications            : "about"
    campaigns             ||--o{ notifications            : "sends"
```

## Future products

```mermaid
erDiagram
    users                 ||--o{ projects        : "posts"
    professional_profiles ||--o{ bookings        : "booked"
    users                 ||--o{ bookings        : "books"
    projects              ||--o{ bookings        : "for"
    users                 ||--o{ payments        : "pays"
    bookings              ||--o{ payments        : "settled by"
    invoices              ||--o{ payments        : "settled by"
    professional_profiles ||--o{ reviews         : "reviewed"
    users                 ||--o{ reviews         : "writes"
    bookings              ||--o{ reviews         : "from"
    message_threads       ||--o{ messages        : "contains"
    users                 ||--o{ messages        : "sends"
    projects              ||--o| message_threads : "about"
    professional_profiles ||--o{ collaborations  : "initiates / joins"
    projects              ||--o{ collaborations  : "on"
```
