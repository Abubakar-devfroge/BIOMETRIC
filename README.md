# Once — Biometric Attendance System

Real-time biometric attendance tracking and payroll-ready reporting, built with Elixir and Phoenix LiveView.

![Once — landing page](docs/screenshots/landing.png)

## What it does

- **⏱ Live attendance from biometric devices** — a background sync worker pulls punches from connected devices into Postgres
- **📊 Real-time dashboard** — LiveView-driven presence tracking, per-employee drill-down and absent counts
- **📄 Payroll-ready reports** — report aggregation and absent counting are pushed into SQL (`NOT IN`, select trimming), not filtered in memory
- **🏢 Multi-tenant** — data isolated per client organization

## Live demo

→ [https://biometric.fly.dev/](https://biometric.fly.dev/)

Access is provisioned per organization — **request credentials at info.devforge@gmail.com**.

## Stack

Elixir · Phoenix LiveView · PostgreSQL · Tailwind CSS · Fly.io · Docker

## Run locally

```sh
mise install
just dev   # or: docker compose up
```

Then visit [http://localhost:4000](http://localhost:4000).

## Engineering notes

- Report queries derived in SQL rather than the app layer — `NOT IN`-based absent counting and trimmed report selects keep views fast
- Composite index on `punch_time` to keep the punch-heavy table performant
- LiveView idle reconnects on Fly.io fixed by keeping one warm machine running
