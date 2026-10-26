# PREL37 speaker deck design system

**Template:** Microsoft Ignite 2026 PREL37 PowerPoint template, Infra visual variant. The deck is maintained outside this repository.
**Applies to:** [Speaker deck specification](PREL37-speaker-deck.md).

## Canvas and safe areas

The template uses a 16:9 widescreen canvas (13.33 x 7.5 in). Coordinates in the specification are percentages of slide width and height.
Reserve the bottom 15% for captions. Keep critical content within x=5-95%, y=6-80%. A demo's identification bar sits above the caption area.
Use the template's own artwork and Microsoft Azure brand mark. Do not add speaker names, unapproved imagery, or publication URLs that have not been confirmed.

## Color palette

The template is dark throughout. Colors come from its theme.

```markdown
| Role                           | Name                   | Hex     |
| ------------------------------ | ---------------------- | ------- |
| Slide background               | Template navy          | #091F2C |
| Primary text                   | White                  | #FFFFFF |
| Secondary text                 | Template light neutral | #E8E6DF |
| Key principle and label accent | Template green         | #8DE971 |
| Fulfillment/evidence accent    | Template teal          | #49C5B1 |
| Structural accent              | Microsoft Blue         | #0078D4 |
| Code panel                     | VS Code dark           | #1E1E1E |
| Demo identification overlay    | Black, 60% opacity     | #000000 |
```

### Accent strategy

This is a concept-focused workshop about one developer capability, not a product tour. Use green for the one principle or label that a slide asks learners to remember. Use teal sparingly for platform fulfillment and evidence. Tools keep neutral text labels rather than competing product colors.
Use no more than two accents on a slide. Green and teal do not mean success; label states with words such as "submitted," "ready," "pending," and "blocked." A color alone never carries meaning.

## Typography and reusable style tokens

The template theme uses Segoe Sans Text Semibold for titles and Segoe Sans Text for body text. Code uses Consolas. Essential text is at least 18 points; short exercise instructions use 24 points.
Because every slide is dark, the dark-variant tokens (TD, HD, BD, KD, LD) are identical to their base tokens. Both names remain valid in the specification.

```markdown
| Token  | Role                                    | Font                     | Size  | Weight   | Color   |
| ------ | --------------------------------------- | ------------------------ | ----- | -------- | ------- |
| T / TD | Slide title                             | Segoe Sans Text Semibold | 36 pt | Semibold | #FFFFFF |
| H / HD | Subhead or primary statement            | Segoe Sans Text          | 24 pt | Regular  | #FFFFFF |
| B / BD | Body                                    | Segoe Sans Text          | 20 pt | Regular  | #E8E6DF |
| A      | Activity instruction                    | Segoe Sans Text          | 24 pt | Regular  | #FFFFFF |
| K / KD | Key statement                           | Segoe Sans Text Semibold | 32 pt | Semibold | #FFFFFF |
| C      | Code on dark panel                      | Consolas                 | 18 pt | Regular  | #FFFFFF |
| L / LD | Nonessential caption                    | Segoe Sans Text          | 12 pt | Regular  | #E8E6DF |
| P      | Principle or accent label               | Segoe Sans Text Semibold | 20 pt | Semibold | #8DE971 |
| S      | Section, activity, demo, or break label | Segoe Sans Text Semibold | 18 pt | Semibold | #8DE971 |
```

Essential text never uses the 12-point caption style.

## Layout mapping

Each logical layout in the specification maps to a template layout.

