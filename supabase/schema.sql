-- Barbearia Julio Caetano: schema inicial de produção
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null unique,
  gender text not null check (gender in ('male','female','undisclosed')),
  birth_date date not null,
  avatar_seed text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','barber')),
  created_at timestamptz not null default now()
);

create table if not exists public.services (
  id text primary key,
  name text not null,
  category text not null,
  price_cents integer not null check (price_cents >= 0),
  duration_minutes integer not null check (duration_minutes between 5 and 480),
  description text not null default '',
  image_key text,
  is_featured boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.barbers (
  id text primary key,
  name text not null,
  role text not null default '',
  bio text not null default '',
  image_key text,
  days_off integer[] not null default '{}',
  service_ids text[] not null default '{}',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.appointments (
  id text primary key,
  user_id uuid references auth.users(id) on delete set null,
  barber_id text not null references public.barbers(id),
  service_ids text[] not null,
  service_names text not null,
  appointment_date date not null,
  start_minute integer not null check (start_minute between 0 and 1439),
  duration_minutes integer not null check (duration_minutes > 0),
  total_cents integer not null check (total_cents >= 0),
  client_name text not null,
  phone text not null,
  status text not null default 'pendente' check (status in ('pendente','confirmado','concluido','cancelado','faltou')),
  source text not null default 'client',
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id text primary key,
  booking_id text not null unique references public.appointments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  barber_id text not null references public.barbers(id),
  rating integer not null check (rating between 1 and 5),
  comment text not null default '',
  client_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.business_settings (
  id text primary key default 'main',
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.services enable row level security;
alter table public.barbers enable row level security;
alter table public.appointments enable row level security;
alter table public.reviews enable row level security;
alter table public.business_settings enable row level security;

create or replace function public.has_staff_role()
returns boolean language sql stable security definer set search_path=public
as $$
 select exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('owner','admin','barber'));
$$;

create or replace function public.is_staff_admin()
returns boolean language sql stable security definer set search_path=public
as $$
 select exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('owner','admin'));
$$;

create policy "profiles read own or staff" on public.profiles for select to authenticated
using (id=auth.uid() or public.has_staff_role());
create policy "profiles insert own" on public.profiles for insert to authenticated
with check (id=auth.uid());
create policy "profiles update own or staff" on public.profiles for update to authenticated
using (id=auth.uid() or public.is_staff_admin()) with check (id=auth.uid() or public.is_staff_admin());

create policy "services public read active" on public.services for select to anon,authenticated using (is_active or public.has_staff_role());
create policy "services staff write" on public.services for all to authenticated using (public.is_staff_admin()) with check (public.is_staff_admin());
create policy "barbers public read active" on public.barbers for select to anon,authenticated using (is_active or public.has_staff_role());
create policy "barbers staff write" on public.barbers for all to authenticated using (public.is_staff_admin()) with check (public.is_staff_admin());

create policy "roles self read" on public.user_roles for select to authenticated using (user_id=auth.uid() or public.is_staff_admin());
create policy "roles owner write" on public.user_roles for all to authenticated using (exists(select 1 from public.user_roles r where r.user_id=auth.uid() and r.role='owner')) with check (exists(select 1 from public.user_roles r where r.user_id=auth.uid() and r.role='owner'));

create policy "appointments client read own" on public.appointments for select to authenticated using (user_id=auth.uid() or public.has_staff_role());
create policy "appointments client create own" on public.appointments for insert to authenticated with check (user_id=auth.uid() and status='pendente');
create policy "appointments client update own" on public.appointments for update to authenticated using (user_id=auth.uid() or public.is_staff_admin()) with check (user_id=auth.uid() or public.is_staff_admin());
create policy "appointments staff manage" on public.appointments for all to authenticated using (public.has_staff_role()) with check (public.has_staff_role());

create policy "reviews public read" on public.reviews for select to anon,authenticated using (true);
create policy "reviews own insert" on public.reviews for insert to authenticated with check (user_id=auth.uid());
create policy "reviews own update" on public.reviews for update to authenticated using (user_id=auth.uid() or public.is_staff_admin()) with check (user_id=auth.uid() or public.is_staff_admin());

create policy "settings public read" on public.business_settings for select to anon,authenticated using (true);
create policy "settings staff write" on public.business_settings for all to authenticated using (public.is_staff_admin()) with check (public.is_staff_admin());

insert into public.business_settings(id,settings) values ('main','{"name":"Barbearia Julio Caetano","desc":"Corte, barba e atendimento com hora marcada em Poá, SP.","hours":"Seg a Sáb · 09h às 19h","minCancelH":2}'::jsonb) on conflict(id) do nothing;

-- Após criar sua conta Google no site, promova-a como proprietária:
-- insert into public.user_roles(user_id, role)
-- select id, 'owner' from auth.users where email = 'SEU_EMAIL_GOOGLE';
