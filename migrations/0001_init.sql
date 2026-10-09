CREATE EXTENSION IF NOT EXISTS citext;

-- ===== identidade =====
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext NOT NULL,
  password_hash text   NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);
CREATE UNIQUE INDEX users_email_active_uq ON users (email) WHERE deleted_at IS NULL;

CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id  uuid NOT NULL,                 -- cadeia de rotação
  token_hash text NOT NULL UNIQUE,          -- SHA-256 do token opaco
  expires_at timestamptz NOT NULL,
  used_at    timestamptz,                   -- preenchido ao rotacionar
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_user_idx   ON refresh_tokens (user_id);

-- ===== tenancy =====
CREATE TABLE projects (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE project_members (
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  role       text NOT NULL CHECK (role IN ('owner','admin','member')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (project_id, user_id)
);
CREATE INDEX project_members_user_idx ON project_members (user_id);

CREATE TABLE api_keys (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id   uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name         text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  prefix       text NOT NULL,               -- só para exibição/identificação
  key_hash     text NOT NULL UNIQUE,        -- SHA-256 da chave completa
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  revoked_at   timestamptz
);
CREATE INDEX api_keys_project_idx ON api_keys (project_id);

-- ===== domínio =====
CREATE TABLE endpoints (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id           uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  url                  text NOT NULL CHECK (char_length(url) <= 2048),
  description          text CHECK (char_length(description) <= 500),
  secret_enc           bytea NOT NULL,      -- AES-256-GCM (nonce||ciphertext||tag)
  event_types          text[] NOT NULL CHECK (cardinality(event_types) BETWEEN 1 AND 50),
  status               text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','paused','disabled')),
  consecutive_failures integer NOT NULL DEFAULT 0 CHECK (consecutive_failures >= 0),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  deleted_at           timestamptz
);
CREATE INDEX endpoints_project_active_idx ON endpoints (project_id) WHERE deleted_at IS NULL;

CREATE TABLE events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  type            text NOT NULL CHECK (char_length(type) <= 100
                    AND type ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'),
  payload         jsonb NOT NULL,           -- limite de tamanho aplicado na API
  idempotency_key text CHECK (char_length(idempotency_key) <= 255),
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX events_idempotency_uq
  ON events (project_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX events_project_created_idx
  ON events (project_id, created_at DESC, id DESC);

CREATE TABLE deliveries (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  endpoint_id     uuid NOT NULL REFERENCES endpoints(id),
  project_id      uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  status          text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','delivered','failed')),
  attempt_count   integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  locked_until    timestamptz,              -- lease do worker
  last_attempt_at timestamptz,
  delivered_at    timestamptz,
  replay_of       uuid REFERENCES deliveries(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CHECK ((status = 'delivered') = (delivered_at IS NOT NULL))
);
-- uma entrega "original" por (evento, endpoint); replays podem repetir
CREATE UNIQUE INDEX deliveries_event_endpoint_uq
  ON deliveries (event_id, endpoint_id) WHERE replay_of IS NULL;
-- índice do worker: só linhas pendentes, ordenadas pelo próximo horário
CREATE INDEX deliveries_due_idx ON deliveries (next_attempt_at) WHERE status = 'pending';
-- dashboard
CREATE INDEX deliveries_project_created_idx
  ON deliveries (project_id, created_at DESC, id DESC);
CREATE INDEX deliveries_endpoint_created_idx
  ON deliveries (endpoint_id, created_at DESC);
CREATE INDEX deliveries_event_idx ON deliveries (event_id);

CREATE TABLE delivery_attempts (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id      uuid NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
  attempt_number   integer NOT NULL CHECK (attempt_number > 0),
  started_at       timestamptz NOT NULL,
  duration_ms      integer CHECK (duration_ms >= 0),
  response_status  integer,                 -- null se não houve resposta HTTP
  response_snippet text CHECK (char_length(response_snippet) <= 2048),
  error_code       text,                    -- TIMEOUT, DNS_FAILED, SSRF_BLOCKED...
  UNIQUE (delivery_id, attempt_number)
);

-- ===== auditoria (V1) =====
CREATE TABLE audit_logs (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id    uuid,                       -- sem FK de propósito: o log sobrevive
  actor_user_id uuid,
  action        text NOT NULL,              -- 'endpoint.created', 'api_key.revoked'...
  entity_type   text NOT NULL,
  entity_id     uuid,
  metadata      jsonb NOT NULL DEFAULT '{}',
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_project_idx ON audit_logs (project_id, created_at DESC);

-- ===== updated_at =====
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated     BEFORE UPDATE ON users      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER projects_updated  BEFORE UPDATE ON projects   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER endpoints_updated BEFORE UPDATE ON endpoints  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER deliveries_updated BEFORE UPDATE ON deliveries FOR EACH ROW EXECUTE FUNCTION set_updated_at();