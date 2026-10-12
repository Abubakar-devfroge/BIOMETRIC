# Default recipe: list available commands
default:
  @just --list

# Start Postgres in Docker and boot Phoenix in IEx
dev:
  docker compose up -d
  iex -S mix phx.server

# Start the Docker database in the background
up:
  docker compose up -d

# Stop the Docker database
down:
  docker compose stop

# Jump straight into psql inside the Docker container
psql:
  docker compose exec -it db psql -U ip -d ip

# Stream database logs
logs:
  docker compose logs -f db

# Wipe, recreate, migrate, and seed the database
reset:
  mix ecto.drop
  mix ecto.create
  mix ecto.migrate
  mix run priv/repo/seeds.exs

# Run seeds only
seed:
  mix run priv/repo/seeds.exs

# Run tests with quiet db setup
test:
  mix test

# Code quality check
check:
  mix format --check-formatted
  mix compile --warnings-as-errors
