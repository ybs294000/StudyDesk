# UI / UX Guide

## Design Philosophy

**Three words: Clean. Focused. Fast.**

StudyDesk should feel like a premium productivity tool, not a toy. Think Linear.app or Notion meets a study app. Every pixel should earn its place. No gradients for the sake of gradients. No animations that don't serve the user. No information that doesn't need to be there.

The UI must never distract from studying. When a student is looking at a flashcard, the only things that should exist are the card and their rating buttons. Everything else disappears.

---

## Design Tokens

### Color Palette

```dart
// Primary Brand
primary:        #6C63FF   // Soft violet — modern, not aggressive
primary_light:  #A89DFF
primary_dark:   #4B44CC

// Semantic
success:        #22C55E   // Green — correct answers
error:          #EF4444   // Red — wrong answers
warning:        #F59E0B   // Amber — timer warnings
info:           #3B82F6   // Blue — neutral info

// Neutrals (Light Theme)
background:     #F8F9FC
surface:        #FFFFFF
surface_variant:#F1F3F8
border:         #E2E8F0
text_primary:   #0F172A
text_secondary: #64748B
text_disabled:  #CBD5E1

// Neutrals (Dark Theme)
background:     #0F1117
surface:        #1A1D27
surface_variant:#222534
border:         #2D3148
text_primary:   #F1F5F9
text_secondary: #94A3B8
text_disabled:  #475569

// Subject Colors (user picks from these 12)
subject_colors: [
  #6C63FF, #EC4899, #F59E0B, #22C55E,
  #3B82F6, #EF4444, #14B8A6, #8B5CF6,
  #F97316, #06B6D4, #84CC16, #E879F9
]
```

### Typography

```dart
// Font: Inter (Google Fonts — free, excellent readability)
// If not available: system font fallback

display_large:   32sp, weight 700  // Screen titles
display_medium:  24sp, weight 700  // Section headers
headline:        20sp, weight 600  // Card titles
title:           16sp, weight 600  // List item titles
body_large:      16sp, weight 400  // Primary body text
body_medium:     14sp, weight 400  // Secondary body, card text
body_small:      12sp, weight 400  // Captions, metadata
label:           13sp, weight 500  // Buttons, chips, labels
mono:            14sp, weight 400  // Code, formulas (JetBrains Mono)
```

### Spacing Scale (8px base grid)

```
4px   — micro (icon padding, tight gaps)
8px   — xs
12px  — sm
16px  — md (default padding)
20px  — md+
24px  — lg
32px  — xl
40px  — 2xl
48px  — 3xl
64px  — 4xl
```

### Border Radius
```
4px   — small elements (chips, badges)
8px   — buttons, inputs
12px  — cards
16px  — modals, bottom sheets
24px  — full-height panels
999px — pills, toggles
```

### Elevation / Shadows (Light Mode)
```
level_0: none (flat surfaces)
level_1: 0 1px 3px rgba(0,0,0,0.08)   — cards
level_2: 0 4px 12px rgba(0,0,0,0.10)  — dropdowns, menus
level_3: 0 8px 24px rgba(0,0,0,0.12)  — modals
```

### Animation Durations
```
instant:    0ms   — no animation (data loading)
fast:       150ms — micro-interactions (button press)
normal:     250ms — navigation transitions
slow:       350ms — card flips, modal open
```

---

## Navigation Architecture

### Bottom Navigation Bar (Mobile)
5 tabs:
1. 🏠 **Home** — Dashboard + Subject grid
2. 📚 **Library** — All decks, quizzes, sheets browsable
3. ▶️ **Study** — Quick study session launcher
4. 📊 **Analytics** — Stats and progress
5. ⚙️ **Settings** — Profile, preferences, data

### Navigation Rail (Tablet/Desktop)
Left-side vertical rail showing the same 5 destinations with labels.

### Nested Navigation
- Home → Subject Detail → Deck/Quiz/Sheet
- Each level has a back arrow in the top bar
- Top bar title updates to show context (e.g., "Chemistry / Flashcards / Functional Groups")

---

## Screen Specifications

---

### Screen 1: Home / Dashboard

**Purpose:** At-a-glance overview. What do I need to study today?

**Layout (Mobile, scrollable):**

