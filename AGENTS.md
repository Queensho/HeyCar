# CepQontag agent instructions

## Design skill
- For UX/UI design, redesign, restyling or review, read `.agents/skills/design-taste-frontend/SKILL.md` before changing UI.
- This skill is upstream Taste Skill v2 by Leonxlnx (MIT). Its web-specific recommendations (GSAP, browser animations, CSS) are not Flutter requirements. Translate the visual principles to native Flutter widgets and animations; do not introduce a web framework.
- Existing CepQontag screens and user-supplied reference screenshots take priority over generic art direction. When asked to match a screenshot, prioritize accurate reproduction over creative variation.

## CepQontag brand
- Primary purple: `#651FFF`; deep purple: `#4912C8`; light purple: `#F3EDFF`; lime: `#B9FF45`.
- Main text: `#10152D`; secondary text: `#778096`; page backgrounds typically `#F8F9FC` or white.
- Keep typography readable, layouts compact and responsive, cards consistently sized, accessible contrast, sensible safe areas and touch targets.
- Preserve existing navigation, state management, API contracts, QR calling, Firebase notifications, Android and PWA behavior. Avoid changing backend behavior for a visual request.
- Do not invent logos or replace the provided brand assets.

## Workflow
1. Inspect the actual widget and surrounding design tokens before editing.
2. Record the current behavior and any user-provided reference measurements.
3. Make the smallest scoped UI change that achieves the requested visual outcome.
4. Check Flutter formatting/analyzer and relevant tests when available. Verify Android and PWA behavior where practical.
5. Report clearly what was implemented, what was tested, and what still needs a device/build verification.

Source: https://github.com/Leonxlnx/taste-skill
