# Oikos - Product Specification

Self-hosted family planner web app for a single household (2–6 people). No app store, no public access. Deployment via Docker on a private Linux server behind an Nginx reverse proxy with SSL.

---

## Data Model

Every table: `id INTEGER PRIMARY KEY`, `created_at TEXT`, `updated_at TEXT` (ISO 8601).

### Users
| Column | Type | Constraint |
|--------|------|-----------|
| username | TEXT | UNIQUE NOT NULL |
| display_name | TEXT | |
| password_hash | TEXT | bcrypt |
| avatar_color | TEXT | HEX color code |
| avatar_data | TEXT | Base64 data URL of profile picture (nullable) |
| role | TEXT | 'admin' or 'member' |
| family_role | TEXT | 'dad', 'mom', 'parent', 'child', 'grandparent', 'relative', 'other' (default 'other') |

### Tasks
| Column | Type | Constraint |
|--------|------|-----------|
| title | TEXT | NOT NULL |
| description | TEXT | |
| category | TEXT | Household, School, Shopping, Repairs, Other |
| priority | TEXT | none (default), low, medium, high, urgent |
| status | TEXT | open, in_progress, done, archived |
| due_date | TEXT | DATE, nullable |
| due_time | TEXT | TIME, nullable |
| assigned_to | INTEGER | FK → Users |
| created_by | INTEGER | FK → Users, NOT NULL |
| is_recurring | INTEGER | 0/1 |
| recurrence_rule | TEXT | iCal RRULE |
| parent_task_id | INTEGER | FK → Tasks (max 2 levels) |

### Shopping Lists
| Column | Type | Constraint |
|--------|------|-----------|
| name | TEXT | NOT NULL (e.g. "Supermarket", "Hardware store") |

### Shopping Items
| Column | Type | Constraint |
|--------|------|-----------|
| list_id | INTEGER | FK → Shopping Lists, NOT NULL |
| name | TEXT | NOT NULL |
| quantity | TEXT | e.g. "500g", "2 pieces" |
| category | TEXT | FK → Shopping Categories (by name) |
| is_checked | INTEGER | 0/1 |
| added_from_meal | INTEGER | FK → Meals, nullable |

### Shopping Categories
Custom, household-wide category list for shopping items. Replaces the old hardcoded category set.

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY |
| name | TEXT | NOT NULL |
| sort_order | INTEGER | NOT NULL |
| created_at | TEXT | |
| updated_at | TEXT | |

### Meals
| Column | Type | Constraint |
|--------|------|-----------|
| date | TEXT | DATE, NOT NULL |
| meal_type | TEXT | breakfast, lunch, dinner, snack |
| title | TEXT | NOT NULL |
| notes | TEXT | |
| recipe_url | TEXT | nullable, URL to recipe |
| recipe_id | INTEGER | FK → Recipes (ON DELETE SET NULL), nullable |
| created_by | INTEGER | FK → Users, NOT NULL |

### Recipes
Reusable recipe cards that can be pre-filled into meal slots.

| Column | Type | Constraint |
|--------|------|-----------|
| title | TEXT | NOT NULL |
| notes | TEXT | |
| recipe_url | TEXT | nullable |
| created_by | INTEGER | FK → Users (CASCADE delete) |

### Recipe Ingredients
| Column | Type | Constraint |
|--------|------|-----------|
| recipe_id | INTEGER | FK → Recipes (CASCADE delete), NOT NULL |
| name | TEXT | NOT NULL |
| quantity | TEXT | |
| category | TEXT | NOT NULL (default 'Sonstiges') |

### Meal Ingredients
| Column | Type | Constraint |
|--------|------|-----------|
| meal_id | INTEGER | FK → Meals, NOT NULL |
| name | TEXT | NOT NULL |
| quantity | TEXT | |
| on_shopping_list | INTEGER | 0/1 |

### Calendar Events
| Column | Type | Constraint |
|--------|------|-----------|
| title | TEXT | NOT NULL |
| description | TEXT | |
| start_datetime | TEXT | DATETIME, NOT NULL |
| end_datetime | TEXT | DATETIME |
| all_day | INTEGER | 0/1 |
| location | TEXT | |
| color | TEXT | HEX |
| icon | TEXT | Lucide icon name, default 'calendar' |
| assigned_to | INTEGER | FK → Users |
| created_by | INTEGER | FK → Users, NOT NULL |
| external_calendar_id | TEXT | ID from external calendar |
| external_source | TEXT | local, google, apple, ics, caldav |
| recurrence_rule | TEXT | iCal RRULE |
| subscription_id | INTEGER | FK → ICS Subscriptions (CASCADE delete) |
| user_modified | INTEGER | 0/1 — prevents sync overwrite when 1 |
| calendar_ref_id | INTEGER | FK → External Calendars (ON DELETE SET NULL) |
| attachment_name | TEXT | Original filename of attached file, nullable |
| attachment_mime | TEXT | MIME type (e.g. image/jpeg, application/pdf), nullable |
| attachment_size | INTEGER | File size in bytes, nullable |
| attachment_data | TEXT | Base64 data URL of attachment (≤ 5 MB), nullable |
| target_caldav_account_id | INTEGER | FK → CalDAV Accounts (for outbound sync), nullable |
| target_caldav_calendar_url | TEXT | CalDAV calendar URL (for outbound sync), nullable |

### External Calendars
Display metadata (name, color) for synced Google/CalDAV calendars. Populated automatically during sync.

| Column | Type | Constraint |
|--------|------|-----------|
| source | TEXT | 'google' or 'caldav', NOT NULL (legacy 'apple' entries migrated to 'caldav' in v0.44.0) |
| external_id | TEXT | Calendar ID from the provider, NOT NULL |
| name | TEXT | Display name from the provider, NOT NULL |
| color | TEXT | Background color from the provider (HEX) |
| UNIQUE | | (source, external_id) |

