-- Z-Studio: public free ZIP packs; only explicitly approved admin accounts can upload/edit/delete.
-- Run this in Supabase SQL Editor AFTER creating the project.

create table if not exists public.zstudio_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.zstudio_admins enable row level security;
revoke all on table public.zstudio_admins from anon, authenticated;

create or replace function public.is_zstudio_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.zstudio_admins a
    where a.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_zstudio_admin() from public;
revoke all on function public.is_zstudio_admin() from anon;
grant execute on function public.is_zstudio_admin() to authenticated;

create table if not exists public.zstudio_zip_packs (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 80),
  storage_path text not null unique,
  created_at timestamptz not null default now()
);

alter table public.zstudio_zip_packs enable row level security;
revoke all on table public.zstudio_zip_packs from anon, authenticated;
grant select on table public.zstudio_zip_packs to anon, authenticated;
grant insert, update, delete on table public.zstudio_zip_packs to authenticated;

drop policy if exists "Anyone can read free ZIP listings" on public.zstudio_zip_packs;
create policy "Anyone can read free ZIP listings"
on public.zstudio_zip_packs for select to anon, authenticated
using (true);

drop policy if exists "Z-Studio admins insert ZIP listings" on public.zstudio_zip_packs;
create policy "Z-Studio admins insert ZIP listings"
on public.zstudio_zip_packs for insert to authenticated
with check (public.is_zstudio_admin());

drop policy if exists "Z-Studio admins update ZIP listings" on public.zstudio_zip_packs;
create policy "Z-Studio admins update ZIP listings"
on public.zstudio_zip_packs for update to authenticated
using (public.is_zstudio_admin())
with check (public.is_zstudio_admin());

drop policy if exists "Z-Studio admins delete ZIP listings" on public.zstudio_zip_packs;
create policy "Z-Studio admins delete ZIP listings"
on public.zstudio_zip_packs for delete to authenticated
using (public.is_zstudio_admin());

-- Create a PUBLIC storage bucket named zstudio-free-zips in the Supabase Dashboard first.
-- Public is intentional because all packs in this setup are free; anyone with a file URL can download it.
-- Upload and delete operations are still restricted by the policies below.

drop policy if exists "Z-Studio admins upload free ZIPs" on storage.objects;
create policy "Z-Studio admins upload free ZIPs"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'zstudio-free-zips'
  and public.is_zstudio_admin()
  and lower(name) like '%.zip'
);

drop policy if exists "Z-Studio admins delete free ZIPs" on storage.objects;
create policy "Z-Studio admins delete free ZIPs"
on storage.objects for delete to authenticated
using (
  bucket_id = 'zstudio-free-zips'
  and public.is_zstudio_admin()
);

-- AFTER creating your admin account under Supabase Dashboard > Authentication > Users,
-- copy its UUID and run the following separately, replacing the placeholder:
-- insert into public.zstudio_admins (user_id) values ('YOUR-AUTH-USER-UUID');
