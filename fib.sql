CREATE OR REPLACE FUNCTION fib(i int) RETURNS int AS $$
BEGIN
  IF i = 0 OR i = 1 THEN
    RETURN i;
  END IF;

  RETURN fib(i - 1) + fib(i - 2);
END;
$$ LANGUAGE plpgsql;
