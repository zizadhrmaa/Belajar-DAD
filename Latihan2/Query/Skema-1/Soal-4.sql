SET search_path TO perpustakaan, public;
with jml_peminjaman_5cabang_terbesar as (
select e.cabang_id, sum(p.peminjaman_id) as jml_peminjaman
from eksemplar e join peminjaman p on p.eksemplar_id = e.eksemplar_id
group by e.cabang_id 
order by sum(p.peminjaman_id) desc limit 5),

buku_gapernah_tersedia as (
select b.buku_id, b.judul, coalesce(sum(p.peminjaman_id), 0) as  total_borrowings
from eksemplar e 
right join buku b on b.buku_id = e.buku_id
left join peminjaman p on p.eksemplar_id = e.eksemplar_id
where e.cabang_id not in (select cabang_id from jml_peminjaman_5cabang_terbesar) 
group by b.buku_id),

ranking_buku as (
select buku_id, judul as title, total_borrowings,
dense_rank() over(order by total_borrowings desc) as rn
from buku_gapernah_tersedia)

select title, total_borrowings 
from ranking_buku 
where rn = 1;