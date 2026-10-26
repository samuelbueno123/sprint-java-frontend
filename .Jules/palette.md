## 2026-10-26 - Icon-Only Buttons Missing Tooltips
**Learning:** Found a common accessibility pattern in this app where `IconButton` widgets used for closing dialogs lacked tooltips, making them inaccessible to screen readers and less intuitive for mouse users.
**Action:** Always verify `IconButton` usage, especially for simple actions like "close", and add localized `tooltip` properties (e.g., `tooltip: 'Fechar'`) to improve accessibility and UX.
