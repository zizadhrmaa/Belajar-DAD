SET search_path TO perpustakaan, public;
with jml_peminjaman_10anggota_terbanyak as (
select count(peminjaman_id) as jml_peminjaman, anggota_id 
from peminjaman 
group by anggota_id
order by count(peminjaman_id) desc 
limit 10), 

pendapatan_buku_gapernah_dipinjam as (
select e.buku_id, coalesce(sum(pd.jumlah), 0) as total_fine_revenue
from eksemplar e 
left join peminjaman p on p.eksemplar_id = e.eksemplar_id 
join pembayaran_denda pd on pd.peminjaman_id = p.peminjaman_id
where p.anggota_id not in (
select anggota_id from jml_peminjaman_10anggota_terbanyak)
group by e.buku_id),

ranking_buku as (
select buku_id, total_fine_revenue, 
dense_rank() over(order by total_fine_revenue desc) as rn
from pendapatan_buku_gapernah_dipinjam)

select b.judul as title, rb.total_fine_revenue
from buku b 
join ranking_buku rb on rb.buku_id = b.buku_id
where rb.rn = 1;