## 2024-05-18 - Missing Tooltips on IconButtons
**Learning:** Found multiple instances where Flutter's `IconButton` widgets were used without the `tooltip` property, specifically for actions like toggling password visibility or clearing search fields. This can cause accessibility issues for screen readers.
**Action:** Added `tooltip` properties to all icon-only buttons to improve accessibility.
