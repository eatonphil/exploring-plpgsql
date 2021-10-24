CREATE OR REPLACE FUNCTION string_to_array(s text) RETURNS char[] AS $$
DECLARE
  a char[];
BEGIN
  WHILE COALESCE(array_length(a, 1), 0) < length(s) LOOP
    a = array_append(a, substr(s, COALESCE(array_length(a, 1), 0) + 1, 1)::char);
  END LOOP;
  RETURN a;
END;
$$ LANGUAGE plpgsql;