```markdown
| Spec layout                              | Template layout                                                  | Zones                                                                                                                         |
| ---------------------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Title Slide                              | Title Slide - Infra 1 (opening), Title Slide - Infra 2 (closing) | TITLE and SUBTITLE in template placeholders; LABEL below the subtitle                                                         |
| Section Title, module                    | Section Title - Infra 1                                          | LABEL ("MODULE n", "SUMMARY", "OPTIONAL") above title; CENTER in title placeholder; BADGE holds the platform fundamental in P |
| Section Title, break                     | Section Title - Infra 2                                          | LABEL "BREAK" above title; CENTER in title placeholder; BADGE below                                                           |
| Demo                                     | Demo slide - Infra                                               | LABEL "DEMO n" above title; CENTER in title placeholder; BADGE in subtitle placeholder holds up to four "watch for" items     |
| Promise tracker                          | Title and Content                                                | TITLE placeholder; tracker grid x5-68% y21-68%; "Instead of" column x72-95%; LABEL y72-80% for the module point               |
| What you'll do                           | Title Only                                                       | TITLE placeholder; step cards y21-52%; done-when strip y56-70%; LABEL y72-80% for the module point                            |
| Title Only plus a lab map or app diagram | Title Only                                                       | TITLE placeholder; lab map y20-68%; LABEL y72-80% split left (legend) and right                                               |
| Title and Content                        | Title and Content                                                | TITLE placeholder; BODY y21-70%; LABEL y72-80%                                                                                |
| Two Content                              | Two Column Bullet with Subheads                                  | TITLE placeholder; LEFT and RIGHT subhead plus body; LABEL y72-80%                                                            |
| Two Content with code                    | Title Only plus a code panel                                     | TITLE placeholder; code panel x5-50%; RIGHT x54-95%; LABEL y72-80%                                                            |
| Activity, Discussion, Checkpoint         | Title and Content                                                | LABEL with type and duration above title in S; BODY in A; FOOTER y72-80% names the guide section                              |
```

### Module divider

Every section of the deck opens with a module divider, so the slide sorter and the room both see the workshop modules as the structure. The BADGE names the one platform fundamental the module teaches. Use PowerPoint sections with the same names as the dividers.

### Module path

Slide 2 shows the six modules as equal rounded rectangles in one row, left to right, from x5% to x95% in the BODY zone. Each card stacks the module label in S, a short name in H, and the start time in L, top-aligned. Cards use the same neutral #E8E6DF outline as an unfilled promise tracker chip. Breaks are dashed vertical rules labeled "BREAK" in L, placed in widened gaps after Modules 2 and 4. Use the same card names on every slide that refers back to the path.

### Lab map

Slide 3 draws the lab as four labeled zones: the lab VM, the control cluster, the workload cluster, and an Azure strip beneath both clusters. Pieces that are ready before Module 1 are solid teal #49C5B1 outlined chips. Pieces learners build are dashed green #8DE971 outlined chips with a module badge ("M2", "M3", "M4") that matches the module path. The legend states both meanings in words; line style and badge, not color alone, carry the distinction. Connectors are thin #E8E6DF arrows with short text labels.

### Promise tracker

The promise tracker is the "team gets" list from Module 1, drawn as eleven equal chips in a 4-4-3 grid. It appears neutral on Module 1's slide 9, on each module's "why" slide, and complete on the summary.

- **This module:** green #8DE971 outline with the label "this module".
- **Delivered earlier:** teal #49C5B1 outline with the label "delivered" (or "prepared" for items set up before the session).
- **Not yet:** neutral #E8E6DF outline, no label.

Every state carries a text label; color never carries meaning alone. Keep chip text identical across slides so learners recognize the same list. When the tracker leaves room on the right, "not given" items appear as "instead of" pairs: the withheld item struck through in neutral, an arrow, and what the team gets instead in B. Use the same pair wording on the module slide and the summary.

### Step row and done when

Every "what you'll do" slide uses the same two bands. Step cards sit in one row, equal width, numbered with a large green #8DE971 numeral in H, a short verb phrase in B, and a type tag in L at the bottom of the card (Worksheet, PR, Backstage, kubectl, Edit, Read, Verify). When steps change role, a thin bracket above the cards names the group, such as "As the platform engineer" and "As the developer". Below the cards, the done-when strip is a full-width neutral #E8E6DF band headed "Done when" in S, with each item as an empty checkbox and a short phrase in B. Never join steps or done-when items with semicolons; each gets its own shape.

### Card grids and stacks

