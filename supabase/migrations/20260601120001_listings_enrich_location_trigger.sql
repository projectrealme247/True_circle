-- Enqueue proximity enrichment after listing insert (requires pg_net extension).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.enqueue_listing_location_enrichment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  supabase_url text;
  service_key text;
  request_id bigint;
BEGIN
  IF NEW.latitude IS NULL OR NEW.longitude IS NULL THEN
    RETURN NEW;
  END IF;

  supabase_url := coalesce(
    current_setting('app.settings.supabase_url', true),
    current_setting('supabase.url', true)
  );
  service_key := coalesce(
    current_setting('app.settings.service_role_key', true),
    current_setting('supabase.service_role_key', true)
  );

  IF supabase_url IS NULL OR service_key IS NULL OR length(supabase_url) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT net.http_post(
    url := rtrim(supabase_url, '/') || '/functions/v1/enrich-location',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object(
      'listing_id', NEW.id,
      'latitude', NEW.latitude,
      'longitude', NEW.longitude
    )
  ) INTO request_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS listings_enrich_location_after_insert ON public.listings;

CREATE TRIGGER listings_enrich_location_after_insert
  AFTER INSERT ON public.listings
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_listing_location_enrichment();
