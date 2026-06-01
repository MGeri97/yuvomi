# Oikos — UI/UX-Audit (Mai 2026)

**Umfang:** Mobile & Desktop, Light- & Dark-Mode. Geprüft gegen die Prioritätskategorien
des UI/UX-Pro-Max-Regelsatzes (Accessibility → Touch → Performance → Style → Layout →
Typografie → Animation → Forms → Navigation → Datenvisualisierung) sowie Apple HIG / Material.

**Geprüfte Basis:** `tokens.css`, `layout.css`, `glass.css`, `reset.css`, `login.css`,
`dashboard.css`, `components/modal.js`, `index.html`, `theme-init.js`, `router.js` (Toast/Route),
`budget.js` (Datenvis), stichprobenhaft alle `pages/*` und `styles/*`.

**Umsetzungsstatus (2026-06-01):** Die Audit-Ergebnisse wurden in mehreren Releases umgesetzt.
Die ursprünglichen P1/P2-Sicherheits- und Accessibility-Punkte sind in `v0.54.12` und
`v0.55.0` geschlossen. Der breitere Frontend-UI/UX-Rollout aus
`docs/superpowers/plans/2026-05-31-frontend-ui-ux-audit-improvements.md` ist in
`v0.55.7` bis `v0.55.10` gelandet: stärkere Arbeitsflächen, bessere mobile Dashboard-,
Tasks- und Shopping-Ergonomie, stabile Kitchen/More-Navigation, lesbarere Kalenderansichten,
strukturiertere Settings und zusätzliche Regressionstests.

---

## 0. Gesamteinschätzung

Oikos ist auf einem **überdurchschnittlich hohen Reifegrad**. Das Design-System ist
diszipliniert umgesetzt und viele Dinge, die in typischen Audits als Mängel auftauchen,
sind hier bereits vorbildlich gelöst:

- **Token-Architektur mit privaten/öffentlichen CSS-Variablen** (`--_name` → `--name`):
  Dark-Mode überschreibt nur private Tokens, die öffentliche API bleibt stabil. Exzellent.
- **Drei Theme-Pfade**: System (`@media prefers-color-scheme`), expliziter Override
  (`[data-theme]`), Flash-Prevention via `theme-init.js` vor dem CSS-Rendering.
- **Accessibility-Media-Queries durchgängig**: `prefers-reduced-transparency`,
  `prefers-contrast: more` und ein **globaler** `prefers-reduced-motion`-Block in
  `reset.css:72` (`*{animation-duration:0s!important}`) decken auch alle Modul-CSS ab.
- **Toast-System** mit getrennten `aria-live="polite"`/`"assertive"`-Containern plus
  Route-Announcer (`router.js:828`).