```
┌────────────────────────────────┐
│ StudyDesk         [🔔] [+]    │  ← App bar: notification bell + add button
├────────────────────────────────┤
│ Good morning, Student 👋       │  ← Greeting (time-based: morning/afternoon/evening)
│ You have 24 cards due today    │  ← Dynamic subtitle
├────────────────────────────────┤
│ ╔══════════════════════════╗   │
│ ║  TODAY'S SUMMARY         ║   │  ← Highlighted card, primary color bg
│ ║  📇 24 cards due          ║   │
│ ║  🔥 7-day streak          ║   │
│ ║  ⏱ 0 min studied today   ║   │
│ ║  [Start Today's Review]   ║   │  ← Primary CTA button
│ ╚══════════════════════════╝   │
├────────────────────────────────┤
│ Your Subjects                  │
│ [+ Add Subject]                │
│                                │
│ ┌──────────┐ ┌──────────┐     │
│ │ ⚗️        │ │ 📐        │     │
│ │Chemistry  │ │ Maths    │     │
│ │ 47 cards  │ │ 23 cards │     │
│ │ ●●●○○    │ │ ●●●●○    │     │  ← 5-dot retention indicator
│ │ Due: 12  │ │ Due: 0   │     │
│ └──────────┘ └──────────┘     │
│                                │
│ ┌──────────┐ ┌──────────┐     │
│ │ 💻        │ │ + New    │     │
│ │ DSA       │ │ Subject  │     │
│ │ 31 cards  │ │          │     │
│ │ ●●○○○    │ │          │     │
│ │ Due: 8   │ │          │     │
│ └──────────┘ └──────────┘     │
├────────────────────────────────┤
│ Recent Activity                │
│ • Chemistry Flashcards  2h ago │
│ • Maths Quiz — 82%     1d ago  │
│ • DSA Concepts         3d ago  │
└────────────────────────────────┘
```

**Subject Card Design:**
- Background: white (light) / surface (dark), 12px radius, level_1 shadow
- Left accent bar: 4px wide, subject's chosen color
- Emoji: 28sp, top left
- Name: headline weight
- Card count: body_small, text_secondary
- Retention dots: 5 filled/empty circles in subject color
- "Due: N" badge: small chip, red if N > 0, gray if 0
- Tap → Subject Detail screen
- Long press → context menu (Edit, Delete, Export)

---

### Screen 2: Subject Detail

**Purpose:** See everything in one subject. Launch any study mode.

**Layout:**
```
┌────────────────────────────────┐
│ ←  ⚗️ Chemistry     [⋮ menu]   │
├────────────────────────────────┤
│ [Flashcards] [Quizzes] [Sheets]│  ← Segmented control / tab bar
│              [Q&A]              │
├────────────────────────────────┤
│ (When Flashcards tab active)   │
│                                │
│ ┌──────────────────────────┐   │
│ │ Functional Groups        │   │
│ │ 24 cards • Due: 12       │   │
│ │ Last studied: 2 days ago │   │
│ │        [Study Now →]     │   │
│ └──────────────────────────┘   │
│                                │
│ ┌──────────────────────────┐   │
│ │ Reaction Mechanisms       │   │
│ │ 18 cards • Due: 0        │   │
│ │ Last studied: today      │   │
│ │        [Browse Cards]    │   │
│ └──────────────────────────┘   │
│                                │
│        [+ New Deck]            │
│        [Import Deck (JSON)]    │
└────────────────────────────────┘
```

**Deck Card:**
- Show study button prominently if cards are due
- Show "Browse Cards" (non-urgent) if no cards due
- Progress bar showing % mature cards

---

### Screen 3: Flashcard Study Session

**Purpose:** Distraction-free study environment.

**Layout:**
```
┌────────────────────────────────┐
│ ←  Functional Groups   [✕ end] │
│ ████████████░░░░░░░░░ 8/20    │  ← Progress bar
├────────────────────────────────┤
│                                │
│                                │
│   ╔══════════════════════╗     │
│   ║                      ║     │
│   ║  What is the         ║     │
│   ║  functional group    ║     │
│   ║  of an **alcohol**?  ║     │
│   ║                      ║     │
│   ║  [💡 Hint]           ║     │  ← Only if hint exists
│   ╚══════════════════════╝     │
│                                │
│   ↕ tap card or button below   │
│                                │
│   ┌──────────────────────┐     │
│   │    Show Answer       │     │  ← Outlined button
│   └──────────────────────┘     │
│                                │
└────────────────────────────────┘
```

