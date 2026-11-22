-- Servings a dish makes: one serving = cooked mass / portions (C-ENERGIE-9).
alter table plat add column portions numeric not null default 1 check (portions > 0 and portions <= 50);
