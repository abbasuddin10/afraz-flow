-- Afraz Flow — Product image storage.
--
-- The app uploads product photos to a public `product-images` bucket and stores
-- the resulting public URL in `public.products.image_url`.
--
-- Paths are always `<tenant_id>/<uuid>.<ext>`, which lets the policies below
-- scope writes to members of the owning tenant without a separate lookup table.
--
-- Deploy with:
--   supabase db push
-- (or paste this file into the SQL editor after 0003_daily_briefing.sql).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Anyone may read product photos (the bucket is public).
drop policy if exists product_images_read on storage.objects;
create policy product_images_read on storage.objects
  for select to public
  using (bucket_id = 'product-images');

-- Only admins/managers of the tenant in the first path segment may write.
drop policy if exists product_images_insert on storage.objects;
create policy product_images_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and public.has_tenant_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin', 'manager']::text[]
    )
  );

drop policy if exists product_images_update on storage.objects;
create policy product_images_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'product-images'
    and public.has_tenant_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin', 'manager']::text[]
    )
  )
  with check (
    bucket_id = 'product-images'
    and public.has_tenant_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin', 'manager']::text[]
    )
  );

drop policy if exists product_images_delete on storage.objects;
create policy product_images_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'product-images'
    and public.has_tenant_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin', 'manager']::text[]
    )
  );