### CalDAV Accounts
Multi-account CalDAV integration. Stores credentials for CalDAV servers (iCloud, Nextcloud, Radicale, Baikal, etc.).

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| name | TEXT | User-defined label (e.g. "My Radicale", "iCloud"), NOT NULL |
| caldav_url | TEXT | CalDAV server base URL, NOT NULL |
| username | TEXT | CalDAV username, NOT NULL |
| password | TEXT | CalDAV password (encrypted if DB_ENCRYPTION_KEY set), NOT NULL |
| created_at | TEXT | ISO 8601 |
| last_sync | TEXT | ISO 8601, nullable |
| UNIQUE | | (caldav_url, username) |

### CalDAV Calendar Selection
Per-account calendar enable/disable state for CalDAV accounts.

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| account_id | INTEGER | FK → CalDAV Accounts (CASCADE delete), NOT NULL |
| calendar_url | TEXT | CalDAV calendar URL from provider, NOT NULL |
| calendar_name | TEXT | Display name from provider, NOT NULL |
| calendar_color | TEXT | HEX color code from provider, nullable |
| enabled | INTEGER | 0/1 (default 1), controls sync for this calendar |
| created_at | TEXT | ISO 8601 |
| UNIQUE | | (account_id, calendar_url) |

Index: CREATE INDEX idx_caldav_selection_enabled ON caldav_calendar_selection(account_id, enabled)

### Notes
| Column | Type | Constraint |
|--------|------|-----------|
| title | TEXT | nullable |
| content | TEXT | NOT NULL |
| color | TEXT | HEX |
| pinned | INTEGER | 0/1 |
| created_by | INTEGER | FK → Users, NOT NULL |

### Contacts
| Column | Type | Constraint |
|--------|------|-----------|
| name | TEXT | NOT NULL |
| category | TEXT | Doctor, School/Nursery, Authority, Insurance, Tradesperson, Emergency, Other |
| phone | TEXT | legacy single-value field |
| email | TEXT | legacy single-value field |
| address | TEXT | legacy single-value field |
| notes | TEXT | |
| organization | TEXT | nullable |
| job_title | TEXT | nullable |
| birthday | TEXT | DATE, nullable |
| website | TEXT | nullable |
| photo | TEXT | Base64 data URL, nullable |
| nickname | TEXT | nullable |
| family_user_id | INTEGER | FK → Users (CASCADE delete), UNIQUE (one linked user per contact), nullable |
| carddav_account_id | INTEGER | FK → CardDAV Accounts (SET NULL on delete), nullable |
| carddav_uid | TEXT | CardDAV UID from server, nullable |
| carddav_addressbook_url | TEXT | Source addressbook URL, nullable |

Index: UNIQUE on `(carddav_account_id, carddav_addressbook_url, carddav_uid)` WHERE `carddav_uid IS NOT NULL`

### Contact Phones
Multiple phone numbers per contact with label and primary flag.

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| contact_id | INTEGER | FK → Contacts (CASCADE delete), NOT NULL |
| label | TEXT | e.g. "mobile", "work", "home", nullable |
| value | TEXT | NOT NULL |
| is_primary | INTEGER | 0/1, default 0 |

### Contact Emails
Multiple email addresses per contact with label and primary flag.

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| contact_id | INTEGER | FK → Contacts (CASCADE delete), NOT NULL |
| label | TEXT | e.g. "work", "home", nullable |
| value | TEXT | NOT NULL |
| is_primary | INTEGER | 0/1, default 0 |

### Contact Addresses
Multiple addresses per contact with label and primary flag.

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| contact_id | INTEGER | FK → Contacts (CASCADE delete), NOT NULL |
| label | TEXT | e.g. "home", "work", nullable |
| street | TEXT | nullable |
| city | TEXT | nullable |
| state | TEXT | nullable |
| postal_code | TEXT | nullable |
| country | TEXT | nullable |
| is_primary | INTEGER | 0/1, default 0 |

### CardDAV Accounts
Multi-account CardDAV integration. Stores credentials for CardDAV servers (Nextcloud, iCloud, Radicale, Baikal, etc.).

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| name | TEXT | User-defined label (e.g. "My Nextcloud", "iCloud"), NOT NULL |
| carddav_url | TEXT | CardDAV server base URL, NOT NULL |
| username | TEXT | CardDAV username, NOT NULL |
| password | TEXT | CardDAV password (encrypted if DB_ENCRYPTION_KEY set), NOT NULL |
| created_at | TEXT | ISO 8601 |
| last_sync | TEXT | ISO 8601, nullable |
| UNIQUE | | (carddav_url, username) |

### CardDAV Addressbook Selection
Per-account addressbook enable/disable state for CardDAV accounts.

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| account_id | INTEGER | FK → CardDAV Accounts (CASCADE delete), NOT NULL |
| addressbook_url | TEXT | CardDAV addressbook URL from provider, NOT NULL |
| addressbook_name | TEXT | Display name from provider, NOT NULL |
| enabled | INTEGER | 0/1 (default 1), controls sync for this addressbook |
| created_at | TEXT | ISO 8601 |
| UNIQUE | | (account_id, addressbook_url) |

Index: CREATE INDEX idx_carddav_addressbook_account ON carddav_addressbook_selection(account_id, enabled)

### Budget Entries
| Column | Type | Constraint |
|--------|------|-----------|
| title | TEXT | NOT NULL |
| amount | REAL | NOT NULL (positive = income, negative = expense) |
| category | TEXT | FK → Budget Categories (by key), NOT NULL |
| subcategory | TEXT | FK → Budget Subcategories (by key), default '' |
| date | TEXT | DATE, NOT NULL |
| is_recurring | INTEGER | 0/1 |
| recurrence_rule | TEXT | iCal RRULE |
| recurrence_parent_id | INTEGER | FK → Budget Entries (generated instance points to original) |
| created_by | INTEGER | FK → Users, NOT NULL |

### Budget Categories
Expense and income category list, DB-backed with stable English slug keys. Predefined set (8 expense, 5 income); users can add custom categories inline from the entry modal.

| Column | Type | Constraint |
|--------|------|-----------|
| key | TEXT | PRIMARY KEY (stable English slug, e.g. `housing`) |
| name | TEXT | NOT NULL |
| type | TEXT | `'expense'` or `'income'` |
| sort_order | INTEGER | NOT NULL DEFAULT 0 |
| created_at | TEXT | ISO 8601 |

