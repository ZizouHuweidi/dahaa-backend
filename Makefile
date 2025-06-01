# Include environment variables
include .env
export

# Variables
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_USER ?= postgres
DB_PASSWORD ?= postgres
DB_NAME ?= dahaa
MIGRATIONS_ROOT ?= backend/migrations
NETWORK ?= dahaa_backend
CONNECTION_STRING ?= postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=disable

.PHONY: init help
.PHONY: migrate/up migrate/up/all migrate/down migrate/down/all migrate/force migration
.PHONY: build build/local run-backend run-frontend run
.PHONY: test test-race itest
.PHONY: docker-run docker-down
.PHONY: db/conn prune ps inspect prune-dangled-volumes
.PHONY: list update audit psql
.PHONY: up down build logs ps

# =====================================================================
# Initialization
# =====================================================================
## init: install required Go tools
init:
	@go install honnef.co/go/tools/cmd/staticcheck@latest
	@go install github.com/cosmtrek/air@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install github.com/go-delve/delve/cmd/dlv@latest
	@go install github.com/segmentio/golines@latest
	@go install mvdan.cc/gofumpt@latest
	@go install github.com/mfridman/tparse@latest

# =====================================================================
# Help
# =====================================================================
## help: print this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

# =====================================================================
# Migrations
# =====================================================================
## migrate/up n=<number>: migrates up n steps
migrate/up:
	docker run --rm -v $(MIGRATIONS_ROOT):/migrations --network $(NETWORK) migrate/migrate -path=/migrations/ -database $(CONNECTION_STRING) up $(n)

## migrate/up/all: migrates up to latest
migrate/up/all:
	docker run --rm -v $(MIGRATIONS_ROOT):/migrations --network $(NETWORK) migrate/migrate -path=/migrations/ -database $(CONNECTION_STRING) up

## migrate/down n=<number>: migrates down n steps
migrate/down:
	docker run --rm -v $(MIGRATIONS_ROOT):/migrations --network $(NETWORK) migrate/migrate -path=/migrations/ -database $(CONNECTION_STRING) down $(n)

## migrate/down/all: migrates down all steps
migrate/down/all:
	docker run --rm -v $(MIGRATIONS_ROOT):/migrations --network $(NETWORK) migrate/migrate -path=/migrations/ -database $(CONNECTION_STRING) down -all

## migration n=<file_name>: creates migration files up/down for file_name
migration:
	docker run --rm -v $(MIGRATIONS_ROOT):/migrations --network $(NETWORK) migrate/migrate -path=/migrations/ create -seq -ext=.sql -dir=./migrations $(n)

## migrate/force n=<version>: forces migration version number
migrate/force:
	docker run --rm -v $(MIGRATIONS_ROOT):/migrations --network $(NETWORK) migrate/migrate -path=/migrations/ -database=$(CONNECTION_STRING) force $(n)

# =====================================================================
# Build
# =====================================================================
## build: build the Go binary (backend)
build:
	@echo "Building Go backend..."
	@go build -o main cmd/api/main.go

## build/local: build with 'local' tags
build/local:
	@echo "Building with 'local' tags..."
	@go build -tags local -o main .

# =====================================================================
# Run
# =====================================================================
## run-backend: run backend with live reload
run-backend:
	@echo "Running backend (using air)..."
	@if command -v air > /dev/null; then \
		air; \
	else \
		read -p "Go's 'air' is not installed. Install it now? [Y/n] " choice; \
		if [ "$$choice" != "n" ] && [ "$$choice" != "N" ]; then \
			go install github.com/cosmtrek/air@latest; \
			air; \
		else \
			echo "air not installed. Exiting..."; exit 1; \
		fi; \
	fi

## run-frontend: run frontend development server
run-frontend:
	@echo "Running frontend..."
	@cd frontend && npm install --prefer-offline --no-fund
	@cd frontend && npm run dev

## run: run both backend and frontend concurrently
run:
	@$(MAKE) run-backend & \
	$(MAKE) run-frontend

# =====================================================================
# Testing
# =====================================================================
## test: run all tests
test:
	@echo "Running unit tests..."
	@go test ./... -v

## test-race: run tests with race detection
test-race:
	@echo "Running tests with race detection..."
	@go test -race ./... -v

## itest: run integration tests
itest:
	@echo "Running integration tests..."
	@go test ./internal/database -v

# =====================================================================
# Docker Operations
# =====================================================================
## docker-run: start all services
docker-run:
	@if docker compose up --build 2>/dev/null; then \
		: ; \
	else \
		echo "Falling back to Docker Compose V1"; \
		docker-compose up --build; \
	fi

## docker-down: stop all services
docker-down:
	@if docker compose down 2>/dev/null; then \
		: ; \
	else \
		echo "Falling back to Docker Compose V1"; \
		docker-compose down; \
	fi

# =====================================================================
# Database and Docker Utilities
# =====================================================================
## db/conn: connect to database
db/conn:
	psql $(CONNECTION_STRING)

## prune: clean up Docker system
prune:
	docker system prune -a -f --volumes

## prune-dangled-volumes: remove dangling volumes
prune-dangled-volumes:
	docker volume ls -q -f dangling=true | xargs -r docker volume rm

## ps: list running containers
ps:
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Size}}\t{{.Ports}}"

## inspect: inspect container IP
inspect:
	docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" $(n)

# =====================================================================
# Go Module Management
# =====================================================================
## list: list module dependencies
list:
	go list -m -u

## update: update module dependencies
update:
	go get -u ./...

# =====================================================================
# Quality Control
# =====================================================================
## audit: run all quality checks
audit:
	@echo 'Tidying and verifying module dependencies...'
	go mod tidy
	go mod verify
	@echo 'Formatting code...'
	gofumpt -l -w -extra .
	golines -w .
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...

# =====================================================================
# Database Access
# =====================================================================
## psql: connect to database via Docker
psql:
	docker run -it --rm --network ${NETWORK} postgres psql -U ${DB_USER}

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
clean: docker-down prune-dangled-volumes

# Start all services
up:
	docker compose up

# Stop all services
down:
	docker compose down

# Build services
build:
	docker compose build

# View logs
logs:
	docker compose logs -f

# List containers
ps:
	docker compose ps
