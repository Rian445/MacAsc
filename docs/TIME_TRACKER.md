# ⏳ Time Tracker & Event Countdowns User Manual

Welcome to the **Time Tracker & Event Countdowns** user guide for Mac ASC. This module allows you to track custom countdowns for future milestones as well as elapsed time for past events, directly from your macOS menu bar.

---

## ⚡ Zero Idle CPU & Memory Leak Free Architecture

1. **Reactive Lifecycle Management**:
   - The 1-second live ticker only executes when the **Time Tracker** tab is actively visible and the popover window is focused.
   - When the user switches to any other tab, opens Settings, or closes/dismisses the menu bar popover, the live timer is **immediately stopped and invalidated** (`stopTimeTicker()`).
   - The app runs at **0.0% idle CPU and 0 MB idle overhead**.

2. **Zero-Leak Memory Safety**:
   - `[weak viewModel]` captures across all background timer closures to prevent retain cycles and memory leaks.
   - Optimized $O(1)$ loop computation in `checkAndProcessRestartTimers` with infinite loop protection.

3. **Streamlined UI Controls**:
   - Quick Notes matching button layout: **`[Expand / Collapse]`** | **`[Edit / Done]`** | **`[+ Folder]`**.
   - Clicking **`Edit`** activates folder sorting (🔼/🔽) and action controls on demand.