**After tapping (card flips 3D):**
```
┌────────────────────────────────┐
│ ←  Functional Groups   [✕ end] │
│ ████████████░░░░░░░░░ 8/20    │
├────────────────────────────────┤
│                                │
│   ╔══════════════════════╗     │
│   ║  BACK SIDE           ║     │
│   ║                      ║     │
│   ║  Hydroxyl group:     ║     │
│   ║  **–OH**             ║     │
│   ║                      ║     │
│   ║  Example: Ethanol    ║     │
│   ║  (CH₃CH₂OH)         ║     │
│   ╚══════════════════════╝     │
│                                │
│  How well did you recall?      │
│                                │
│  [Again] [Hard] [Good] [Easy]  │
│  ← 1d    3d     5d     8d →   │  ← Show next interval under each button
│                                │
└────────────────────────────────┘
```

**Card Design:**
- Large, centered, occupies ~60% of screen height
- White/surface background, strong shadow
- Markdown rendered (bold, italic, LaTeX, images)
- Flip: horizontal 3D rotation, 300ms, ease-in-out
- Card front: lighter background or subtle pattern
- Card back: slightly different tint (e.g., 2% primary tint)

**Rating Buttons:**
- 4 buttons in a row
- Again: red/error color
- Hard: orange/warning color
- Good: primary color
- Easy: green/success color
- Show next interval (e.g., "5d") below each button in small gray text

**Swipe Gestures (mobile):**
- Right swipe → Easy
- Left swipe → Again
- Up swipe → Good
- Down swipe → Hard
- Show swipe indicator arrows on first 3 cards (onboarding hint), then hide

**Session End Screen:**
```
┌────────────────────────────────┐
│         Session Complete! 🎉   │
├────────────────────────────────┤
│                                │
│   Cards reviewed: 20           │
│   Correct:        16 (80%)     │
│   Time:           12 min       │
│   Streak:         🔥 7 days    │
│                                │
│   ┌──────────────────────┐     │
│   │ Again (review later) │  4  │  ← Count per rating
│   │ Hard                 │  3  │
│   │ Good                 │  8  │
│   │ Easy                 │  5  │
│   └──────────────────────┘     │
│                                │
│   Next review due: Tomorrow    │
│                                │
│   [Study Again] [Done]         │
└────────────────────────────────┘
```

---

### Screen 4: Quiz Session

**Intro Screen:**
```
┌────────────────────────────────┐
│ ← Organic Chemistry Midterm    │
├────────────────────────────────┤
│   📝 Practice Quiz             │
│   20 questions                 │
│   ⏱ 30:00 minutes              │
│   Passing score: 60%           │
│                                │
│   Marking: +1 correct, 0 wrong │
│                                │
│   ┌──────────────────────┐     │
│   │     Start Quiz       │     │
│   └──────────────────────┘     │
│                                │
│   [View Questions First]       │
└────────────────────────────────┘
```

**Question Screen (MCQ):**
```
┌────────────────────────────────┐
│  Q 3/20          ⏱ 28:14      │
│  ████░░░░░░░░░░░░░░░░          │
├────────────────────────────────┤
│                                │
│  Which of the following is a   │
│  **primary alcohol**?          │
│                                │
│  ○  2-propanol                 │
│  ○  1-butanol                  │
│  ○  2-butanol                  │
│  ○  2-methyl-2-propanol        │
│                                │
│                                │
│  [Skip]              [Next →]  │
└────────────────────────────────┘
```

**After selecting option (immediate feedback OFF):**
- Selected option gets primary color highlight
- "Next" button activates

**After selecting option (immediate feedback ON):**
- Correct option → green background + ✓
- Wrong option → red background + ✗
- Correct option shown if user was wrong
- Explanation shown below in a card
- "Next" button

**Timer:**
- Top right, live countdown
- Yellow at 25% time remaining
- Red at 10% time remaining, subtle pulse animation
- At 0:00, auto-submit current question and end quiz

**Question Screen (Short Answer):**
```
┌────────────────────────────────┐
│  Q 12/20         ⏱ 18:32      │
├────────────────────────────────┤
│                                │
│  Explain why carboxylic acids  │
│  are more acidic than alcohols.│
│  (2-4 sentences)               │
│                                │
│  ┌──────────────────────────┐  │
│  │ Type your answer here... │  │
│  │                          │  │
│  │                          │  │
│  └──────────────────────────┘  │
│  Word count: 0 / min 20        │
│                                │
│  [Skip]              [Next →]  │
└────────────────────────────────┘
```

