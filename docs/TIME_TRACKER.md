# ⏳ Time Tracker & Event Countdowns User Manual

Welcome to the **Time Tracker & Event Countdowns** user guide for Mac ASC. This module allows you to track custom countdowns for future milestones as well as elapsed time for past events, directly from your macOS menu bar.

---

## 🔍 Key Capabilities

1. **Future Countdowns & Past Milestones**:
   - Create custom event timers with titles (e.g. *Product Launch*, *Vacation*, *New Year*) and target dates/times using a native macOS date picker.

2. **Auto-Phrased Time Readouts**:
   - **Future Event**: Displays `[Event Title] coming in` with a cyan `COMING IN` badge and live countdown (`X days Y hrs Z mins S secs`).
   - **Past Event**: Displays `[Event Title] passed for` with an orange `PASSED FOR` badge and elapsed readout (`X yrs Y days Z mins S secs`).

3. **Seamless Future ➔ Past Transition**:
   - When a countdown passes its target date, it automatically switches its badge to `PASSED FOR` and begins counting up without stopping or freezing at zero.

4. **Zero-Resource Idle Protection**:
   - The 1-second UI ticker runs **strictly while the dropdown window is open and the Time Tracker tab is selected**.
   - Closing the window or switching tabs instantly destroys the timer, guaranteeing **0% idle CPU and 0 MB RAM overhead**.

5. **Full Backup Integration**:
   - All events (`SavedTimeEvents`) and tweak toggles (`TweakTimeTracker`) are included in your exported JSON settings backups.

---

## 🛠️ Usage Examples

### Creating a New Event
1. Open Mac ASC ➔ navigate to **Time Tracker** (Tab 5 or press `⌘6`).
2. Click **+ New Event**.
3. Enter an event title and pick a target date/time.
4. Click **Create Timer**.

### Editing or Deleting an Event
- Click the **Pencil icon** (`✏️`) on any event card to edit its title or target date.
- Click the **Trash icon** (`🗑️`) to delete an event.
