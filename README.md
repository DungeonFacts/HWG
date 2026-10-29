# Hedge Wizard — Game-Design Exploration Lab

An experimental Godot 4 prototype written in GDScript for **Hedge Wizard**, testing several distinct mechanics to discover what creates compelling wizard gameplay and meaningful player decisions.

---

## 1. Running the Exploration Lab

### Prerequisites
- Godot Engine 4.x (4.2+ / 4.4+ recommended).

### How to Play in Godot Editor
1. Open Godot Engine.
2. Import the project root directory.
3. Launch the project (press `F5` or click Play).
4. Use the **Experiment Selector** dropdown in the top bar to switch between scenarios at any time:
   - **`Exp 1: Scarcity & Competing Uses`**
   - **`Exp 2: Neglect & Evolving World`**
   - **`Exp 3: Multiple Paths to Power`**
   - **`Legacy Prototype Loop`**

### Running Automated Integration Tests (Headless)
If Godot Engine is installed on your system PATH:
```bash
# Test Experiment 1: Scarcity
godot --headless -s res://tests/test_experiment1.gd

# Test Experiment 2: Neglect & Evolving World
godot --headless -s res://tests/test_experiment2.gd

# Test Experiment 3: Multiple Paths to Power
godot --headless -s res://tests/test_experiment3.gd

# Test Legacy Integration Loop
godot --headless -s res://tests/test_scenario.gd
```

---

## 2. Design Experiments & Hypotheses

### Experiment 1: Scarcity and Competing Uses
- **Design Hypothesis**: Severe resource scarcity with multiple competing, mutually exclusive uses creates genuine strategic tension without relying on artificial countdown timers.
- **Scenario Instructions**:
  - You possess **1 rare Yew Heartwood**, 1 Silver Shilling, 1 Herbal Infusion, and 1 Ancient Scroll.
  - Three major ambitions immediately compete for the Yew Heartwood:
    1. *Craft Yew-Heart Wand*: Unlocks supreme arcane mastery.
    2. *Trade for Winter Provisions*: Secures abundant food stockpiles for the village.
    3. *Heart-Oak Spirit Shrine*: Offer wood to gain divine spirit favor.
  - Committing the Yew Heartwood to one ambition permanently locks it out for the others. You can use alternative secondary resources (Silver + Herb or Ancient Scroll) to achieve partial/compromised solutions for the other events.
  - Conclude by using your resulting item to ward off the Valley Shadow Storm.
- **Mechanics Creating Tension**: Mutually exclusive resource locking. Because there is strictly 1 Yew Heartwood, the opportunity cost of every action is explicit and immediate.
- **Design Assessment**:
  - *Strongest Aspect*: Clear, high-impact choice. The player immediately understands what was gained and what was permanently sacrificed.
  - *Weakest Aspect*: Once the single rare resource is spent, the remaining choices become trivial unless new scarce resources are continuously introduced.

---

### Experiment 2: Neglect and an Evolving World
- **Design Hypothesis**: Graduated, contextual consequences of neglect (escalating costs, accumulating grievances, shifting merchant inventory) generate organic pressure that feels more narrative and compelling than binary countdown clocks.
- **Scenario Instructions**:
  - Your goal is to complete a 3-turn long-term project: **Crafting the Yew-Heart Wand** (requires 1 Wizard work action per turn).
  - Meanwhile, three world events evolve every time you advance time or work on your wand:
    1. *Crop Blight*: Mild Blight (1 Herb) -> Severe Blight (1 Herb + Wizard) -> Famine & Crop Rot (Ruined trust & Villager Grievance cards).
    2. *Blacksmith Request*: Anomaly help request -> if neglected, Blacksmith damages his forge and holds a resentment grievance.
    3. *Wandering Merchant*: Rare Sun-Gem (1 Silver) -> if neglected, bought by a rival wizard, leaving only cheap Scrap Metal.
  - Evaluate "Rational Neglect": Decide which problems are cheap to ignore, which escalate dangerously, and when to accept minor grievances to complete your ambition.
- **Mechanics Creating Tension**: Dynamic world pressure engine. Neglecting an obligation changes its state, increasing costs or altering outcomes rather than causing it to vanish.
- **Design Assessment**:
  - *Strongest Aspect*: Feels like a real living world where the player's inaction has visible, narrative consequences. Allows strategic "rational neglect."
  - *Weakest Aspect*: Requires careful tuning so escalation doesn't spiral into inescapable failure states or feel overly punishing to first-time players.

---

### Experiment 3: Multiple Paths to Power
- **Design Hypothesis**: The process and method chosen to acquire power (costs, immediate risks, delayed constraints) define the wizard's identity and create richer decision spaces than simply possessing the power.
- **Scenario Instructions**:
  - Goal: Acquire **Yew Heartwood** to face the concluding **Archmage Trial**.
  - Four fundamentally distinct acquisition methods are available simultaneously:
    1. *Patient Stewardship (3 turns)*: Pure, risk-free, harmony. Yields `Consecrated Yew`.
    2. *Bargain with Sylph Spirit (1 turn + Herbal Offering)*: Yields Yew Heartwood but imposes a `Spirit Vow (Taboo)` constraint card.
    3. *Hire Local Forester (1 turn + Silver Shilling)*: Fast mortal assistance, but leaves a `Forester's Debt` card.
    4. *Forbidden Blight Ritual (0 turns / Instant)*: Rips life from soil. Instant acquisition, but corrupts the land (`Blighted Soil`).
  - Face the Archmage Trial: Resolving the trial inspects your path constraint card and grants a unique Wizard Title (*Patient Scholar*, *Bound Mystic*, *Mortal Patron*, or *Dread Sorcerer*).
- **Mechanics Creating Tension**: Path-dependent identity cards and delayed constraints. The choice is not just "how fast do I get X?", but "what kind of wizard do I become by getting X?".
- **Design Assessment**:
  - *Strongest Aspect*: High replayability and roleplaying resonance. Players feel true agency in shaping their character's wizardly archetype.
  - *Weakest Aspect*: Requires meaningful late-game payoffs for each path constraint card so that taboos/debts feel like active gameplay boundaries rather than just cosmetic labels.

---

## 3. Core Architecture & UI Code

- **`scenes/main.tscn`**: Integrated layout containing TopBar experiment selector, experiment objective/hypothesis banner, card inventory panel, active events panel, and RichText log console.
- **`scripts/main.gd`**: Central controller orchestrating scenario switching (`switch_experiment`), event instantiation, state trackers (wand progress, world escalation, path constraints), and event resolution callbacks.
- **`scripts/card_ui.gd` & `scripts/slot_ui.gd` & `scripts/event_ui.gd`**: Reusable component architecture supporting click-to-slot and drag-and-drop interactions.
