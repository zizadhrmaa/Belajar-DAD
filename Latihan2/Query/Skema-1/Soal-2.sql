SET search_path TO perpustakaan, public;

with jml_semua_members as (
select c.cabang_id as branch_id, 
coalesce(count(a.anggota_id), 0) as total_members 
from cabang c 
left join anggota a on a.cabang_id = c.cabang_id 
group by  c.cabang_id 
having count(a.anggota_id) >= 50),

jml_active_members as 
(select c.cabang_id as branch_id, 
coalesce(count(a.anggota_id), 0) as active_members 
from cabang c 
join anggota a on a.cabang_id = c.cabang_id 
where a.aktif = 't' 
group by c.cabang_id), 

percentage_active_members as (
select semua.branch_id,
round(
coalesce(
(active.active_members::numeric/nullif(semua.total_members, 0)) * 100
, 0)
, 2) as active_percentage 
from jml_semua_members semua 
join jml_active_members active on semua.branch_id = active.branch_id ),

max_percentage as (
select max(active_percentage) as max_active_percentage 
from percentage_active_members) 

select semua.branch_id, semua.total_members, active.active_members, percentage.active_percentage 
from jml_semua_members semua 
join jml_active_members active on semua.branch_id = active.branch_id 
join percentage_active_members percentage on percentage.branch_id = semua.branch_id
join max_percentage maxp on maxp.max_active_percentage = percentage.active_percentage 
order by percentage.active_percentage desc;