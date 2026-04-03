-- 01-schema.sql
-- Executado automaticamente pelo PostgreSQL no primeiro start do container.
-- Arquivos em /docker-entrypoint-initdb.d são rodados em ordem alfabética.
--
-- Este arquivo é um exemplo fictício. Substitua pelo schema real da aplicação.

CREATE TABLE IF NOT EXISTS exemplo_tabela (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(255) NOT NULL,
    criado_em   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Índice exemplo para demonstrar boas práticas de DDL inicial
CREATE INDEX IF NOT EXISTS idx_exemplo_nome ON exemplo_tabela (nome);
