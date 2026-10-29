# Hedge Wizard — Disposable Godot Prototype

This project is a disposable design prototype for **Hedge Wizard**, a turn-based village guardian wizard game. Its objective is to allow experiencing the core interaction loop firsthand, discovering interface and game-design problems, and evaluating whether the mechanics are compelling in practice.

---

## 1. Running the Project

### Prerequisites
- Godot Engine 4.x (4.2+ recommended).

### How to Run in Godot Editor
1. Open Godot Engine.
2. Click **Import** and select the `project.godot` file in this repository root.
3. Click **Import & Edit**.
4. Press `F5` (or click the Play button in the top right) to launch the project.

### How to Run Automated Headless Tests
From the terminal:
```bash
godot --headless -s res://tests/test_scenario.gd
```

---

## 2. Project Architecture & Scene Structure

- **`project.godot`**: Project configuration setting `res://scenes/main.tscn` as the main scene.
- **`scenes/`**:
  - `main.tscn`: Main gameplay UI screen with top status bar, left card inventory, right active events area, and bottom event log.
  - `card_ui.tscn`: Panel rendering card title, tag, and description. Supports click-selection and drag-and-drop preview.
  - `slot_ui.tscn`: Slot container with tag requirement verification and card removal/placement controls.
  - `event_ui.tscn`: Panel displaying event title, description, deadline counter, dynamic slot instances, and action resolution buttons.
- **`scripts/`**:
  - `main.gd`: Orchestrates scenario stages (A through D), inventory tracking, event spawning, turn advancement, delayed tasks, and logging.
  - `card_ui.gd`: Handles visual state (selection outline) and mouse inputs/drag data for individual cards.
  - `slot_ui.gd`: Manages card slotting validation based on card tags, rendering slotted cards, and clear button logic.
  - `event_ui.gd`: Manages event instance data (duplicated to prevent shared state), slot instantiation, and action readiness checks.
- **`tests/`**:
  - `test_scenario.gd`: End-to-end integration test running through Stages A to D headlessly.
  - `test_stage_ab.gd`, `test_stage_c.gd`, `test_stage_d.gd`: Specific stage unit tests.

---

## 3. Assumptions Made About Ambiguous Mechanics

1. **Card Retain vs. Consume Rule**: The Wizard card represents the player's presence and is retained in inventory when used in actions, whereas consumed ingredients (e.g., Magical Essence, Tea Leaves, Herbs) are removed from inventory upon action resolution.
2. **Click-to-Slot & Drag-to-Slot Coexistence**: To maximize legibility and accessibility, cards can either be selected by clicking in the inventory and then clicking an empty slot, OR dragged directly onto the slot.
3. **Turn Advancement vs. Instant Actions**: Immediate crafting actions (e.g., brewing tea or crafting a talisman) resolve instantly upon clicking the action button. Delayed tasks (e.g., Gathering Herbs) lock in a background task counter that ticks down each time the player clicks **End Turn**.
4. **Deadline Expiration Timing**: Events with `deadline = 0` expire when the turn is ended if unfulfilled. Since the player has only one Tea card in Stage D, committing tea to one event resolves that event immediately and leaves the other 0-deadline event to expire when advancing time or leaving the screen.

---

## 4. Design Insights & Limitations Exposed by Prototype

- **Visibility of Mutually Exclusive Choices**: Presenting competing events side-by-side with clear `[Deadline: 0]` indicators creates strong, immediate tension. The primary limitation is that players need upfront feedback on resource requirements before slotting to avoid feeling punished by trial-and-error.
- **Slot Instance Independence**: Duplicating event definitions when instantiating `EventUI` is critical. Shared dictionary references in prototype engines often cause subtle bugs where filling a slot in Event A accidentally fills the slot in Event B.
- **Time as a Resource vs. Turn Pressure**: The delayed gathering task clearly showed that turns feel meaningful only when accompanied by active deadlines. Advancing turns without active pressure feels like wasted clicks.
- **Scalability of Plain Inventory vs. Deck/Location Board**: As card counts grow beyond a simple scenario, a flat inventory UI can quickly clutter. Future iterations may benefit from grouping cards by location or active status.
