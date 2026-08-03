---
name: fastapi
description: "FastAPI service standard: lifespan context managers (not on_event), Pydantic v2 models (ConfigDict, field_validator), Annotated dependency injection, explicit response_model/status codes for OpenAPI, and RFC 9457 problem+json error handling. Triggered when building or reviewing FastAPI apps, routers, schemas, or dependencies. Reference alongside core skills backend-engineering, security-principles, and observability, plus clean-architecture-python."
---

# FastAPI

## Purpose

Defines how HTTP services are built with FastAPI so they are type-safe, self-documenting, and consistent with the company backend, security, and observability standards. Routers stay thin — they validate, delegate to the application/service layer, and serialize; business logic lives in services (see `clean-architecture-python`).

## When to Trigger

- Loaded as a domain skill when the project tech stack includes FastAPI.
- Triggered when building or reviewing FastAPI applications, routers, Pydantic schemas, or dependencies.

---

## 1. Application Lifespan

Use `contextlib.asynccontextmanager` for startup/shutdown. Do **not** use the deprecated `@app.on_event` handlers.

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    await pool.open()          # e.g. psycopg AsyncConnectionPool (see postgresql)
    yield
    await pool.close()

app = FastAPI(title="Campaign API", version="1.0.0", lifespan=lifespan)
```

---

## 2. Pydantic v2 Schemas

- Use Pydantic **v2**: `model_config = ConfigDict(...)` instead of nested `class Config`.
- Use `@field_validator` / `@model_validator` for validation, not v1 `@validator`.
- **Do not use `...` (ellipsis)** to mark required fields — simply omit the default.
- `ConfigDict(from_attributes=True)` for response models mapping from ORM/domain objects; `populate_by_name=True` when aliasing.

```python
from pydantic import BaseModel, ConfigDict, EmailStr, Field

class AccountRegistration(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    credit_limit: float = Field(gt=0.0)

class AccountResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    account_id: str
    username: str
    is_active: bool
```

---

## 3. Dependency Injection with `Annotated`

Declare dependencies with `Annotated[T, Depends(...)]`, not default-argument `Depends()`. This is reusable and type-checker friendly.

```python
from typing import Annotated
from fastapi import Depends, Header, HTTPException, status

async def get_current_principal(x_access_token: Annotated[str, Header()]) -> Principal:
    principal = verify_token(x_access_token)
    if principal is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="unauthorized")
    return principal

CurrentPrincipal = Annotated[Principal, Depends(get_current_principal)]
```

Inject services the same way so routers receive fully-constructed use cases (wired at the composition root).

---

## 4. Declarative Endpoints (OpenAPI quality)

Every endpoint declares an explicit `response_model` (or return annotation) and `status_code`. Authentication is required by default (see `security-principles` §4).

```python
@app.post("/v1/accounts", response_model=AccountResponse,
          status_code=status.HTTP_201_CREATED, summary="Register a trading account")
async def create_account(payload: AccountRegistration, principal: CurrentPrincipal,
                         service: AccountServiceDep) -> AccountResponse:
    return await service.create(payload)   # delegate; no business logic here
```

- Version paths under `/v1/...` (see `backend-engineering` §1).
- Validate at the boundary by schema; return only what the caller needs (output minimization).

---

## 5. Error Handling (RFC 9457)

- Map domain exceptions to `application/problem+json` responses via exception handlers, with `type`, `title`, `status`, `detail`, `instance`, plus `code` and `trace_id`.
- 4xx include recoverable detail; **5xx are generic to the client** (message + correlation id) but rich in logs/traces (see `backend-engineering` §2, `observability`).
- Services raise **domain** exceptions; the FastAPI layer is the only place that translates them to HTTP.

```python
from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(RecordNotFound)
async def handle_not_found(request: Request, exc: RecordNotFound) -> JSONResponse:
    return JSONResponse(status_code=404, media_type="application/problem+json",
        content={"type": "about:blank", "title": "Not Found", "status": 404,
                 "code": "record_not_found", "trace_id": current_trace_id()})
```

---

## 6. Anti-Patterns (review-blocking)

- `@app.on_event("startup"/"shutdown")` — use `lifespan`.
- Pydantic v1 patterns (`class Config`, `@validator`, `...` for required).
- Business logic, raw SQL, or DB sessions inside route handlers.
- Endpoints without `response_model`/return type — degrades OpenAPI and type safety.
- Raising framework `HTTPException` from the service layer.
- Endpoints unauthenticated by default without explicit review.

---

## References

- FastAPI — lifespan events: <https://fastapi.tiangolo.com/advanced/events/>.
- FastAPI — dependencies with `Annotated`: <https://fastapi.tiangolo.com/tutorial/dependencies/>.
- FastAPI — response model: <https://fastapi.tiangolo.com/tutorial/response-model/>.
- Pydantic v2 models & `ConfigDict`: <https://docs.pydantic.dev/latest/concepts/models/>.
- RFC 9457 — Problem Details: <https://www.rfc-editor.org/rfc/rfc9457>.
