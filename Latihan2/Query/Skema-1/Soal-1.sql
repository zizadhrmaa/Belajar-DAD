SET search_path TO perpustakaan, public;

with jumlah_peminjaman as (
select e.buku_id, count(p.peminjaman_id) as total_borrowings 
from peminjaman p 
join eksemplar e on p.eksemplar_id = e.eksemplar_id 
where p.tanggal_pinjam >= current_date - interval '12 months' 
group by e.buku_id),

ranking_peminjaman as (
select buku_id, total_borrowings, 
dense_rank() over(order by total_borrowings desc) as borrowing_rank 
from jumlah_peminjaman)

select b.judul as title, rp.total_borrowings, rp.borrowing_rank 
from ranking_peminjaman rp 
join buku b on b.buku_id = rp.buku_id 
where borrowing_rank <= 5 
order by rp.borrowing_rank, b.judul;