### Budget Subcategories
Optional subcategories scoped to an expense category. Predefined set (35 entries); users can add custom subcategories inline. Income categories have no subcategories.

| Column | Type | Constraint |
|--------|------|-----------|
| key | TEXT | PRIMARY KEY |
| category_key | TEXT | FK → Budget Categories (CASCADE delete), NOT NULL |
| name | TEXT | NOT NULL |
| sort_order | INTEGER | NOT NULL DEFAULT 0 |
| created_at | TEXT | ISO 8601 |
| UNIQUE | | (category_key, name) |

### Budget Recurrence Skipped
Stores instances of a recurring entry deleted by the user so they are not re-generated.

| Column | Type | Constraint |
|--------|------|-----------|
| parent_id | INTEGER | FK → Budget Entries, NOT NULL |
| month | TEXT | YYYY-MM, NOT NULL |
| PRIMARY KEY | | (parent_id, month) |

### Reminders

Per-user reminders attached to tasks or calendar events.

| Column | Type | Constraint |
|--------|------|-----------|
| entity_type | TEXT | 'task' or 'event', NOT NULL |
| entity_id | INTEGER | FK → tasks or calendar_events, NOT NULL |
| remind_at | TEXT | ISO 8601 datetime, NOT NULL |
| dismissed | INTEGER | 0/1, default 0 |
| created_by | INTEGER | FK → Users (CASCADE delete), NOT NULL |

### Birthdays

Birthday records with optional profile photo and automatic calendar event + reminder.

| Column | Type | Constraint |
|--------|------|-----------|
| name | TEXT | NOT NULL |
| birth_date | TEXT | DATE (YYYY-MM-DD), NOT NULL |
| notes | TEXT | nullable |
| photo_data | TEXT | Base64 data URL (≤ 5 MB), nullable |
| calendar_event_id | INTEGER | FK → calendar_events (SET NULL on delete), nullable |
| family_user_id | INTEGER | FK → Users (CASCADE delete), UNIQUE (one linked user per birthday), nullable |
| created_by | INTEGER | FK → Users (CASCADE delete), NOT NULL |
| reminder_offset | TEXT | Preset offset key (e.g. "1d", "1w") or "custom"; empty/null = no reminder |
| reminder_custom_amount | INTEGER | Amount for custom offset, nullable |
| reminder_custom_unit | TEXT | Unit for custom offset: "minutes", "hours", "days", "weeks", nullable |

### API Tokens
Named Bearer / X-API-Key tokens for non-interactive external integrations. Admin-only creation and revocation. Token values are SHA-256-hashed at rest; the plaintext is shown only once after creation.

| Column | Type | Constraint |
|--------|------|-----------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| name | TEXT | NOT NULL |
| token_hash | TEXT | NOT NULL UNIQUE (SHA-256) |
| token_prefix | TEXT | NOT NULL (first 8 chars, for display) |
| created_by | INTEGER | FK → Users (CASCADE delete), NOT NULL |
| expires_at | TEXT | ISO 8601, nullable |
| revoked_at | TEXT | ISO 8601, nullable |
| last_used_at | TEXT | ISO 8601, nullable |
| created_at | TEXT | ISO 8601 NOT NULL |

### ICS Subscriptions
External calendar feeds subscribed by users (read-only, auto-synced).