Use shapes, not delimited lists, whenever a slide compares items. A 2x2 grid suits four parallel controls (slide 52). A vertical layer stack suits defense in depth, with convenience layers neutral and control layers teal, each labeled in words (slide 41). Two lanes joined by an arrow suit ownership splits (slide 20). Flows such as the costCenter trace use pills joined by arrows inside one band.
BODY may be subdivided into rows or four labeled cells without a new layout. Never use more than four bullets. Column content uses short labels, not miniature paragraphs. A `->` sequence in the specification renders as an arrow chain.
Code is at most 20 lines per slide. Prefer a short excerpt that makes one point; put full manifests and commands in the learner guide. Never project credentials or use a live terminal as a substitute for an unreadable slide.

## Animation presets

Every slide specification names a preset. The preset is its complete default animation sequence; explicit overrides appear on the slide.

```markdown
| Preset  | Slide transition | Element entrance                                            | Trigger and delay                                                                                         |
| ------- | ---------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Static  | Fade, 0.5 s      | All content visible together; no entrance                   | On load, 0 s                                                                                              |
| Reveal  | Fade, 0.5 s      | Title visible; each numbered body item fades, 0.3 s         | One click per item, 0 s delay; labels visible on load                                                     |
| Compare | Fade, 0.5 s      | Left group fades, 0.3 s; right group fades, 0.3 s           | Separate clicks, 0 s delay; title/labels visible on load                                                  |
| Trace   | Fade, 0.5 s      | Nodes visible; highlight fades onto each stated node, 0.3 s | One click per node, 0 s delay; completed highlights return to neutral                                     |
| Demo    | Fade, 0.5 s      | "Watch for" items visible on load                           | Switch to the live app manually, then return to the slide; recorded fallback starts on click; no autoplay |
```

No automatic slide advance. No Fly-in, Bounce, Spin, or Wipe. Transitions fit inside each phase's allocated time; they do not add time.

## Workshop visual rhythm

Every module follows the same order: divider, why (promise tracker), what you'll do, two or three explanation slides, demo, your turn, debrief, checkpoint. The repeated order tells learners when to listen, watch, act, and stop for discussion.
Each demo is one slide for five minutes. The speaker reads the "watch for" items, switches to the live surface, then returns to the same slide to ground what was shown.
Explanation, activity, discussion, and checkpoint slides use the plain template master. Activity and discussion screens show the type and duration in the label and the guide section in the footer. Module dividers and break screens use section-title artwork with different variants, and their labels say which is which. Checkpoint screens distinguish ready from pending without asking blocked learners to hide their status.
Activity slides remain on screen for 10 or 15 minutes. Debrief and checkpoint screens also hold their full time. These are facilitation surfaces, not material to narrate continuously.

## Demo presentation and fallback assets

Use the separate instructor environment, not a learner's instance. Prefer live demonstrations; no recordings are presumed to exist.
For a recorded fallback, add a hidden slide after the demo slide that fills the canvas with the approved capture, starts it on click, and includes the black 60%-opacity identification bar with the demo label left and tool label right in 18-point white text.
For live software, do not obscure operational controls with an overlay. Identify the demo on its slide, use a persistent prepared browser or window label where practical, and return to the demo slide afterward. A recorded overlay is not an extra software implementation requirement.
Prepare a sanitized recorded fallback for each demo. Label it "Recorded fallback" when used. Never present them as live success or as evidence that an attendee's instance passed.

## Accessibility and production checks

Use descriptive labels as well as color, at least 18-point essential text, and editable shapes with meaningful reading order. Add alt text to meaningful diagrams and screenshots. Keep background decoration out of the code and activity areas.
For projection, enlarge browser/editor text before capturing. Show only the relevant panel and remove credentials, tokens, private telemetry, personal account details, and unrelated tabs.
Confirm Segoe Sans Text is available on the presenter machine. If PowerPoint substitutes a font, review wrapping and code alignment rather than silently accepting the replacement.
The closing slide names the workshop guide and worksheet. Add the published guide URL or QR code once the repository is public; do not invent an aka.ms link.