- **Modal** mit Focus-Trap, Focus-Restore, Scroll-Lock, Dirty-Check, Swipe-to-Close.
- **WCAG-Kontraste** sind explizit dokumentiert und teils nachgebessert (z. B. Kommentar
  `dashboard.css:124`: „was: text-2xs — WCAG minimum 12px").
- **Empty-States in 13 von 13 Seiten**, Skeleton-Loading, `tabular-nums` für Zahlen/Zeiten,
  fluide Typo-Skalierung via `clamp()`.

Die folgenden Befunde sind daher überwiegend **Feinschliff** — keine groben Schnitzer.
Sie sind nach Wirkung/Aufwand priorisiert.

---

## 1. Konkrete Befunde (verifiziert, mit Datei:Zeile)

### 🔴 P1 — Schnell behebbar, sichtbare Wirkung

#### 1.1 `theme-color` passt nicht zur Akzentfarbe
`index.html:9`
```html
<meta name="theme-color" content="#4F46E5" media="(prefers-color-scheme: light)" />
```
Die PWA-/Browser-Chrome-Farbe ist **Indigo `#4F46E5`**, der tatsächliche App-Akzent ist
aber **Violet `#6c3aed`** (`tokens.css:111`). In der installierten PWA zeigt die
Statusleiste/Adressleiste damit einen sichtbar anderen Farbton als die App selbst — ein
Bruch in der Markenwahrnehmung, genau an der prominentesten Stelle (System-Chrome).

**Fix:** `content="#6c3aed"` (oder `--color-btn-primary` `#5b2fd4`) setzen. Dark-Mode-Wert
`#222220` ist korrekt (= Surface).

#### 1.2 `width: 100vw` erzeugt horizontalen Overflow auf Desktop
`login.css:13`
```css
.login-page { width: 100vw; }
```
`100vw` schließt die Breite der vertikalen Scrollbar **mit ein**. Sobald auf Desktop eine
Scrollbar erscheint (z. B. bei Fehler-Banner + kleiner Höhe), entsteht ein horizontaler
Scrollbalken / abgeschnittener Rand. Verstößt gegen `horizontal-scroll` (Layout, HIGH).

**Fix:** `width: 100%` (das Element ist ohnehin Block-Level und füllt den Viewport).

#### 1.3 10px-Schrift (`--text-2xs`) trotz selbst gesetztem 12px-Minimum
Inkonsistenz: Das Team hat im Dashboard `text-2xs` bewusst auf `text-xs` (12px) angehoben
(`dashboard.css:124`), 10px wird aber weiter verwendet:
- `layout.css:784` — `.nav-sidebar__version` (Versionsnummer)
- `layout.css:2503` — `.nav-section-label` (Sidebar-Abschnitts-Label, uppercase)
- `reminders.css:21` — Erinnerungs-Badge

10px ist für uppercase-Labels/Badges grenzwertig, aber unterhalb der eigenen Norm und der
Empfehlung (Body min. 12px). Verstößt gegen `font-scale`/`readable-font-size` (MEDIUM).

**Fix:** Auf `--text-xs` (12px) anheben oder bewusst dokumentieren, dass 10px nur für rein
dekorative Labels (nicht informationstragend) erlaubt ist.

---

### 🟡 P2 — UX-Verhalten überdenken

#### 1.4 Enter-Taste springt im Modal zum nächsten Feld statt zu submitten
`modal.js:59-82`: In einzeiligen `<input>`/`<select>` löst Enter **nicht** Submit aus,
sondern fokussiert das nächste Feld; erst beim letzten Feld wird submittet.

Das weicht von der etablierten Web-Konvention ab (Enter in einem Formularfeld = Absenden).
Power-User, die „Titel eingeben → Enter → fertig" erwarten, landen stattdessen im nächsten
Feld. Das Verhalten ist clever, aber **unerwartet** und nicht entdeckbar.

**Empfehlung:** Entweder zur Standardkonvention zurückkehren (Enter = Submit) **oder** das
Verhalten nur dort aktivieren, wo es sinnvoll ist (mehrstufige Formulare), und es nicht als
globalen Default im Shared-Modal verankern. Mindestens dokumentieren/testen, ob Nutzer es
als hilfreich empfinden.

#### 1.5 Dirty-Check-State-Management im Modal ist fragil
`modal.js:320-355`: Beim Schließen eines „dirty" Formulars wird der globale `activeOverlay`
kurzzeitig auf `null` gesetzt, um die Bestätigungs-Modal ohne Deadlock zu öffnen, danach
wiederhergestellt. Diese manuelle State-Jonglage (id entfernen/zurücksetzen, Snapshot
sichern/restaurieren) ist schwer nachvollziehbar und eine typische Quelle für
Race-Conditions (z. B. schnelles Doppel-Schließen, Hardware-Back während Confirm offen).

**Empfehlung:** Kein funktionaler Bug gefunden, aber als technisches Risiko vormerken — bei
nächster Modal-Arbeit auf eine explizite State-Maschine (`idle | open | confirming | closing`)
umstellen, statt globale Variablen temporär zu „leihen".

#### 1.6 Login-Feld nutzt `autocomplete="username"`, aber kein passender Tastatur-/Typ-Hint
`login.js:49` setzt korrekt `autocomplete="username"` und `current-password`. Falls der
Login per **E-Mail** erfolgt (User-Profil deutet darauf hin), fehlen `type="email"` +
`inputmode="email"` + `autocapitalize="none"` — auf Mobile erscheint sonst die falsche
Tastatur und Auto-Korrektur greift. (Verifizieren, ob Login = Benutzername oder E-Mail.)

---

### 🟢 P3 — Optionaler Feinschliff / strategisch

#### 1.7 Datenvisualisierung: Screenreader-Zusammenfassung für Budget-Chart
`budget.js:361` rendert ein Kategorie-Diagramm (`.budget-chart`). Tabs, Buttons und
Fortschrittsbalken sind sauber gelabelt (`aria-label`, `role="tablist"`), aber das Chart
selbst hat keine textuelle Zusammenfassung/Tabellen-Alternative (`screen-reader-summary`,
`data-table`, Charts-Kategorie). Für ein einzelnes Balken-/Kategorie-Chart ist die Wirkung
gering, aber eine `aria-label`-Kurzzusammenfassung („3 Kategorien, größte: Lebensmittel
42 %") schließt die Lücke günstig.

#### 1.8 `selectModal`/`promptModal`: Option-Labels nicht escaped
`modal.js:471` fügt `o.label` und `modal.js:239` `title` direkt in den HTML-String ein.
Sofern Aufrufer Nutzerdaten als Label/Titel übergeben, ist das ein XSS-Vektor (eher
Security als UX, aber im selben Code-Pfad). Prüfen, ob alle Aufrufer `esc()` anwenden bzw.
zentral in `openModal` escapen.

#### 1.9 Primär-Aktion via FAB vs. versteckte Toolbar-Buttons
`layout.css:689-695` blendet die „Neu"-Buttons der Module global per
`display:none !important` aus, der FAB übernimmt. Konsistent und sauber — Hinweis nur:
Das ist ein hartkodierter ID-Block; jedes neue Modul muss daran denken, seinen
Toolbar-Button hier zu ergänzen, sonst erscheinen **zwei** Erstellen-Wege. Künftig besser
über eine gemeinsame Klasse (`.toolbar-new-btn`) statt ID-Liste lösen.

---

## 2. Light/Dark-Mode — Detailprüfung

**Stärken:** Eigene desaturierte Akzentwerte im Dark-Mode (`#a78bfa` statt invertiertem
Violet), separat gerechnete Toast-Textfarben mit dokumentierten Kontrasten (13–15:1),
angehobene `--lg-blob-opacity` für Dark, verstärkte Schatten.

**Beobachtungen:**
- **Beide Themes wurden offensichtlich getrennt durchdacht** (nicht nur invertiert) — der
  Pflicht-Check aus der Dark-Mode-Pairing-Regel ist erfüllt.
- Empfehlung: Einen **automatisierten Kontrast-Check** in die Test-Suite aufnehmen
  (Token-Paare Text/Surface in beiden Themes gegen WCAG 4.5:1 prüfen). Die Werte sind heute
  per Hand-Kommentar belegt — ein Test verhindert Regressionen bei künftigen Token-Änderungen.
- `--neutral-500` ist in beiden Themes identisch `#8E8D89` (`tokens.css:70` / `:523`). Als
  mittlerer Grauton auf gegensätzlichen Hintergründen ist der Kontrast in einem der beiden
  Modi tendenziell knapp — gezielt für `--color-priority-low` / Disabled-Texte verifizieren.

---

## 3. Was bewusst KEIN Problem ist (Fehlbefunde ausgeschlossen)

Bei der Prüfung verifiziert und **als korrekt bestätigt**:

- **`maximum-scale=5`** (`index.html:6`): erlaubt Zoom bis 5× — kein Zoom-Verbot, a11y-konform.
- **Bottom-Nav Icon-Well 32px** (`layout.css:582`): Das umschließende `.nav-item` hat
  `min-height: var(--target-lg)` (48px) — das Touch-Target ist konform, nur das visuelle
  Well ist kleiner. Korrekt.
- **Modul-CSS ohne eigenen `reduced-motion`-Block** (calendar/tasks/shopping/settings):
  durch den globalen `*`-Block in `reset.css:72` abgedeckt. Kein Mangel.
- **Hardcodierte Hex-Werte in `notes.js`/`calendar.js`**: nutzerwählbare Farbpaletten;
  Google-Logo-Farben in `settings.js`: offizielle Brand-Assets. Legitim.

---

## 4. Priorisierte Maßnahmenliste

| # | Befund | Datei | Prio | Aufwand |
|---|--------|-------|------|---------|
| 1.1 | `theme-color` auf Violet angleichen | `index.html:9` | 🔴 P1 | XS |
| 1.2 | `100vw` → `100%` | `login.css:13` | 🔴 P1 | XS |
| 1.3 | `text-2xs` → `text-xs` (3 Stellen) | `layout.css`, `reminders.css` | 🔴 P1 | S |
| 1.4 | Enter-im-Modal-Verhalten überdenken | `modal.js:59` | 🟡 P2 | M |
| 1.6 | Login-Feld `type`/`inputmode` prüfen | `login.js:49` | 🟡 P2 | S |
| 1.8 | Modal-Labels zentral escapen | `modal.js:239,471` | 🟡 P2 | S |
| 1.5 | Modal-State-Maschine refactoren | `modal.js:320` | 🟢 P3 | L |
| 1.7 | Chart-SR-Zusammenfassung | `budget.js:361` | 🟢 P3 | S |
| — | Kontrast-Test in Suite | `test-*` | 🟢 P3 | M |
| 1.9 | Toolbar-„Neu"-Ausblendung via Klasse | `layout.css:689` | 🟢 P3 | S |

**Empfehlung:** P1 (1.1–1.3) sind drei winzige, risikoarme Änderungen mit sofort sichtbarer
Wirkung — ideal als nächster kleiner PR. P2 erfordert eine Produktentscheidung (v. a. 1.4).
P3 ist Backlog-Material.