| Column | Type | Constraint |
|--------|------|-----------|
| name | TEXT | NOT NULL |
| url | TEXT | NOT NULL (https:// or webcal://) |
| color | TEXT | HEX, default #6366f1 |
| shared | INTEGER | 0/1 — visible to all family members when 1 |
| created_by | INTEGER | FK → Users (SET NULL on delete) |
| etag | TEXT | HTTP ETag for conditional fetch |
| last_modified | TEXT | HTTP Last-Modified for conditional fetch |
| last_sync | TEXT | ISO timestamp of last successful sync |
| created_at | TEXT | ISO timestamp |

### Family Documents
Upload and manage family files with per-document access control.

| Column | Type | Constraint |
|--------|------|-----------|
| name | TEXT | NOT NULL (display name) |
| description | TEXT | nullable |
| category | TEXT | medical, school, identity, insurance, finance, home, vehicle, legal, travel, pets, warranty, taxes, work, other (default) |
| status | TEXT | active (default), archived |
| visibility | TEXT | family (default), restricted, private |
| original_name | TEXT | NOT NULL (original filename) |
| mime_type | TEXT | NOT NULL |
| file_size | INTEGER | NOT NULL (bytes) |
| content_data | TEXT | NOT NULL (Base64 data URL) |
| storage_provider | TEXT | local (default), external |
| storage_key | TEXT | nullable (external storage path) |
| created_by | INTEGER | FK → Users (CASCADE delete), NOT NULL |

### Family Document Access
Allowlist for `visibility = 'restricted'` documents — only listed users can see the document.

| Column | Type | Constraint |
|--------|------|-----------|
| document_id | INTEGER | FK → Family Documents (CASCADE delete), NOT NULL |
| user_id | INTEGER | FK → Users (CASCADE delete), NOT NULL |
| PRIMARY KEY | | (document_id, user_id) |

### Budget Loans
Instalment-based loans with per-payment tracking. Active loans show remaining balance and due months; paid-off loans are automatically closed.

| Column | Type | Constraint |
|--------|------|-----------|
| title | TEXT | NOT NULL |
| borrower | TEXT | NOT NULL |
| total_amount | REAL | NOT NULL CHECK(> 0) |
| installment_count | INTEGER | NOT NULL CHECK(> 0) |
| start_month | TEXT | YYYY-MM, NOT NULL |
| notes | TEXT | nullable |
| status | TEXT | 'active' (default) or 'paid' |
| created_by | INTEGER | FK → Users (CASCADE delete), NOT NULL |

### Budget Loan Payments
Individual payment records for a budget loan. Each installment number is unique per loan.

| Column | Type | Constraint |
|--------|------|-----------|
| loan_id | INTEGER | FK → Budget Loans (CASCADE delete), NOT NULL |
| installment_number | INTEGER | NOT NULL CHECK(> 0), UNIQUE per loan |
| amount | REAL | NOT NULL CHECK(> 0) |
| paid_date | TEXT | DATE, NOT NULL |
| budget_entry_id | INTEGER | FK → Budget Entries (SET NULL on delete), nullable |
| created_by | INTEGER | FK → Users (CASCADE delete), NOT NULL |

### Sync Config
Key-value table for OAuth tokens and CalDAV credentials.

| Column | Type | Constraint |
|--------|------|-----------|
| key | TEXT | PRIMARY KEY |
| value | TEXT | NOT NULL |

---

## Modules

### Dashboard (`/`)

Responsive grid: 1 column on mobile, 2 on tablet, 3 on desktop.

**Widgets:**
- Greeting: "Good [morning/afternoon/evening], [Name]" + date
- Weather: OpenWeatherMap proxy, 3-day preview, refresh every 30 min, hide widget on API error
- Upcoming events: next 3–5, color-coded by person
- Urgent tasks: priority urgent/high + due_date ≤48h
- Today's meals: meals for the current day
- Pinboard preview: 2–3 pinned notes
- FAB (quick actions): + Task, + Event, + Shopping list item, + Note

**Widget sizes:** each widget has a configurable size using named presets (Tiny, Narrow, Standard, Large, Full) that map to `columns × rows` in the CSS grid. Sizes are persisted in user preferences and survive page reloads.

Skeleton loading instead of spinners. Clicking any widget navigates to that module.

### Tasks (`/tasks`)

**Views:**
- List view (default): grouped by category or due date (toggleable), filter: person, priority, status
- Kanban: columns Open → In Progress → Done, drag & drop
- View mode persisted in localStorage; URL parameter `?view=kanban` overrides (useful for tablet kiosk setups)

**Features:**
- CRUD + subtasks (max 2 levels, checkbox list, progress bar)
- Assignment to users (avatar color as indicator)
- Priorities shown visually via color/icon
- Recurring: automatically create next instance on completion
- Archive: completed tasks can be archived (status = 'archived'); visible in a separate Archived filter
- Inline reminder presets: offset from due date/time — 15 min, 1 h, 1 d, 2 d, 1 w, 2 w, or fully custom offset
- **Bulk actions (list view only):** select multiple tasks via checkboxes and apply batch operations (mark done, mark open, archive, delete); bulk select toggle in toolbar
- Mobile swipe: left = done, right = edit
- Badge for overdue tasks

### Shopping Lists (`/shopping`)

- Multiple lists in parallel
- Items: name, category, quantity, checkbox
- Grouping by category (aisle logic)
- Integration with meal plan: "Add ingredients to shopping list" transfers with source reference
- Checked items shown with strikethrough + moved to bottom
- "Clear list" = remove checked items only
- Autocomplete from previous entries (local)
- Mobile swipe: left = check/uncheck, right = delete; × delete button hidden on mobile (swipe takes over)

### Meal Plan (`/meals`)

Weekly view (Mon–Sun), slots: breakfast / lunch / dinner / snack.

- Meal: title + notes + ingredient list
- "→ Shopping list" button: transfer unchecked ingredients of the week to a selected list
- Week navigation forward/back
- Drag & drop between days/slots
- Autocomplete from meal history
- **Recipe integration:** Select a saved recipe from the meal modal to auto-fill title, notes, URL, and ingredients. Scale ingredient quantities by a numeric factor. Save the current meal as a new recipe with one click.
- **Customizable meal visibility:** In Settings, users can toggle which meal types (breakfast, lunch, dinner, snack) are shown in the planner. Stored as household-wide preference in `sync_config` (key: `visible_meal_types`). At least one type must remain active.

### Recipes (`/recipes`)

Reusable recipe cards linked to meal slots.

- CRUD: title, notes, recipe link, per-ingredient category
- Duplicate existing recipes
- "Add to meal plan" navigates to `/meals` with the selected recipe pre-filled in the modal
- REST API: `GET/POST /api/v1/recipes`, `PUT/DELETE /api/v1/recipes/:id` with ingredient sync

### Calendar (`/calendar`)

**Views:** Month (default, dot indicators), Week (hour grid), Day (timeline), Agenda (list).

- CRUD: title, description, start/end, all-day, location, color, assignment
- Color-coding per person
- Recurring via iCal RRULE
- **Google Calendar:** OAuth 2.0, Calendar API v3, two-way sync
- **CalDAV Multi-Account:** Connect multiple CalDAV servers (iCloud, Nextcloud, Radicale, Baikal) with per-account calendar selection via checkboxes, two-way sync (tsdav), optional outbound target selection per event
- **ICS Subscriptions:** Subscribe to any public ICS/webcal URL (e.g. public holidays, sports schedules). Per-subscription color, private/shared visibility, manual "Sync now" and automatic sync on the shared interval. Edit name, color, and visibility of any subscription inline. RRULE events expanded into a rolling ±6/+12 month window. SSRF-protected (DNS pre-resolution), ETag/Last-Modified conditional fetch, 10 MB limit, 15 s timeout. User-edited events are protected from being overwritten (`user_modified`); a "Reset to original" link restores them.
- **External calendar names & colors:** Google and Apple sync stores each calendar's display name and background color in the `external_calendars` table (migration v14). A colored `event-cal-label` badge appears in event popups, agenda, month, week, and day views when `cal_name` is present.
- **Event location:** Event popup and dashboard display the location field with RFC 5545 backslash-escape normalization (`\n`, `\,`, `\;`, `\\`) via `fmtLocation()` in `public/utils/html.js`.
- **Custom event icons:** Each event can have an icon chosen from 102 validated Lucide icons via a visual picker. Birthday events are automatically assigned the `cake` icon. Icon stored in `calendar_events.icon`.
- **File attachments:** Events support a single file attachment (images, PDFs, Office documents, ≤ 5 MB). Images are displayed inline in the event popup; other files show a download link. Drag-and-drop upload supported in the event modal. Stored as Base64 in `attachment_data`.
- **Overlapping events:** In week and day views, timed events that overlap in time are rendered side-by-side using a column-layout algorithm instead of stacking.
- Configurable sync interval (default 15 min)
- External events visually distinguishable
- Conflicts: external event wins, local additions are preserved

### Notes (`/notes`)

Masonry grid with colored sticky notes.

- CRUD: title (optional), content, color
- Pin → appears at top + on dashboard
- Creator shown (avatar color)
- Markdown-light: bold, italic, lists (regex-based)
- Full-text search: client-side filter bar, filters instantly by title + content

### Contacts (`/contacts`)

- CRUD with category filter
- **Multi-value fields:** multiple phones, emails, and addresses per contact, each with a label (mobile, work, home, etc.) and optional `isPrimary` flag
- **Additional fields:** organization, job_title, birthday, website, photo, nickname
- Phone: `tel:` link, email: `mailto:` link
- Address: Maps link (Google/Apple via user agent)
- Real-time search filter
- vCard export: each contact downloadable as `.vcf` (`GET /api/v1/contacts/:id/vcard`)
- vCard import: upload file → client-side parser (FN, TEL, EMAIL, ADR, NOTE, CATEGORIES) → create contact
- **CardDAV multi-account sync:** connect multiple CardDAV servers (Nextcloud, iCloud, Radicale, Baikal); per-addressbook enable/disable via checkboxes; manual sync trigger; bidirectional sync. New API routes under `/api/v1/contacts/cardav/*`: create/delete accounts, test connections, discover/refresh addressbooks, toggle addressbook selection, sync contacts

### Documents (`/documents`)

Upload and manage family files with per-document access control.

- CRUD: name, description, category, file upload (PDF, images, text, Office documents; ≤ 5 MB)
- Drag-and-drop upload in the new-document modal
- **Grid / list view** toggle; view mode persisted in localStorage
- **Category tags:** 14 predefined categories (medical, school, identity, insurance, finance, home, vehicle, legal, travel, pets, warranty, taxes, work, other)
- **Visibility:** family (all members see it), restricted (only selected members), private (only the uploader)
- **Archive / restore** — archived documents hidden from the main view, accessible via the Archive filter
- **Download** — original file downloaded with its original filename
- API: `GET /api/v1/documents`, `POST /api/v1/documents`, `GET /api/v1/documents/:id`, `PUT /api/v1/documents/:id`, `DELETE /api/v1/documents/:id`, `GET /api/v1/documents/:id/download`

### Login (`/login`)

Unauthenticated users are redirected here. No public registration form - admin creates users via setup wizard (`setup.js`) or Settings.

- Username + password form
- Error display for wrong credentials
- Rate limiting: 5 attempts/min/IP, 15-min lockout
- After successful login: redirect to dashboard

### Settings (`/settings`)

User management and app configuration. Logged-in users only.

- **Profile:** change display name, avatar color, password
- **User management (admin):** create new users, edit/delete existing users, assign roles (admin/member)
- **Module toggles (admin, Settings → General):** individual modules (Tasks, Calendar, Shopping, Meals, Recipes, Birthdays, Notes, Contacts, Budget, Documents) can be disabled to hide them from navigation. Data is preserved and reappears when re-enabled. Dashboard and Settings remain essential and cannot be disabled. Stored as `disabled_modules` key in `sync_config`.
- **Synchronization tab:** unified tab for calendar and contact sync, replacing the old Calendar tab. Contains two sections:
  - **Calendar Sync:** connect/disconnect Google Calendar (OAuth 2.0); manage multiple CalDAV accounts (iCloud, Nextcloud, Radicale, Baikal) with per-account calendar selection via checkboxes, two-way sync, and optional outbound event target; manage ICS URL subscriptions (add, delete, sync now, set color and visibility); configure sync interval
  - **Contact Sync:** manage multiple CardDAV accounts (iCloud, Nextcloud, Radicale, Baikal); per-addressbook enable/disable; manual sync trigger; real-time status badges (success, error, syncing with animated spinner)
- **Weather:** configure OpenWeatherMap location
- **Language:** System (follows `navigator.language`), German, English, Spanish, French, Italian, Swedish, Greek, Russian, Turkish, Chinese, Japanese, Arabic, Hindi, Portuguese, Ukrainian, Polish - via `oikos-locale-picker` web component; switch without page reload
- **API Tokens (admin):** create named Bearer / X-API-Key tokens for external integrations; the full token value is shown only once immediately after creation; tokens can be revoked at any time; support optional expiry and track last-used timestamp
- **Backup Management (admin):** download the current database as a file (`GET /api/v1/backup/database`) or restore from a backup file (`POST /api/v1/backup/restore`, drag-and-drop supported). Validates that the uploaded file is a valid Oikos database. A rollback copy is created automatically before restore. **Automatic scheduled backups:** configurable via `.env` (`BACKUP_ENABLED`, `BACKUP_SCHEDULE`, `BACKUP_DIR`, `BACKUP_KEEP`); default 2 AM daily, keeps last 7 copies; Settings → Backup shows scheduler status, schedule, retention policy, last backup timestamp, and a manual trigger button.
- **Tab navigation:** Settings is organized in nine tabs (General, Meals, Budget, Shopping, Synchronization, Family, API Tokens, Backup, Account). Admin-only tabs: Family, API Tokens, Backup. Sticky tab bar, active tab persists in sessionStorage, Synchronization tab auto-activates after OAuth callbacks.
- **Family management (admin):** assign a `family_role` (Dad, Mom, Parent, Child, Grandparent, Relative, Other) to each user, and set per-member phone, email, and birthday — automatically synced to Contacts and Birthdays. Displayed in the family member list and profile views.
- **Profile picture:** users can upload a personal avatar (PNG/JPEG/WebP/GIF, ≤ 5 MB), stored as a Base64 data URL in `avatar_data`. Displayed alongside display name across the app.
- **App info:** version, license

### Budget (`/budget`)

**Views:**
- Monthly overview: income vs. expenses, balance, bar chart by category (Canvas, no library)
- Transaction list: chronological, filterable

- CRUD: title, amount, category, subcategory, date
- Categories: DB-backed with stable English slug keys; 8 predefined expense categories, 5 income categories; users can add custom categories inline from the entry modal
- Subcategories: 35 predefined subcategories across expense categories; users can add custom subcategories inline; displayed alongside category in each entry's metadata line
- Recurring entries
- Monthly comparison (current vs. previous month)
- CSV export includes a subcategory column and English column headers
- **Loans tab:** create instalment-based loans (borrower, total amount, number of instalments, start month); record individual payments; remaining balance and due months shown automatically; paid-off loans marked as closed; filter budget transactions by loan
- API: `GET /api/v1/budget/categories`, `GET /api/v1/budget/categories/:key/subcategories` (optional `?lang=` localisation), `POST /api/v1/budget/categories`, `POST /api/v1/budget/categories/:key/subcategories`
- Loans API: `GET /api/v1/budget/loans`, `POST /api/v1/budget/loans`, `GET /api/v1/budget/loans/:id`, `PUT /api/v1/budget/loans/:id`, `DELETE /api/v1/budget/loans/:id`, `GET /api/v1/budget/loans/:id/payments`, `POST /api/v1/budget/loans/:id/payments`, `DELETE /api/v1/budget/loans/:id/payments/:paymentId`

### Birthdays (`/birthdays`)

Personal birthday tracker with automatic calendar integration.

- CRUD: name, birth_date (day/month/year or day/month only for age-unknown entries), notes, photo
- Profile photo upload (PNG/JPEG/WebP/GIF, ≤ 5 MB, stored as Base64 data URL)
- **Upcoming view:** birthdays sorted by days until next occurrence; shows age when year is known
- **Calendar integration:** creating or updating a birthday automatically creates/updates a recurring annual all-day calendar event (title: "🎂 {Name}"); deleting a birthday removes the linked event
- **Configurable reminder:** customizable reminder offset per birthday with preset options (none, at time, 15 min, 1 h, 1 d, 2 d, 1 w, 2 w) and a fully custom interval (amount + unit). Reminder time calculated from offset; auto-dismissed when the birthday passes
- Search filter by name
- API: `GET /api/v1/birthdays`, `GET /api/v1/birthdays/upcoming`, `GET /api/v1/birthdays/:id`, `POST /api/v1/birthdays`, `PUT /api/v1/birthdays/:id`, `DELETE /api/v1/birthdays/:id`

### Reminders (`/reminders`)

Time-based reminders attached to tasks or calendar events.

- One reminder per entity (upsert — creating a new reminder replaces the previous one)
- Reminder time set via datetime picker in the task or event modal
- **Pending reminders:** polled on page load and at a fixed interval; displayed as an in-app notification badge/toast
- **Birthday reminders** auto-synced from the Birthdays module (1 day before each occurrence)
- Dismissing a reminder marks it `dismissed = 1`; dismissed reminders are not shown again
- API: `GET /api/v1/reminders/pending`, `GET /api/v1/reminders?entity_type=&entity_id=`, `POST /api/v1/reminders`, `DELETE /api/v1/reminders/:id`, `POST /api/v1/reminders/:id/dismiss`

---

## API Documentation

An OpenAPI 3.0 specification is served at `/api/v1/openapi.json` and `/openapi.json`. Append `?download=1` to download as a file. The spec covers all authenticated endpoints and can be imported into any OpenAPI-compatible client (Insomnia, Postman, etc.).

Authentication options for external integrations:
- **Session cookie:** standard browser session after login
- **Bearer token:** `Authorization: Bearer <token>` — tokens created via Settings → API Tokens (admin only)
- **X-API-Key header:** `X-API-Key: <token>` — alternative header accepted alongside Bearer

---

## Design System

### Colors (CSS Custom Properties)

Source of truth: `public/styles/tokens.css`. Key values (as of v0.20.39):

**Palette rationale:** Warm-tinted neutral scale (`#FAFAF8 → #121211`) anchored by an **Indigo-600 primary** (`#4F46E5`) that harmonises with the Calendar module violet and the secondary accent. Module colors are semantically separated from severity colors — no hue shared without explicit documentation in `tokens.css`.

```css
:root {
  /* Neutral canvas — warm linen/unbleached-paper atmosphere */
  --color-bg:              #F5F4F1;   /* neutral-100 */
  --color-surface:         #FFFFFF;
  --color-border:          #E8E7E2;   /* neutral-200 */
  --color-text-primary:    #1C1C1A;   /* neutral-900, 14.7:1 on bg */
  --color-text-secondary:  #6C6B67;   /* neutral-600, 5.0:1 on white */
  --color-text-tertiary:   #6A6964;   /* 4.61:1 on bg */

  /* Primary accent — Indigo (warm bias, harmonises with Calendar/violet) */
  --color-accent:           #4F46E5;  /* Indigo-600, 4.93:1 on white (AA) */
  --color-accent-hover:     #4338CA;  /* Indigo-700, 7.04:1 (AAA) */
  --color-accent-active:    #3730A3;  /* Indigo-800 */
  --color-accent-deep:      #2E2D82;  /* deep Indigo for gradients/weather */
  --color-accent-secondary: #7C5CFC;  /* violet — logo gradient, same Indigo family */
  --color-accent-light:     #EEF2FF;  /* Indigo-50 */
  --color-accent-subtle:    #E0E7FF;  /* Indigo-100 */
  --color-btn-primary:      #4338CA;  /* Indigo-700, 7.04:1 on white (AAA) */
  --color-btn-primary-hover:#3730A3;

  /* Severity — hue-separated from module colors */
  --color-success:       #15803D;     /* 4.54:1 */
  --color-warning:       #A15C0A;     /* 5.23:1 — Amber, distinct from --module-meals */
  --color-danger:        #B91C1C;     /* Red-700, 6.90:1 (AAA) */
  --color-info:          #0969DA;     /* 4.64:1 */

  /* Module accents — domain-specific, not interchangeable with severity */
  --module-dashboard:  #4F46E5;   /* Indigo — follows primary accent */
  --module-tasks:      #15803D;   /* Green — intentional share with --color-success */
  --module-calendar:   #8250DF;   /* Violet */
  --module-meals:      #C2410C;   /* Orange-700 */
  --module-shopping:   #DB2777;   /* Pink-600 — distinct from Meals/Warning */
  --module-notes:      #CA8A04;   /* Gold, 4.08:1 — icons/large-text only */
  --module-contacts:   #0969DA;   /* Blue — distinct from Indigo primary */
  --module-budget:     #0F766E;   /* Teal-700, 5.11:1 */
  --module-reminders:  #0E7490;   /* Cyan-700, WCAG AA */
  --module-settings:   #6E7781;   /* Neutral grey */

  /* Priority */
  --color-priority-medium: #A16207;  /* Amber-700, 6.3:1 — distinct from Warning+Meals */
  --color-priority-high:   #C2410C;  /* = --module-meals (documented share: "hot") */
  --color-priority-urgent: #B91C1C;  /* = --color-danger (documented share: "destructive") */

  /* Glass layer tokens */
  --glass-bg: rgba(255,255,255,0.72);
  --glass-border: rgba(255,255,255,0.55);
  --blur-2xs: blur(2px);
  --blur-md: 16px;
  --radius-glass-button: 9999px;       /* capsule */
  --ease-glass: cubic-bezier(0.34, 1.56, 0.64, 1); /* spring */

  /* Glass Vibrancy tokens (Phase 4) */
  --glass-bg-card: rgba(255,255,255,0.52);
  --glass-bg-card-hover: rgba(255,255,255,0.65);
  --glass-bg-input: rgba(255,255,255,0.48);
  --glass-bg-toolbar: rgba(255,255,255,0.58);
  --glass-tint-strength: 6%;

  /* Glass inset specular highlights */
  --glass-inset-soft:     inset 0 1px 0 rgba(255,255,255,0.18);
  --glass-inset-base:     inset 0 1px 0 rgba(255,255,255,0.20);
  --glass-inset-medium:   inset 0 1px 0 rgba(255,255,255,0.22);
  --glass-inset-elevated: inset 0 1px 0 rgba(255,255,255,0.28);
  --glass-inset-strong:   inset 0 1px 0 rgba(255,255,255,0.32);
}

/* Dark mode — Hue preserved (Indigo-400), only Lightness/Saturation adjusted.
   Private --_name tokens prevent duplication between @media and [data-theme]. */
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: #1A1A18;       /* deep warm */
    --color-surface: #222220;
    --color-border: #2C2C2A;
    --color-text-primary: #F5F4F1;
    --color-text-secondary: #AEADB0;
    --color-accent:            #818CF8;  /* Indigo-400, 6.8:1 on dark surface */
    --color-accent-hover:      #6366F1;  /* Indigo-500 */
    --color-accent-active:     #4F46E5;  /* Indigo-600 — mirrors light primary */
    --color-accent-light:      #2E2D5B;
    --color-accent-subtle:     #252255;
    --color-btn-primary:       #6366F1;  /* 5.5:1 */
    --color-btn-primary-hover: #4F46E5;
    --module-dashboard: #818CF8;
    --module-meals:     #FB923C;  /* Orange-400 */
    --module-shopping:  #F472B6;  /* Pink-400 — mirrors light entanglement */
    --module-budget:    #2DD4BF;  /* Teal-400 */
    --module-reminders: #22D3EE;  /* Cyan-400 */
    --meal-dinner:      #818CF8;
    --glass-bg: rgba(28,28,26,0.75);
    --glass-border: rgba(255,255,255,0.12);
    --glass-bg-card: rgba(38,38,36,0.50);
    --glass-tint-strength: 8%;
  }
}
```

### Typography
- System font stack, headings 600–700
- Body: 16px mobile, 15px desktop, line-height 1.5
- Caption: 13px, `var(--color-text-secondary)`

### Glass Layer (`public/styles/glass.css`)

Additive CSS file loaded globally after `layout.css`. Implements a Liquid Glass design language inspired by Apple's iOS 26 Liquid Glass, adapted for CSS/web:

**Phase 1-3 (Shell + Components + Polish):**
- **Translucent surfaces:** `backdrop-filter: blur()` on bottom nav, sidebar, modal overlay, cards on hover. All blur effects are inside `@supports (backdrop-filter: blur(1px))` for progressive enhancement.
- **Glass tokens:** Section 16 of `tokens.css` defines `--glass-bg*`, `--glass-border*`, `--blur-2xs` through `--blur-xl`, `--opacity-glass-*`, `--glass-highlight*`, `--glass-shadow-sm/md/lg`, `--radius-glass-card/inner/chip/button`, `--ease-glass`, `--transition-glass`. Full dark mode overrides.
- **Capsule shapes:** Buttons, FAB, and search inputs use `--radius-glass-button` (pill shape).
- **Spring animations:** Modal entrance (`glass-modal-scale-in` / `glass-sheet-in`), page transitions, and list stagger all use `cubic-bezier(0.34, 1.56, 0.64, 1)` spring easing.
- **FAB attention pulse:** `fab-ring-pulse` keyframe expands a ring around the FAB to signal readiness.
- **Nav auto-hide:** Bottom bar hides on scroll-down, reappears on scroll-up (mobile only, < 1024px, 4 px hysteresis). CSS: `.nav-bottom--hidden { transform: translateY(calc(100% + var(--safe-area-inset-bottom))); }`. JS: `initNavHideOnScroll()` in `router.js`.

**Phase 4 (Vibrancy + Tint):**
- **Deeper glass penetration:** Dashboard widgets, task cards, note items, meal slots, form inputs, toolbars, group toggles, and FAB speed-dial actions all use semi-transparent glass backgrounds (`--glass-bg-card`, 52% opacity) with `backdrop-filter: blur() saturate()` so underlying content shines through.
- **Module tint:** Each glass surface receives a subtle accent color gradient overlay via `::after` pseudo-element using `color-mix(in srgb, var(--module-accent) var(--glass-tint-strength), transparent)`. Strength is 6% in light mode, 8% in dark mode.
- **App vibrancy background:** `app-content` uses a radial gradient with the active module accent at 3% opacity to provide an ambient color base that glass elements refract.
- **Load-order safety:** All Phase 4 glass selectors use parent-scoped specificity (`.dashboard .widget`, `.tasks-page .task-card`, `.meals-page .meal-slot`) to prevent override by on-demand page CSS that loads after `glass.css`.

**Accessibility:** `prefers-reduced-transparency`, `prefers-reduced-motion`, and `prefers-contrast: more` blocks deactivate blur/animation and restore solid fallbacks across all phases.

### Components
- **Cards:** `var(--color-surface)` base, glass vibrancy via `var(--glass-bg-card)` + `backdrop-filter: blur(8px) saturate(180%)` when supported. `var(--radius-md)`, `var(--shadow-sm)`. Module tint overlay via `::after`. Consistent padding `var(--space-4)` (16px) across all modules.
- **Buttons:** Primary = accent + white. Secondary = outline. Min-height 44px. Capsule shape via `--radius-glass-button`. Submit buttons show success (checkmark, 700ms green via `.btn--success`) and error (shake via `.btn--shaking`).
- **Inputs:** `var(--radius-sm)`, 1.5px border, padding 12px 16px. Search inputs use `--radius-glass-button` and `--glass-border-subtle`. `[required]` fields receive validation status on blur (`.form-field--error` / `.form-field--valid`). Enter moves focus to the next field; Enter on the last field triggers submit.
- **FAB (Floating Action Button):** Color follows the module accent token (`--module-accent`) - each module defines its own accent color. Specular inner highlight + attention ring pulse. Hidden when the virtual keyboard is open (`visualViewport.resize`, threshold 75% of window height).
- **Module accent colors:** `--module-accent` is applied on three visual layers - (1) active nav tab (bottom bar + sidebar stripe), (2) toolbar `border-top: 3px`, (3) cards/rows `border-left: 3px`. The active accent is written to `--active-module-accent` on `:root` on every navigation change. Falls back to `--color-accent` for pages without a module context.
- **Navigation:** Bottom tab bar on mobile (Dashboard, Tasks, Calendar, Meals, More), auto-hides on scroll-down. Sidebar on desktop. Both use glass blur surface.
- **Transitions:** Directional slide-X animation on page change (forward = from right, back = from left, 200ms) with spring easing. Respects `prefers-reduced-motion`.
- **Empty states:** Consistent `.empty-state` class across all modules (icon + title + description, centered). Compact variant `.empty-state--compact` for meal slots.
- **Modals:** Centered panel on desktop with glass overlay. On mobile (< 768px) bottom sheet - spring slide-in from below, sheet handle visible, swipe-to-close (> 80px downward). `focusin` scrolls inputs into view when the virtual keyboard is open.
- **List animation:** Staggered spring fade-in on load (`stagger()` from `public/utils/ux.js`) - max 5 elements staggered (30ms gap), rest appear immediately.
- **Vibration:** `vibrate()` from `public/utils/ux.js` - short pulses for light actions (10-40ms), pattern `[30, 50, 30]` for destructive actions (delete). Respects `prefers-reduced-motion`.
- **PWA install prompt:** Appears only after 2 user interactions. Dismiss window 7 days; interaction counter resets after dismiss.
- **PWA offline fallback:** Service worker serves `/offline.html` when the network is unreachable and `index.html` is not cached. Includes a reload button.

### Breakpoints
- Mobile: < 768px (1 column, bottom nav)
- Tablet: 768–1024px (2 columns, bottom nav)
- Desktop: > 1024px (sidebar + content)

---

## Internationalization (i18n)

All UI strings are managed via `public/i18n.js`. No hardcoded text in JS files outside of locale files.

### Architecture

- **Module:** `public/i18n.js` - exports: `initI18n()`, `setLocale()`, `t(key, params?)`, `getLocale()`, `getSupportedLocales()`, `formatDate(date)`, `formatTime(date)`
- **Locale files:** `public/locales/de.json` (reference), `public/locales/en.json`, `public/locales/es.json`, `public/locales/fr.json`, `public/locales/it.json`, `public/locales/sv.json`, `public/locales/el.json`, `public/locales/ru.json`, `public/locales/tr.json`, `public/locales/zh.json`, `public/locales/ja.json`, `public/locales/ar.json`, `public/locales/hi.json`, `public/locales/pt.json`, `public/locales/uk.json`, `public/locales/pl.json` - structure: `{ "module.camelCaseKey": "Value" }`
- **Variables:** `{{variable}}` syntax in translation strings, e.g. `t('tasks.assignedTo', { name: 'Anna' })`
- **Fallback chain:** active locale → German (`de`) → key itself
- **Date format:** `Intl.DateTimeFormat` with current locale - use `formatDate()` and `formatTime()` from `i18n.js`

### Language Detection

1. `localStorage` entry `oikos-locale` (manual selection)
2. `navigator.languages[0]` (browser language)
3. Fallback: `en`

### Supported Languages

| Code | Language | Status |
|------|----------|--------|
| `de` | German | Reference locale (all keys defined here) |
| `en` | English | Full translation |
| `es` | Spanish | Full translation |
| `fr` | French | Full translation (added v0.16.3) |
| `it` | Italian | Full translation (added v0.5.8) |
| `sv` | Swedish | Full translation (added v0.11.3) |
| `el` | Greek | Full translation (added v0.16.3) |
| `ru` | Russian | Full translation (added v0.16.3) |
| `tr` | Turkish | Full translation (added v0.16.3) |
| `zh` | Chinese (Simplified) | Full translation (added v0.16.3) |
| `ja` | Japanese | Full translation (added v0.19.0) |
| `ar` | Arabic | Full translation (added v0.19.0) |
| `hi` | Hindi | Full translation (added v0.19.0) |
| `pt` | Portuguese | Full translation (added v0.19.0) |
| `uk` | Ukrainian | Full translation (added v0.19.0) |
| `pl` | Polish | Full translation (added v0.50.0) |

### Adding a New Language

1. Create `public/locales/xx.json` (copy of `de.json`, translate)
2. Add `'xx'` to `SUPPORTED_LOCALES` in `public/i18n.js`
3. Add label in `oikos-locale-picker` (`LOCALE_LABELS['xx'] = 'Name'`)

### Locale Switching

`setLocale(locale)` saves the selection, loads the new locale file, and fires the `locale-changed` custom event. All page modules and web components listen to this event and re-render - no page reload required.
