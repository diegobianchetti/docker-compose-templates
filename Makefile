# =============================================================================
# Makefile — docker-compose-templates
# =============================================================================
# Atalhos para operações comuns em cada template.
#
# Uso:
#   make up        TEMPLATE=web-classic
#   make down      TEMPLATE=web-classic
#   make logs      TEMPLATE=web-classic
#   make ps        TEMPLATE=web-classic
#   make restart   TEMPLATE=web-classic SERVICE=nginx
#   make shell     TEMPLATE=web-classic SERVICE=app
#
# Templates disponíveis:
#   web-classic       — nginx + app + PostgreSQL
#   private-registry  — Docker Registry v2 + nginx
# =============================================================================

TEMPLATE        ?= web-classic
SERVICE         ?=
COMPOSE_FILE    := $(TEMPLATE)/docker-compose.yml
ENV_FILE        := $(TEMPLATE)/.env
COMPOSE         := docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

# Cores para output
BOLD  := \033[1m
RESET := \033[0m
GREEN := \033[32m
RED   := \033[31m

# Verifica se o template existe antes de qualquer operação
_check_template:
	@if [ ! -f "$(COMPOSE_FILE)" ]; then \
		echo "$(RED)Erro: template '$(TEMPLATE)' não encontrado ($(COMPOSE_FILE))$(RESET)"; \
		echo "Templates disponíveis: web-classic  private-registry"; \
		exit 1; \
	fi

# Verifica se o .env existe — cria a partir do .env.example se não existir
_check_env: _check_template
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "$(RED)Aviso: $(ENV_FILE) não encontrado.$(RESET)"; \
		echo "Criando a partir de $(TEMPLATE)/.env.example ..."; \
		cp $(TEMPLATE)/.env.example $(ENV_FILE); \
		echo "$(GREEN)Criado: $(ENV_FILE)$(RESET) — edite antes de continuar."; \
		exit 1; \
	fi

# -----------------------------------------------------------------------------
# Targets principais
# -----------------------------------------------------------------------------

.PHONY: up
up: _check_env  ## Sobe o ambiente em background
	@echo "$(BOLD)Subindo template: $(TEMPLATE)$(RESET)"
	$(COMPOSE) up -d --remove-orphans

.PHONY: down
down: _check_template  ## Para e remove os containers (mantém volumes)
	@echo "$(BOLD)Parando template: $(TEMPLATE)$(RESET)"
	$(COMPOSE) down

.PHONY: destroy
destroy: _check_template  ## Para e remove containers E volumes nomeados
	@echo "$(RED)ATENÇÃO: isso apaga os volumes de dados de $(TEMPLATE)$(RESET)"
	@read -p "Confirmar? [s/N] " confirm; \
	if [ "$$confirm" = "s" ] || [ "$$confirm" = "S" ]; then \
		$(COMPOSE) down -v; \
	else \
		echo "Cancelado."; \
	fi

.PHONY: restart
restart: _check_env  ## Reinicia um serviço específico (SERVICE=nome) ou todos
	@if [ -n "$(SERVICE)" ]; then \
		echo "$(BOLD)Reiniciando: $(SERVICE)$(RESET)"; \
		$(COMPOSE) restart $(SERVICE); \
	else \
		echo "$(BOLD)Reiniciando todos os serviços$(RESET)"; \
		$(COMPOSE) restart; \
	fi

.PHONY: logs
logs: _check_template  ## Exibe logs em tempo real (SERVICE=nome para filtrar)
	$(COMPOSE) logs -f --tail=100 $(SERVICE)

.PHONY: ps
ps: _check_template  ## Lista containers e status de health
	$(COMPOSE) ps

.PHONY: pull
pull: _check_env  ## Faz pull das imagens sem subir os serviços
	$(COMPOSE) pull

.PHONY: shell
shell: _check_template  ## Abre shell em um serviço (SERVICE=nome obrigatório)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Erro: informe o serviço. Exemplo: make shell SERVICE=app$(RESET)"; \
		exit 1; \
	fi
	$(COMPOSE) exec $(SERVICE) sh

.PHONY: config
config: _check_env  ## Exibe o compose resolvido (com variáveis substituídas)
	$(COMPOSE) config

.PHONY: top
top: _check_template  ## Exibe processos rodando dentro dos containers
	$(COMPOSE) top

# -----------------------------------------------------------------------------
# Targets de informação
# -----------------------------------------------------------------------------

.PHONY: help
help:  ## Exibe esta ajuda
	@echo ""
	@echo "$(BOLD)docker-compose-templates — comandos disponíveis$(RESET)"
	@echo ""
	@echo "  $(BOLD)TEMPLATE$(RESET) (padrão: web-classic)"
	@echo "    web-classic       nginx + app + PostgreSQL"
	@echo "    private-registry  Docker Registry v2 + nginx"
	@echo ""
	@echo "  $(BOLD)Exemplos:$(RESET)"
	@echo "    make up                              # sobe web-classic"
	@echo "    make up        TEMPLATE=private-registry"
	@echo "    make logs      TEMPLATE=web-classic  SERVICE=nginx"
	@echo "    make shell     TEMPLATE=web-classic  SERVICE=app"
	@echo "    make restart   TEMPLATE=web-classic  SERVICE=db"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  $(BOLD)%-12s$(RESET) %s\n", $$1, $$2}'
	@echo ""

.DEFAULT_GOAL := help
