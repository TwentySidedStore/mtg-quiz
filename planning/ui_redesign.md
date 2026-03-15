# Quiz UI Redesign — Tabbed Interface

## Goal
Replace the dropdown topic selector with a Bulma tabbed interface. Improve desktop width and add a mobile hamburger menu for the tabs.

## Current State
- Topic selection: `<select>` dropdown in a centered box
- Container: `max-width: 800px; margin: 0 auto`
- No navbar — just a centered `<h1>` title
- Views: select, quiz, score, review, empty (toggled via `.is-hidden`)
- Mobile: works but dropdown feels clunky

## Proposed Design

### Layout Structure
```
┌──────────────────────────────────────────────────┐
│  Navbar (is-dark)                      [burger]  │
│  "MTG Rules Quiz"                                │
├──────────────────────────────────────────────────┤
│  Tabs (desktop: horizontal row)                  │
│  [Basics] [Multiplayer] [2HG] [Stack] [Adv] [Edge]
├──────────────────────────────────────────────────┤
│                                                  │
│  Quiz content (card, buttons, etc.)              │
│  max-width: 900px, margin: 0 auto, padding       │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Desktop (>=769px)
- Navbar at top with title "MTG Rules Quiz" on the left
- Tabs below navbar showing all 6 topics horizontally
- Active tab is highlighted (Bulma `is-active`)
- Below tabs: topic description + question count + "Start Quiz" button
- Quiz content in a centered container, `max-width: 900px`
- Burger is hidden

### Mobile (<769px)
- Navbar with title + hamburger icon on the right
- Hamburger toggles a vertical menu with the 6 topics listed
- Tapping a topic selects it and closes the menu
- Below: same quiz content, full-width with padding

### Navbar Details
- Bulma `navbar is-dark`
- `navbar-brand`: title "MTG Rules Quiz"
- `navbar-burger`: standard Bulma burger (3 spans)
- `navbar-menu`: contains nothing (tabs are separate) OR contains the topic list on mobile
- Actually — simpler approach: put the tabs IN the navbar-menu so Bulma's burger naturally toggles them

**Decision: Tabs-in-navbar approach**
- Desktop: navbar with title + horizontal tabs in `navbar-end`
- Mobile: burger toggles dropdown with topic links
- This avoids a separate tab bar and a separate burger — Bulma handles it

### Revised Structure
```html
<nav class="navbar is-dark">
  <div class="navbar-brand">
    <span class="navbar-item has-text-weight-bold">MTG Rules Quiz</span>
    <a class="navbar-burger" id="burger">
      <span></span><span></span><span></span>
    </a>
  </div>
  <div class="navbar-menu" id="navbar-menu">
    <div class="navbar-end">
      <a class="navbar-item is-active" data-topic="fundamentals">Basics</a>
      <a class="navbar-item" data-topic="multiplayer">Multiplayer</a>
      <a class="navbar-item" data-topic="2hg">Two-Headed Giant</a>
      <a class="navbar-item" data-topic="stack_triggers">Stack & Priority</a>
      <a class="navbar-item" data-topic="interactions">Advanced</a>
      <a class="navbar-item" data-topic="edge_cases">Edge Cases</a>
    </div>
  </div>
</nav>
```

### JavaScript for Burger
```js
document.getElementById('burger').addEventListener('click', () => {
  document.getElementById('burger').classList.toggle('is-active');
  document.getElementById('navbar-menu').classList.toggle('is-active');
});
```

### Topic Selection Flow (revised)
1. User clicks a tab/topic → tab highlights, content area shows description + count + Start
2. During quiz: tabs remain visible but clicking one quits the quiz (with confirmation?) or is disabled
3. After quiz: tabs re-enable, user can pick another topic

### CSS Changes
- Container: `max-width: 900px; margin: 0 auto; padding: 1.5rem`
- Remove the old `<h1>` title (now in navbar)
- Remove the `<select>` dropdown and its wrapping box
- Topic description + Start button live directly in the content area
- On mobile: navbar-menu drops down, tapping topic closes menu

## Implementation Steps

1. **Replace the `<section>` header with a Bulma navbar**
   - Add `navbar is-dark` with brand + burger + menu
   - Put topic links in `navbar-end` with `data-topic` attributes
   - Add burger toggle JS

2. **Replace the select view with tab-driven content**
   - Remove the `<select>` dropdown and its box
   - Keep the description/count/start-button area, but populate it from the active tab
   - Highlight the active tab with `is-active` or a CSS class

3. **Style the active tab**
   - On dark navbar, active item could use `has-background-grey-dark` or Bulma's built-in active styling
   - Or use a bottom-border highlight

4. **Update quiz flow**
   - When quiz is active, visually indicate the current topic in navbar (keep it highlighted)
   - Disable other tabs OR clicking another tab quits quiz and switches
   - Simplest: clicking a tab during a quiz confirms quit, then switches topic

5. **Update the container width**
   - Change `max-width` from 800px to 900px
   - Ensure padding works on mobile

6. **Close mobile menu on topic click**
   - After selecting a topic from the mobile dropdown, close the menu
   - `burger.classList.remove('is-active'); menu.classList.remove('is-active');`

7. **Test**
   - Desktop: tabs display horizontally, content centered
   - Mobile: burger toggles, topics listed vertically, tapping one closes menu
   - Quiz flow works end-to-end
   - Review/score views still work
   - Empty state still works
