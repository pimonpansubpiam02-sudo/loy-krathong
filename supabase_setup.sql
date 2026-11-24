-- ============================================================
--  ลอยกระทงออนไลน์ · Supabase setup
--  วิธีใช้: Supabase Dashboard → SQL Editor → วางทั้งไฟล์ → Run
--  จากนั้นคัดลอก Project URL และ anon public key (Project Settings → API)
--  ไปใส่ที่ตัวแปร CONFIG ด้านบนสุดของ index.html
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists public.krathongs (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  nickname    text not null check (char_length(nickname) between 1 and 20),
  wish        text not null check (char_length(wish)    between 1 and 120),
  gender      text not null check (gender   in ('male','female','other')),
  outfit      text not null check (outfit   in ('f_sabai','f_lace','f_silk','m_ratcha','m_mohom','m_pattern')),
  krathong    text not null check (krathong in ('lotus','banana','bread','coconut','butterfly')),
  spot_id     text not null check (spot_id  in ('bkk','cnx','ayt','sukhothai','kwai','ubon','nongkhai','phitsanulok'))
);

create index if not exists krathongs_created_idx on public.krathongs (created_at desc);
create index if not exists krathongs_spot_idx    on public.krathongs (spot_id);

-- Row Level Security: ใครก็อ่านและเพิ่มได้ แต่แก้ไข/ลบไม่ได้
alter table public.krathongs enable row level security;

drop policy if exists "krathongs_read"   on public.krathongs;
drop policy if exists "krathongs_insert" on public.krathongs;

create policy "krathongs_read"   on public.krathongs for select to anon, authenticated using (true);
create policy "krathongs_insert" on public.krathongs for insert to anon, authenticated with check (true);

-- ตัวนับต่อสถานที่ (ใช้แสดงตัวเลขบนหมุดแผนที่)
create or replace view public.krathong_stats as
  select spot_id, count(*)::int as total
  from public.krathongs
  group by spot_id;

grant select on public.krathong_stats to anon, authenticated;
grant select, insert on public.krathongs to anon, authenticated;

-- เปิด Realtime ให้ตาราง
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'krathongs'
  ) then
    alter publication supabase_realtime add table public.krathongs;
  end if;
end $$;

-- ------------------------------------------------------------
-- (ทางเลือก) ป้องกันการยิงรัว: จำกัด 1 รายการ / 10 วินาที ต่อ nickname
-- ถ้าจะใช้งานจริงจังควรย้ายการ insert ไปผ่าน Edge Function + CAPTCHA
-- ------------------------------------------------------------
-- create or replace function public.krathongs_throttle() returns trigger as $$
-- begin
--   if exists (select 1 from public.krathongs
--              where nickname = new.nickname and created_at > now() - interval '10 seconds') then
--     raise exception 'ลอยถี่เกินไป กรุณารอสักครู่';
--   end if;
--   return new;
-- end $$ language plpgsql;
-- create trigger krathongs_throttle_trg before insert on public.krathongs
--   for each row execute function public.krathongs_throttle();
