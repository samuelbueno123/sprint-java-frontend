## 2024-05-18 - Missing Tooltips on IconButtons
**Learning:** Found multiple instances where Flutter's `IconButton` widgets were used without the `tooltip` property, specifically for actions like toggling password visibility or clearing search fields. This can cause accessibility issues for screen readers.
**Action:** Added `tooltip` properties to all icon-only buttons to improve accessibility.
## 2026-10-26 - Added Autofill Hints to Signup Pages
**Learning:** Password managers and OS autofill services provide a significant UX boost, but they require explicit hints (`autofillHints`) on Flutter's `TextFormField`s to work correctly.
**Action:** Ensure all authentication and profile forms include relevant `AutofillHints` to reduce user friction.

## 2026-10-28 - Missing Tooltips on IconButtons
**Learning:** Found multiple instances where Flutter's `IconButton` widgets were used without the `tooltip` property, specifically for actions like closing dialogs or clearing search fields. This can cause accessibility issues for screen readers.
**Action:** Always verify if an `IconButton` widget has a descriptive `tooltip` attached if it does not have a text label beside it.

## 2024-05-18 - Missing Tooltips on IconButtons
**Learning:** Found multiple instances where Flutter's `IconButton` widgets were used without the `tooltip` property, specifically for actions like closing dialogs or clearing search fields. This can cause accessibility issues for screen readers.
**Action:** Always verify if an `IconButton` widget has a descriptive `tooltip` attached if it does not have a text label beside it.
## 2026-10-30 - Added Autofill Hints to Edit Profile Dialogs
**Learning:** Password managers and OS autofill services provide a significant UX boost, but they require explicit hints (`autofillHints`) on Flutter's `TextField`s to work correctly. The edit profile dialogs were lacking these hints, causing a slight friction when users need to confirm their passwords to delete their account, or update email.
**Action:** Ensure all profile updating and account managing forms include relevant `AutofillHints` to reduce user friction.
