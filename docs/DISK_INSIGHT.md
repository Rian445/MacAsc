# 📊 Disk Insight & Drive Storage User Manual

Welcome to the **Disk Insight & Drive Storage** user guide for Mac ASC. This module provides a real-time, categorized breakdown of your Mac's internal storage, external volume monitoring, and custom folder size tracking.

---

## 📸 Visual Overview

<p align="center">
  <img src="../Screenshots/disk_insight_overview.png" width="480" alt="Disk Insight Overview"/>
</p>

---

## 🔍 Key Capabilities

1. **Categorized Storage Breakdown**:
   - Visualizes disk space distribution into balanced categories:
     - 🔵 **Applications**: Installed macOS software packages.
     - 🟣 **Developer Files**: Xcode caches, Swift build directories (`.build`), package managers, and node modules.
     - 🟠 **Documents**: User documents, text files, and PDFs.
     - 🟢 **Media Files**: Images, audio tracks, and video files.
     - ⚪ **System & Other**: macOS system runtime, OS snapshots, and uncategorized files.
     - 🔘 **Free Space**: Remaining available capacity on your drive.

2. **Multi-Drive & External Storage Monitor**:
   - Automatically detects external USB drives, SD cards, and Thunderbolt disks.
   - Displays volume names, used space, free space, and mount paths.
   - Provides a single-click **Eject Volume** (`eject.fill`) button to safely unmount external disks without Finder warnings.

3. **Pinned Folder Size Tracker**:
   - Allows you to pin any folder on your Mac to the dashboard.
   - Measures folder size asynchronously in the background so your UI never freezes.
   - Includes a **Finder Icon Button** (`folder.fill`) to open pinned directories instantly.

4. **Antigravity AI Quota Usage Monitor**:
   - Automatically monitors remaining AI usage limits when Google Antigravity CLI (`agy`) is installed.
   - **Exact 2-Decimal Precision**: Parses `agy --output-format json -p /usage` to display real-time fractional percentages (e.g., `99.83%`, `99.10%`) instead of rounded integers.
   - **Symmetrical 1-Line Circular Design**: Compact circular rings (`CircularQuotaRing`) show consumption visually alongside Weekly (`Wk`) and 5-Hour (`5h`) limit gauges.
   - **Reset Countdown Timers**: Displays remaining time until quota replenishment (e.g., `⏱ in 78h 5m`, `⏱ in 3h 54m`, or `✓ Available`).
   - **Dedicated Independent Refresh (`↻`)**: Click the refresh button beside the Antigravity Quota header to refresh only the quota instantly without triggering an extensive disk rescan.

<p align="center">
  <img src="../Screenshots/external_and_pinned_drives.png" width="480" alt="External Storage and Pinned Folders"/>
</p>

---

## 🛠️ Step-by-Step Usage & Examples

### Example 1: Locating Large Applications
1. Open the Mac ASC dropdown from your menu bar.
2. Ensure you are on the **Disk Insight** tab (`⌘1`).
3. Scroll down to the **Applications** list.
4. Top installed applications are sorted by size. Click any application row to immediately highlight it in macOS Finder (`/Applications`).

### Example 2: Monitoring & Ejecting External USB Disks
1. Plug an external USB flash drive or hard drive into your Mac.
2. Mac ASC automatically detects the disk under the **External Storage** section.
3. View available capacity and storage usage.
4. When done, click the **Eject** button (`eject.fill`) on the right side of the drive row. Mac ASC safely unmounts the disk cleanly.

### Example 3: Pinning a Project Folder (e.g. `~/Developer/MyProject`)
1. In the **Pinned Folders** section, click the `+` button.
2. Select any folder from the native macOS file picker (e.g., your project directory or downloads folder).
3. The folder will appear on your dashboard with its calculated size updated asynchronously in the background.
4. Click the folder icon anytime to open it directly in Finder.

### Example 4: Checking & Refreshing Antigravity Quota
1. On the **Disk Insight** tab (`⌘1`), locate the **Antigravity Quota** section directly above Pinned Folders.
2. View your exact quota remaining for **Gemini** and **Claude + GPT** across Weekly and 5-Hour limits, complete with live reset countdowns.
3. If you recently prompted an AI model and want updated numbers immediately, click the `↻` icon beside **Antigravity Quota**. It queries `agy` directly without rescanning your local storage or applications.

---

## 💡 Performance & Privacy Guarantee
- Disk scans use native macOS file system APIs (`FileManager`).
- Quota queries run on-demand via local CLI subprocess without background daemons or idle CPU/GPU consumption.
- All calculations occur 100% locally on your machine with **zero network requests**.
