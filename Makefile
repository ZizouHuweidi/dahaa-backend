# Include environment variables
include .env
export

# Variables
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_USER ?= postgres
DB_PASSWORD ?= postgres
DB_NAME ?= dahaa
MIGRATIONS_ROOT ?= $(shell pwd)/migrations
CONNECTION_STRING ?= postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=disable

# Go related variables
GOBASE=$(shell pwd)
GOBIN=$(GOBASE)/bin

.PHONY: init help
.PHONY: migrate/up migrate/up/all migrate/down migrate/down/all migrate/force migration
.PHONY: build run
.PHONY: test test-race
.PHONY: docker-run docker-down
.PHONY: db/conn prune ps
.PHONY: setup clean

# =====================================================================
# Initialization
# =====================================================================
## init: install required Go tools
init:
	@echo "Installing required Go tools..."
	@go install github.com/air-verse/air@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install github.com/go-delve/delve/cmd/dlv@latest
	@go install mvdan.cc/gofumpt@latest

# =====================================================================
# Help
# =====================================================================
## help: print this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

# =====================================================================
# Development
# =====================================================================
## build: build the Go binary
build:
	@echo "Building Go binary..."
	@go build -o $(GOBIN)/server cmd/api/main.go

## run: run with hot reload
run:
	@echo "Starting development server..."
	@which air >/dev/null 2>&1 || go install github.com/air-verse/air@latest
	@air

# =====================================================================
# Testing
# =====================================================================
## test: run all tests
test:
	@echo "Running tests..."
	@go test -v -race -coverprofile=coverage.out ./...

## test-race: run tests with race detection
test-race:
	@echo "Running tests with race detection..."
	@go test -race -v ./...

# =====================================================================
# Docker Operations
# =====================================================================
## docker-run: start all services
docker-run:
	@echo "Starting Docker services..."
	@docker compose up --build

## docker-down: stop all services
docker-down:
	@echo "Stopping Docker services..."
	@docker compose down

# =====================================================================
# Database Operations
# =====================================================================
## migrate/up n=<number>: migrates up n steps
migrate/up:
	@echo "Running migration up $(n) steps..."
	@test -d $(MIGRATIONS_ROOT) || (echo "Migrations directory not found at $(MIGRATIONS_ROOT)" && exit 1)
	@echo "Using migrations from: $(MIGRATIONS_ROOT)"
	@migrate -path $(MIGRATIONS_ROOT) -database "$(CONNECTION_STRING)" up $(n)

## migrate/up/all: migrates up to latest
migrate/up/all:
	@echo "Running all migrations up..."
	@test -d $(MIGRATIONS_ROOT) || (echo "Migrations directory not found at $(MIGRATIONS_ROOT)" && exit 1)
	@echo "Using migrations from: $(MIGRATIONS_ROOT)"
	@migrate -path $(MIGRATIONS_ROOT) -database "$(CONNECTION_STRING)" up

## migrate/down n=<number>: migrates down n steps
migrate/down:
	@echo "Running migration down $(n) steps..."
	@test -d $(MIGRATIONS_ROOT) || (echo "Migrations directory not found at $(MIGRATIONS_ROOT)" && exit 1)
	@echo "Using migrations from: $(MIGRATIONS_ROOT)"
	@migrate -path $(MIGRATIONS_ROOT) -database "$(CONNECTION_STRING)" down $(n)

## migrate/down/all: migrates down all steps
migrate/down/all:
	@echo "Running all migrations down..."
	@test -d $(MIGRATIONS_ROOT) || (echo "Migrations directory not found at $(MIGRATIONS_ROOT)" && exit 1)
	@echo "Using migrations from: $(MIGRATIONS_ROOT)"
	@migrate -path $(MIGRATIONS_ROOT) -database "$(CONNECTION_STRING)" down -all

## migration n=<file_name>: creates migration files up/down for file_name
migration:
	@echo "Creating migration files for $(n)..."
	@test -d $(MIGRATIONS_ROOT) || (echo "Migrations directory not found at $(MIGRATIONS_ROOT)" && exit 1)
	@echo "Using migrations from: $(MIGRATIONS_ROOT)"
	@migrate create -seq -ext=.sql -dir $(MIGRATIONS_ROOT) $(n)

## migrate/force n=<version>: forces migration version number
migrate/force:
	@echo "Forcing migration version to $(n)..."
	@test -d $(MIGRATIONS_ROOT) || (echo "Migrations directory not found at $(MIGRATIONS_ROOT)" && exit 1)
	@echo "Using migrations from: $(MIGRATIONS_ROOT)"
	@migrate -path $(MIGRATIONS_ROOT) -database "$(CONNECTION_STRING)" force $(n)

## db/conn: connect to database
db/conn:
	@echo "Connecting to database..."
	@psql $(CONNECTION_STRING)

# =====================================================================
# Docker Utilities
# =====================================================================
## prune: clean up Docker system
prune:
	@echo "Cleaning up Docker system..."
	@docker system prune -a -f --volumes

## ps: list running containers
ps:
	@echo "Listing running containers..."
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Size}}\t{{.Ports}}"

# =====================================================================
# Setup and Cleanup
# =====================================================================
## setup: initial project setup
setup: init
	@echo "Setting up project..."
	@make docker-run
	@sleep 5  # Wait for services to be ready
	@make migrate/up/all

## clean: clean up project
clean: docker-down
	@echo "Cleaning up project..."
	@rm -rf $(GOBIN)/*
	@go clean -testcache
