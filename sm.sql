DROP FUNCTION IF EXISTS sm_alength;
CREATE FUNCTION sm_alength(a text[]) RETURNS int AS $$
BEGIN
  RETURN COALESCE(array_length(a, 1), 0);
END;
$$ LANGUAGE plpgsql;

CREATE EXTENSION IF NOT EXISTS hstore;
DROP FUNCTION IF EXISTS sm_run;
CREATE FUNCTION sm_run(s text) RETURNS TEXT AS $$
DECLARE
  tokens text[] = regexp_split_to_array(s, '\s+');
  stack text[];
  defs hstore;
  tmps text[];
  token text; -- current token
  rps text[];
  pc int = 1; -- program counter
BEGIN
  WHILE true LOOP
    token = tokens[pc];
    RAISE NOTICE '[Debug] Current token: %. Current stack: %.', token, stack;
    IF token IS NULL THEN
      RAISE EXCEPTION 'PC out of bounds.';
    END IF;

    IF token = 'DEF' THEN
      tmps[1] = tokens[pc+1]; -- function name
      tmps[2] = pc + 2; -- starting pc
      WHILE tokens[pc] <> 'RET' LOOP
        -- RAISE NOTICE '[Debug] skipping past: %.', tokens[pc];
        pc = pc + 1;
      END LOOP;

      IF defs IS NULL THEN
        defs = hstore(tmps[1], tmps[2]);
      ELSE
        defs = defs || hstore(tmps[1], tmps[2]);
      END IF;
      pc = pc + 1; -- continue past 'RET'
      CONTINUE;
    END IF;

    IF token = '=' THEN
      -- Grab two items from stack
      tmps[1] = stack[sm_alength(stack) - 1];
      tmps[2] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      -- Replace last item on stack
      stack[sm_alength(stack)] = tmps[1]::int = tmps[2]::int;
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = '>' THEN
      -- Grab two items from stack
      tmps[1] = stack[sm_alength(stack) - 1];
      tmps[2] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      -- Replace last item on stack
      stack[sm_alength(stack)] = tmps[1]::int > tmps[2]::int;
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = '+' THEN
      -- Grab two items from stack
      tmps[1] = stack[sm_alength(stack) - 1];
      tmps[2] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      -- Replace last item on stack
      stack[sm_alength(stack)] = tmps[1]::int + tmps[2]::int;
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = '-' THEN
      -- Grab two items from stack
      tmps[1] = stack[sm_alength(stack) - 1];
      tmps[2] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      -- Replace last item on stack
      stack[sm_alength(stack)] = tmps[1]::int - tmps[2]::int;
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = '*' THEN
      -- Grab two items from stack
      tmps[1] = stack[sm_alength(stack) - 1];
      tmps[2] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      -- Replace last item on stack
      stack[sm_alength(stack)] = tmps[1]::int * tmps[2]::int;
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = '/' THEN
      -- Grab two items from stack
      tmps[1] = stack[sm_alength(stack) - 1];
      tmps[2] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      -- Replace last item on stack
      stack[sm_alength(stack)] = tmps[1]::int / tmps[2]::int;
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = '.' THEN
      -- Grab item
      tmps[1] = stack[sm_alength(stack)];
      RAISE NOTICE '%', tmps[1];
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = 'DUP' THEN
      -- Grab item
      tmps[1] = stack[sm_alength(stack)];
      -- Add it to the stack
      stack = array_append(stack, tmps[1]);
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = '1-' THEN
      -- Grab item
      tmps[1] = stack[sm_alength(stack)];
      -- Rewrite top of stack
      stack[sm_alength(stack)] = tmps[1]::int - 1;
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = 'SWAP' THEN
      -- Grab two items from stack
      tmps[1] = stack[sm_alength(stack) - 1];
      tmps[2] = stack[sm_alength(stack)];
      -- Swap the two
      -- Replace last item on stack
      stack[sm_alength(stack)] = tmps[1];
      stack[sm_alength(stack) - 1] = tmps[2];
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = 'CALL' THEN
      -- Grab item
      tmps[1] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      -- Store return pointer
      rps = array_append(rps, (pc + 1)::text);
      -- Fail if function not defined
      IF NOT defs?tmps[1] THEN
        RAISE EXCEPTION 'No such function, %.', tmps[1];
      END IF;
      -- Otherwise jump to function
      RAISE NOTICE '[Debug] Jumping to: %:%.', tmps[1], defs->tmps[1];
      pc = defs->tmps[1];
      CONTINUE;
    END IF;

    IF token = 'RET' THEN
      -- Grab last return pointer
      tmps[1] = rps[sm_alength(rps)];
      -- Drop last return pointer from stack
      rps = rps[1:sm_alength(rps) - 1];
      -- Jump to last return pointer
      pc = tmps[1]::int;
      CONTINUE;
    END IF;

    IF token = 'IF' THEN
      -- Grab last item from stack
      tmps[1] = stack[sm_alength(stack)];
      -- Remove one item from stack
      stack = stack[1:sm_alength(stack) - 1];
      IF NOT tmps[1]::boolean THEN
        WHILE tokens[pc] <> 'THEN' LOOP
	  pc = pc + 1;
	END LOOP;
	pc = pc + 1; -- Skip past THEN
      ELSE
        pc = pc + 1;
      END IF;
      CONTINUE;
    END IF;

    IF token = 'THEN' THEN
      -- Just skip past it
      pc = pc + 1;
      CONTINUE;
    END IF;

    IF token = 'EXIT' THEN
      RETURN stack[sm_alength(stack)];
    END IF;

    stack = array_append(stack, token);
    pc = pc + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
