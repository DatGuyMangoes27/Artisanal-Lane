-- ============================================================
-- shop_follows: buyers follow maker shops
-- ============================================================
create table if not exists public.shop_follows (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references public.profiles(id) on delete cascade,
    shop_id    uuid not null references public.shops(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique(user_id, shop_id)
);

create index if not exists idx_shop_follows_user on public.shop_follows(user_id);
create index if not exists idx_shop_follows_shop on public.shop_follows(shop_id);

alter table public.shop_follows enable row level security;

create policy "Shop follows are publicly readable"
    on public.shop_follows for select
    using (true);

create policy "Users can follow shops"
    on public.shop_follows for insert
    with check (true);

create policy "Users can unfollow shops"
    on public.shop_follows for delete
    using (true);

-- ============================================================
-- shop_posts: maker photo + caption posts (Instagram-style)
-- ============================================================
create table if not exists public.shop_posts (
    id           uuid primary key default gen_random_uuid(),
    shop_id      uuid not null references public.shops(id) on delete cascade,
    caption      text not null default '',
    media_urls   jsonb not null default '[]'::jsonb,
    is_published boolean not null default true,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

create index if not exists idx_shop_posts_shop_created on public.shop_posts(shop_id, created_at desc);

alter table public.shop_posts enable row level security;

create policy "Published posts are publicly readable"
    on public.shop_posts for select
    using (is_published = true);

create policy "Vendors can insert posts for own shop"
    on public.shop_posts for insert
    with check (true);

create policy "Vendors can update own shop posts"
    on public.shop_posts for update
    using (true);

create policy "Vendors can delete own shop posts"
    on public.shop_posts for delete
    using (true);

-- Trigger for updated_at
create trigger set_shop_posts_updated_at
    before update on public.shop_posts
    for each row execute function update_updated_at_column();
