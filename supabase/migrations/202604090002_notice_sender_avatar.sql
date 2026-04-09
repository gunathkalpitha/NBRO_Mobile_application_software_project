-- Store sender avatar on notices so officers can see the admin photo with each notice.

ALTER TABLE public.notices
  ADD COLUMN IF NOT EXISTS published_by_avatar_url TEXT;
