CREATE OR REPLACE FUNCTION slength(s text) RETURNS int AS $$
BEGIN
  RETURN length(s);
END;
$$ LANGUAGE plpgsql;