**Results Screen:**
```
┌────────────────────────────────┐
│         Quiz Complete!         │
├────────────────────────────────┤
│                                │
│         16 / 20                │  ← Large score, prominent
│            80%                 │
│         ✅ PASSED              │  ← Green badge
│                                │
│  ┌────────────────────────┐    │
│  │ Time taken:  22:18     │    │
│  │ Correct:     16        │    │
│  │ Wrong:        3        │    │
│  │ Skipped:      1        │    │
│  └────────────────────────┘    │
│                                │
│  [Review All Answers]          │
│  [Retry Wrong Answers Only]    │
│  [Done]                        │
└────────────────────────────────┘
```

**Answer Review Screen:**
- List of all questions, expandable
- Green row = correct, Red row = wrong
- Expand to see: your answer / correct answer / explanation
- Short answers show keyword match result

---

### Screen 5: Reference Sheet Viewer

**Default Mode:**
```
┌────────────────────────────────┐
│ ←  Thermodynamics     [🎭] [⋮]│  ← 🎭 = rehearsal mode toggle
├────────────────────────────────┤
│  # Thermodynamics Formulas     │  ← Markdown rendered
│                                │
│  ## First Law                  │
│  ΔU = Q − W                    │  ← LaTeX rendered
│                                │
│  - ΔU = change in internal...  │
│  - Q = heat added...           │
│                                │
│  ## Entropy                    │
│  ΔS = Q_rev / T               │
│                                │
│  [▶ What does 2nd Law state?] │  ← Toggle block, closed state
│                                │
│  ## Ideal Gas Law              │
│  PV = nRT                      │
│                                │
│  | P | Pressure | Pa |         │  ← Table rendered
│  | V | Volume   | m³ |         │
└────────────────────────────────┘
```

**Rehearsal Mode (toggle active):**
- Toggle blocks now show ONLY the question, answer is blurred/hidden
- "Tap to reveal" hint text
- Tap reveals answer with a smooth fade-in
- Tap again to re-hide
- Non-toggle content stays normal

**Font Size Control:**
- Three-dot menu → Font: Small / Medium / Large
- Persists per sheet

---

### Screen 6: Analytics Dashboard

**Layout:**
```
┌────────────────────────────────┐
│  Analytics          [Week ▾]   │  ← Week / Month / 3 Months / All Time
├────────────────────────────────┤
│  🔥 Current streak: 7 days     │
│  🏆 Longest: 14 days           │
├────────────────────────────────┤
│  Study Activity                │
│  ┌──────────────────────────┐  │
│  │ M  T  W  T  F  S  S      │  │  ← Heatmap: GitHub-style
│  │ ■  ■  □  ■  ■  ■  □      │  │  ← ■ = studied, □ = didn't
│  │ (color intensity = time) │  │
│  └──────────────────────────┘  │
├────────────────────────────────┤
│  This Week                     │
│  ┌────────┐ ┌────────┐        │
│  │  124   │ │  43    │        │
│  │ cards  │ │ quiz Qs│        │
│  └────────┘ └────────┘        │
│  ┌────────┐ ┌────────┐        │
│  │ 3.2 hr │ │  78%   │        │
│  │studied │ │accuracy│        │
│  └────────┘ └────────┘        │
├────────────────────────────────┤
│  By Subject                    │
│  [Pie chart: time per subject] │
├────────────────────────────────┤
│  Accuracy Trend                │
│  [Line chart: % over 7 days]   │
├────────────────────────────────┤
│  [📤 Export Analytics as JSON] │  ← Exports for AI analysis
└────────────────────────────────┘
```

---

### Screen 7: Reminders & Important Dates

```
┌────────────────────────────────┐
│ ← Reminders & Dates            │
├────────────────────────────────┤
│  Upcoming                      │
│  ┌──────────────────────────┐  │
│  │ 📅 Chemistry Midterm     │  │
│  │ Jun 15 — 9 days away     │  │
│  │ [Study Chemistry →]      │  │  ← Quick link to subject
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ 🧪 Physics Practical     │  │
│  │ Jun 12 — 6 days away     │  │
│  └──────────────────────────┘  │
│                                │
│  [+ Add Exam / Event]          │
├────────────────────────────────┤
│  Daily Study Reminder          │
│  ○ Enabled  ● Disabled         │  ← Toggle
│  Time: 8:00 PM  [Change]       │
└────────────────────────────────┘
```

**Add Event Sheet (bottom sheet):**
- Event name (text)
- Type: Exam / Viva / Practical / Assignment / Other
- Date picker
- Linked subject (optional dropdown)
- Notes (optional)

---

### Screen 8: Link Box (Study Resources)

