CREATE OR REPLACE FUNCTION string_to_array(s text) RETURNS char[] AS $$
DECLARE
  a char[];
BEGIN
  WHILE COALESCE(array_length(a, 1), 0) < length(s) LOOP
    a[COALESCE(array_length(a, 1), 0) + 1] = substr(s, COALESCE(array_length(a, 1), 0) + 1, 1);
  END LOOP;
  RETURN a;
END;
$$ LANGUAGE plpgsql;
