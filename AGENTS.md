# Backend Agent Guide

Follow the current API conventions in this file when adding or changing backend behavior.

## Commits

- Use Conventional Commits format for commit messages, such as `fix: ...`, `feat: ...`, or `chore: ...`.

## API Shape

- Responses are wrapped.
  - Success: `{ "status": "success", "data": ... }`
  - Success with metadata: `{ "status": "success", "data": ..., "meta": ... }`
  - Error: `{ "status": "error", "errors": { ... } }`
- Request bodies are not wrapped in `data`.
  - Prefer `{ "name": "Sour Cream", "unit": "g" }`
  - Do not add `{ "data": { ... } }` for request contracts.
- Query params stay top-level.
- Use stable HTTP statuses through `ApplicationController` helpers where possible:
  - `bad_request!(message)` for `400`, malformed request shape, or bad primitive input.
  - `unauthorized!` for `401` authentication failures.
  - `not_found!` for `404` missing scoped records.
  - `conflict!` for generic `409` conflicts; use `render_error(..., status: :conflict)` when the response needs field-specific conflict details.
  - `unprocessable_entity!(errors)` for `422`, valid request shape that fails domain validation.
  - Use `render_error(..., status: :precondition_required)` for `428` when an operation needs explicit acknowledgement before destructive impact.

## Controllers

- Controllers should inherit from `ApplicationController`.
- Do not subclass another concrete controller to share behavior. Copy or extract needed behavior into concerns, forms, or services.
- Controller helper methods should be private.
- Prefer explicit early returns for failure branches when it makes the action easier to read.
- Use `render_success` and `render_error` from `V2Rendering`; do not hand-roll v2 envelopes in actions.
- Use named invalidation helpers from `QueryInvalidation`, such as `invalidate_products!`, `invalidate_pantry!`, and `invalidate_groceries!`.

## Contracts

- Use `Dry::Validation::Contract` for request validation in controllers.
- Contracts define the request boundary. Forms/services should receive already-normalized values and should not re-parse booleans or duplicate contract coercion.
- Use `params do` unless there is a clear reason to require strict JSON-native scalar types.
- Boolean fields should be declared as `filled(:bool)` / `maybe(:bool)` in contracts. Do not add custom `truthy?` helpers.
- Keep contracts close to the controller until there is enough reuse or size pressure to justify extracting them.

## Forms And Services

- Forms own business orchestration for multi-model writes.
- Services own focused domain operations that are not naturally controller or model responsibilities.
- Keep ActiveRecord transactions around operations that must succeed or fail as one user action.
- PATCH should be partial. Preserve existing values for absent fields, and distinguish absent fields from explicit `nil` when that matters.

## Data Ownership

- Scope family-owned records through `@current_user.family`.
- Do not look up mutable user data globally unless the operation is intentionally cross-family.
- Products are the backbone for pantry, grocery, ingredients, suggestions, and consumption flows.
- Kitchen basics are visible/manageable in Items and suggestions, but hidden from pantry/shopping behavior.

## Tests

- Add focused tests for each controller/form/service behavior touched.
- For controller changes, test both the success envelope and important error shapes/statuses.
- Run focused tests for the touched slice before handing work back.