```
┌────────────────────────────────┐
│ ← Link Box                     │
│                         [+ Add]│
├────────────────────────────────┤
│  [All ▾]  [Chemistry] [Maths]  │  ← Filter chips by subject tag
├────────────────────────────────┤
│  ┌──────────────────────────┐  │
│  │ 🔗 MIT OpenCourseWare    │  │
│  │ Thermodynamics lectures  │  │
│  │ chemistry • course       │  │
│  │ [Open] [Copy] [Delete]   │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ 🔗 3Blue1Brown — Calculus │  │
│  │ YouTube playlist         │  │
│  │ maths • video            │  │
│  └──────────────────────────┘  │
└────────────────────────────────┘
```

**Add Link Sheet:**
- URL input (paste or share from browser)
- Custom name (auto-fetch page title if possible)
- Tags: subject link / course / video / article / reference
- Linked subject (optional)

---

### Screen 9: Settings

```
┌────────────────────────────────┐
│  Settings                      │
├────────────────────────────────┤
│  Appearance                    │
│  Theme    [Light] [Dark] [Auto]│  ← Segmented control
│                                │
│  Study Preferences             │
│  Max cards/session      20 [>] │
│  Auto-flip timer         Off[>]│
│  Show next intervals     On  ○ │
│                                │
│  AI Integration          [>]   │  ← Opens AI config screen
│                                │
│  Reminders & Dates       [>]   │
│                                │
│  Data                          │
│  Import JSON             [>]   │
│  Export All Data         [>]   │
│  Export Analytics (JSON) [>]   │
│  Storage used: 24 MB           │
│  Clear study history     [>]   │
│                                │
│  About                         │
│  Version 1.0.0                 │
│  JSON Format Docs        [>]   │  ← In-app docs for the format
└────────────────────────────────┘
```

---

## Component Library

### Primary Button
```
Background: primary (#6C63FF)
Text: white, 14sp, weight 600
Padding: 12px vertical, 24px horizontal
Border radius: 8px
Height: 48px (touch target)
Pressed state: darken 10%
Disabled: 40% opacity
```

### Secondary Button (Outlined)
```
Background: transparent
Border: 1.5px solid primary
Text: primary, 14sp, weight 600
Same sizing as Primary
```

### Text Button
```
No background, no border
Text: primary, 14sp, weight 500
Used for less important actions
```

### Cards
```
Background: surface
Border radius: 12px
Padding: 16px
Shadow: level_1
Hover (desktop): level_2 + slight scale(1.01)
```

### Input Fields
```
Background: surface_variant
Border: 1px solid border (default), primary (focused), error (error)
Border radius: 8px
Padding: 12px 16px
Label: floats above on focus
Height: 48px (single line), auto (multiline)
```

### Chip / Tag
```
Background: primary at 10% opacity
Text: primary, 12sp, weight 500
Border radius: 4px
Padding: 4px 8px
```

### Progress Bar
```
Height: 6px
Background: border color
Fill: primary
Border radius: 3px (pill)
Animated with linear transition
```

### Bottom Sheet
```
Background: surface
Border radius: 16px top-left, 16px top-right
Drag handle: 4px x 32px, centered, border color
Padding: 8px (handle) + 16px (content)
```

---

## Responsive Breakpoints

```
Mobile:   < 600px  — single column, bottom nav bar
Tablet:   600-900px — two column grid for subjects, nav rail
Desktop:  > 900px  — three column grid, nav rail + expanded labels
```

On tablet/desktop:
- Subject grid: 2-3 columns
- Study session: card is max-width 500px, centered
- Analytics: side-by-side panels

---

## Micro-interactions

- **Button tap**: scale down to 0.97, 80ms, spring back
- **Card selection**: instant highlight color change
- **Flashcard flip**: 3D rotation on X axis
- **Swipe to rate**: card follows finger, fades color (red left, green right)
- **Success sound**: subtle tick on correct answer (optional, user setting)
- **Streak badge**: small confetti burst when streak increases
- **Loading state**: shimmer skeleton for list items (never a spinner for local data)
- **Error toast**: bottom snackbar, red, auto-dismiss 4s
- **Success toast**: bottom snackbar, green, auto-dismiss 2s

---

## Accessibility

- All interactive elements: minimum 48x48px touch target
- Color is never the only indicator (always paired with icon or text)
- Font sizes respect system accessibility settings
- All images have semantic labels for screen readers
- Contrast ratios: minimum 4.5:1 for text (WCAG AA)
- Dark mode fully implemented — not just inverting colors
