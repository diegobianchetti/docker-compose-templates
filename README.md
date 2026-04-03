# docker-compose-templates

Templates prontos e comentados de ambientes multi-serviço com Docker Compose,
com foco em boas práticas de produção.

Cada template é independente — use apenas o que precisar.

---

## Templates disponíveis

| Template | Serviços | Descrição |
|---|---|---|
| [`web-classic/`](web-classic/) | nginx + app + PostgreSQL | Stack web com proxy reverso, aplicação e banco de dados |
| [`private-registry/`](private-registry/) | Registry v2 + nginx | Registry Docker privado com autenticação básica e TLS |

---

## Pré-requisitos

- Docker Engine 24+
- Docker Compose v2 (`docker compose`, não `docker-compose`)
- `make` (opcional, mas recomendado)

---

## Uso rápido

```bash
# Clone o repositório
git clone https://github.com/diegobianchetti/docker-compose-templates.git
cd docker-compose-templates

# Escolha um template e configure o .env
cp web-classic/.env.example web-classic/.env
vi web-classic/.env

# Suba o ambiente
make up TEMPLATE=web-classic

# Verifique o status
make ps TEMPLATE=web-classic

# Acompanhe os logs
make logs TEMPLATE=web-classic

# Pare tudo
make down TEMPLATE=web-classic
```

Sem `make`:

```bash
cd web-classic
cp .env.example .env && vi .env
docker compose up -d
docker compose ps
docker compose logs -f
```

---

## Makefile — referência de comandos

| Comando | Descrição |
|---|---|
| `make up TEMPLATE=nome` | Sobe o ambiente em background |
| `make down TEMPLATE=nome` | Para e remove containers (mantém volumes) |
| `make destroy TEMPLATE=nome` | Para, remove containers **e volumes** (dados apagados) |
| `make logs TEMPLATE=nome` | Logs em tempo real |
| `make logs TEMPLATE=nome SERVICE=nginx` | Logs de um serviço específico |
| `make ps TEMPLATE=nome` | Lista containers e status de health |
| `make shell TEMPLATE=nome SERVICE=app` | Shell interativo no container |
| `make restart TEMPLATE=nome SERVICE=db` | Reinicia um serviço |
| `make pull TEMPLATE=nome` | Faz pull das imagens sem subir |
| `make config TEMPLATE=nome` | Exibe o compose com variáveis resolvidas |
| `make help` | Exibe ajuda completa |

---

## Estrutura dos arquivos

```
docker-compose-templates/
├── Makefile                          # Comandos utilitários
├── .gitignore
│
├── web-classic/
│   ├── docker-compose.yml            # Stack principal (nginx + app + db)
│   ├── .env.example                  # Variáveis documentadas
│   ├── nginx/
│   │   ├── nginx.conf                # Configuração base do nginx
│   │   └── conf.d/
│   │       └── app.conf              # Server block da aplicação
│   └── db/
│       └── init/
│           └── 01-schema.sql         # DDL inicial (executado no primeiro start)
│
└── private-registry/
    ├── docker-compose.yml            # Registry v2 + nginx
    ├── .env.example
    ├── auth/                         # htpasswd gerado localmente (não commitado)
    └── nginx/
        ├── nginx.conf
        └── conf.d/
            └── registry.conf         # Proxy + autenticação para o registry
```

---

## Configuração dos templates

### web-classic

1. Configure o `.env`:

```bash
cp web-classic/.env.example web-classic/.env
```

Variáveis obrigatórias a alterar:

```bash
COMPOSE_PROJECT_NAME=webapp          # prefixo para containers/volumes/redes
POSTGRES_USER=appuser
POSTGRES_PASSWORD=senha_forte_aqui
POSTGRES_DB=appdb
APP_SECRET_KEY=chave_aleatoria_32bytes  # openssl rand -hex 32
```

2. Adicione os certificados TLS:

```bash
# Com Let's Encrypt (certbot já configurado no host):
TLS_CERT_DIR=/etc/letsencrypt/live/app.example.br
```

3. Adapte o `nginx/conf.d/app.conf` com o domínio real.

4. Substitua a imagem fictícia em `docker-compose.yml`:

```yaml
image: your-registry.example.br/nome-app:1.4.2
# → sua imagem real com tag semântica
```

---

### private-registry

1. Configure o `.env`:

```bash
cp private-registry/.env.example private-registry/.env
```

2. Gere o arquivo `htpasswd` com bcrypt:

```bash
# Cria o diretório auth (se ainda não existir)
mkdir -p private-registry/auth

# Gera o htpasswd usando a imagem httpd (sem instalar apache2-utils)
docker run --rm httpd:2.4-alpine \
  htpasswd -Bbn meususuario minhasenha \
  > private-registry/auth/htpasswd

# Para adicionar mais usuários (sem sobrescrever):
docker run --rm httpd:2.4-alpine \
  htpasswd -Bbn outrousuario outrasenha \
  >> private-registry/auth/htpasswd
```

3. Adicione os certificados TLS e adapte o `nginx/conf.d/registry.conf`.

4. Suba e teste:

```bash
make up TEMPLATE=private-registry
docker login registry.example.br
docker pull nginx:1.27-alpine
docker tag nginx:1.27-alpine registry.example.br/nginx:1.27-alpine
docker push registry.example.br/nginx:1.27-alpine
```

