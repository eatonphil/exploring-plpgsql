-- Oddly, CREATE OR REPLACE doesn't exist for types
DROP TYPE IF EXISTS json_token CASCADE;
CREATE TYPE json_token AS (
  kind text,
  value text
);

CREATE OR REPLACE FUNCTION json_lex(j text, OUT ts json_token[]) RETURNS json_token[] AS $$
DECLARE 
  i int = 1; -- Index in loop
  c text; -- Current character in loop
  token text; -- Current accumulated characters
BEGIN
  WHILE i < length(j) + 1 LOOP
    c = substr(j, i, 1);
    token = '';

    -- Handle syntax characters
    IF c = '{' OR c = '}' OR c = ',' OR c = ':' THEN
      ts = array_append(ts, ('syntax', c)::json_token);
      i = i + 1;
      CONTINUE;
    END IF;

    -- Handle whitespace
    IF regexp_replace(c, '^\s+', '') = '' THEN
      i = i + 1;
      CONTINUE;
    END IF;

    -- Handle strings
    IF c = '"' THEN
      i = i + 1;
      c = substr(j, i, 1);
      WHILE c <> '"' LOOP
	token = token || c;
	i = i + 1;
	c = substr(j, i, 1);
      END LOOP;

      i = i + 1;
      ts = array_append(ts, ('string', token)::json_token);
      CONTINUE;
    END IF;

    -- Handle numbers
    WHILE c ~ '^[0-9]+$' LOOP
      token = token || c;
      i = i + 1;
      c = substr(j, i, 1);
    END LOOP;
    IF length(token) > 0 THEN
      ts = array_append(ts, ('number', token)::json_token);
      CONTINUE;
    END IF;

    RAISE EXCEPTION 'Unknown character: %, at index: %; already found: %.', c, i, ts;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

DROP TYPE IF EXISTS json_key_value CASCADE;
CREATE TYPE json_key_value AS (
  k text,
  v text
);

CREATE OR REPLACE FUNCTION json_parse(ts json_token[], i int) RETURNS json_key_value[] AS $$
DECLARE
  t json_token; -- Current token in tokens loop
  kvs json_key_value[];
  k text;
BEGIN
  t = ts[i];

  IF t.kind <> 'syntax' OR t.value <> '{' THEN
    RAISE EXCEPTION 'Invalid JSON, must be an object, got: %.', t;
  END IF;
  i = i + 1;
  t = ts[i];

  WHILE t.kind <> 'syntax' OR t.value <> '}' LOOP
    IF array_length(kvs, 1) > 0 THEN
      IF t.kind <> 'syntax' OR t.value <> ',' THEN
        RAISE EXCEPTION 'JSON key-value pair must be followed by a comma or closing brace, got: %.', t;
      END IF;

      i = i + 1;
      t = ts[i];
    END IF;

    IF t.kind <> 'string' THEN
      RAISE EXCEPTION 'JSON object must start with string key, got: %.', t;
    END IF;
    k = t.value;

    i = i + 1;
    t = ts[i];
    IF t.kind <> 'syntax' OR t.value <> ':' THEN
      RAISE EXCEPTION 'JSON object must start with string key followed by colon, got: %.', t;
    END IF;

    i = i + 1;
    t = ts[i];
    IF t.kind = 'number' OR t.kind = 'string' THEN
      kvs = array_append(kvs, (k, t)::json_key_value);
      i = i + 1;
      t = ts[i];
      CONTINUE;
    END IF;

    RAISE EXCEPTION 'Invalid key-value pair syntax, got: %.', t;
  END LOOP;

  RETURN kvs;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION json_from_string(s text) RETURNS json_key_value[] AS $$
BEGIN
  RETURN json_parse(json_lex(s), 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION json_get(kvs json_key_value[], key text) RETURNS text AS $$
DECLARE
  kv json_key_value;
BEGIN
  FOREACH kv IN ARRAY kvs LOOP
    IF kv.k = key THEN RETURN (kv.v::json_token).value; END IF;
  END LOOP;

  RAISE EXCEPTION 'Key not found.';
END;
$$ LANGUAGE plpgsql;
