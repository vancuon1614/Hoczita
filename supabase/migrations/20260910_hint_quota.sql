create table if not exists daily_hint_quota (
  user_id uuid not null,
  quota_date date not null,
  hints_remaining int not null default 3,
  warning_shown boolean not null default false,
  primary key (user_id, quota_date)
);

-- Enable RLS
alter table daily_hint_quota enable row level security;

-- Policy
create policy "Users can view and update their own quota"
  on daily_hint_quota for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- RPC to request hint
create or replace function request_hint_start()
returns json
language plpgsql security definer
as $$
declare
  _uid uuid := auth.uid();
  _today date := current_date;
  _remaining int;
  _warning boolean;
begin
  if _uid is null then
    return json_build_object('allowed', false);
  end if;

  -- Get or create quota for today
  insert into daily_hint_quota (user_id, quota_date, hints_remaining, warning_shown)
  values (_uid, _today, 3, false)
  on conflict (user_id, quota_date) do nothing;

  select hints_remaining, warning_shown 
  into _remaining, _warning
  from daily_hint_quota 
  where user_id = _uid and quota_date = _today;

  if _remaining <= 0 then
    return json_build_object('allowed', false, 'remaining', 0);
  end if;

  if _remaining = 2 and not _warning then
    return json_build_object('allowed', 'needs_confirmation', 'remainingAfterUse', 1);
  end if;

  -- Otherwise, allow and deduct immediately
  update daily_hint_quota
  set hints_remaining = hints_remaining - 1
  where user_id = _uid and quota_date = _today
  returning hints_remaining into _remaining;

  return json_build_object('allowed', true, 'remaining', _remaining);
end;
$$;

-- RPC to confirm hint after warning
create or replace function confirm_hint_after_warning()
returns json
language plpgsql security definer
as $$
declare
  _uid uuid := auth.uid();
  _today date := current_date;
  _remaining int;
begin
  if _uid is null then
    return json_build_object('allowed', false);
  end if;

  update daily_hint_quota
  set warning_shown = true, hints_remaining = hints_remaining - 1
  where user_id = _uid and quota_date = _today and hints_remaining > 0
  returning hints_remaining into _remaining;

  if not found then
    return json_build_object('allowed', false);
  end if;

  return json_build_object('allowed', true, 'remaining', _remaining);
end;
$$;