---

## Decisões técnicas

### Por que `depends_on` com `condition: service_healthy` e não apenas `depends_on` simples?

O `depends_on` simples garante apenas que o container foi *iniciado* — não que o serviço dentro dele está pronto para receber conexões. Um banco PostgreSQL, por exemplo, passa por estágios de inicialização (recovering WAL, applying checkpoint) antes de aceitar queries. Com `depends_on` simples, a aplicação tenta conectar enquanto o banco ainda está inicializando e falha.

Com `condition: service_healthy`, o Docker Compose aguarda o healthcheck retornar `healthy` antes de iniciar o serviço dependente. Isso elimina a necessidade de lógica de retry na aplicação para o caso de boot concorrente e torna o comportamento determinístico.

O custo é configurar healthchecks em todos os serviços — o que é uma boa prática de qualquer forma, pois o `docker compose ps` passa a mostrar o estado real de saúde de cada serviço.

---

### Por que nunca usar a tag `latest` em produção?

A tag `latest` é um alias mutável: `docker pull nginx:latest` hoje pode trazer a versão 1.26 e amanhã a 1.27, com mudanças de comportamento silenciosas. Isso quebra a reprodutibilidade dos deployments.

Problemas concretos causados pelo `latest`:

- **Rollback impossível**: se `latest` avançou, você não consegue garantir que vai voltar para a imagem anterior.
- **Builds não reproduzíveis**: dois hosts que fazem pull em momentos diferentes podem ter versões diferentes rodando.
- **Debugging difícil**: logs de erros sem versão identificável dificultam abertura de issues e busca de CVEs.
- **Surpresas em patches de segurança**: uma atualização de segurança pode incluir mudanças de comportamento que quebram a aplicação.

A convenção usada neste repositório é `imagem:MAJOR.MINOR.PATCH` (ou `MAJOR.MINOR-variant` quando o patch não é exposto pela imagem upstream, como `nginx:1.27-alpine`).

---

### Por que redes dedicadas por stack?

Por padrão, todos os serviços de um mesmo `docker-compose.yml` entram na mesma rede e podem se comunicar entre si diretamente. Isso é conveniente em desenvolvimento, mas problemático em produção:

- **nginx alcançando o banco diretamente** por engano de configuração.
- **Containers de debug** temporários conectados a todas as redes da stack.
- **Nomes de serviço colidindo** entre projetos diferentes no mesmo host.

Com redes separadas por responsabilidade (`frontend` para nginx↔app, `backend` para app↔db), o isolamento é garantido por design: o nginx fisicamente não consegue abrir conexão com o PostgreSQL, mesmo que alguém configure um `proxy_pass` errado.

Usar `name:` explícito nas redes (ex: `${COMPOSE_PROJECT_NAME}-frontend`) também evita colisão de nomes entre projetos diferentes rodando no mesmo host Docker.

---

### Por que volumes nomeados e não bind mounts em produção?

Bind mounts (ex: `./data:/var/lib/postgresql/data`) mapeiam um diretório do host para dentro do container. São úteis em desenvolvimento para editar código sem rebuildar a imagem, mas têm problemas em produção:

- **Permissões**: o UID/GID do processo dentro do container precisa ter permissão de escrita no diretório do host. Com imagens como `postgres` ou `nginx`, isso exige `chown` manual no host.
- **Portabilidade**: o caminho no host (`./data`) é relativo ao `docker-compose.yml`. Se o projeto for movido ou executado por outro usuário, o bind mount pode apontar para o lugar errado ou não existir.
- **Backup**: volumes nomeados são listados por `docker volume ls` e podem ser copiados com `docker run --volumes-from` ou ferramentas como `restic`. Bind mounts ficam espalhados no sistema de arquivos do host sem rastreabilidade.
- **Exclusão acidental**: `docker compose down -v` remove volumes nomeados, mas não toca bind mounts — comportamento mais seguro em produção.

Volumes nomeados são gerenciados inteiramente pelo daemon Docker, que cuida das permissões e do ciclo de vida. Em produção, use volumes nomeados para dados persistentes e bind mounts apenas para configurações (arquivos de config montados como `:ro`).

---

## Adaptações comuns

### Trocar PostgreSQL por MySQL/MariaDB

No `web-classic`, substitua o serviço `db` e ajuste o healthcheck:

```yaml
db:
  image: mariadb:11.4
  environment:
    MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
    MARIADB_DATABASE: ${MARIADB_DATABASE}
    MARIADB_USER: ${MARIADB_USER}
    MARIADB_PASSWORD: ${MARIADB_PASSWORD}
  healthcheck:
    test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Adicionar storage externo ao registry (S3)

No `private-registry`, adicione ao bloco `environment` do serviço `registry`:

```yaml
REGISTRY_STORAGE: s3
REGISTRY_STORAGE_S3_REGION: us-east-1
REGISTRY_STORAGE_S3_BUCKET: meu-bucket-registry
REGISTRY_STORAGE_S3_ENCRYPT: "false"
REGISTRY_STORAGE_S3_SECURE: "true"
AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
```

E remova o volume `registry-data` (não é mais necessário).

---

## Licença

MIT
