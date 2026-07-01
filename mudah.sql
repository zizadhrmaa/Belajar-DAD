(1)
select * from "order" order by order_id asc limit 10;

(2)
select order_id, user_id, driver_id, waktu_order, tarif_final, status 
from "order" where status = 'selesai' order by order_id asc;

(3)
select order_id, user_id, driver_id, waktu_order, alasan_batal, status 
from "order" where status = 'dibatalkan' order by waktu_order asc;

(4)
select order_id, user_id, driver_id, waktu_order, waktu_pickup, jarak_km, tarif_final 
from "order" where status = 'dalam_perjalanan' order by waktu_order asc;

(5)
select order_id, user_id, driver_id, jarak_km, tarif_final, status 
from "order" order by jarak_km desc, order_id asc limit 10;

(6)
select order_id, user_id, driver_id, tarif_normal, diskon, tarif_final, status 
from "order" order by tarif_final desc limit 10;

(7)
select order_id, user_id, promo_id, tarif_normal, diskon, tarif_final, status 
from "order" where promo_id is not null order by order_id asc;

(8)
select order_id, user_id, promo_id, tarif_normal, diskon, tarif_final, status 
from "order" where promo_id is null order by order_id asc;

(9)
select count(*) as total_order from "order";

(10)
select status, count(*) as total_order from "order" group by status order by total_order desc;

(11)
select coalesce (sum(tarif_final) filter (where status ='selesai'), 0) as gross_revenue from "order";

(12)
select round(avg(tarif_final) filter (where status ='selesai'),2) as avg_tarif_final from "order";

(13)
select min(jarak_km) as min_jarak_km, max(jarak_km) as max_jarak_km from "order";

(14)
select sum(tarif_final) as total_revenue, avg(tarif_final) as avg_tarif_final, 
min(tarif_final) as min_tarif_final, max(tarif_final) as max_tarif_final from "order";

(15)
select tier, coalesce (count(*), 0) as jumlah_user 
from "user" group by tier order by jumlah_user desc;

(16)
select status, count(driver_id) as jumlah_driver 
from "order" group by status order by jumlah_driver desc;

(17)
select is_mitra_premium, count(*) as jumlah_driver 
from driver group by is_mitra_premium order by is_mitra_premium desc;

(18)
select is_premium, count(*) as jumlah_zona 
from zona group by is_premium order by is_premium desc;

(19)
select tipe, count(*) as jumlah_promo
from promo group by tipe order by jumlah_promo desc;

(20)
select tipe_insentif, count(*) as jumlah_data, sum(jumlah) as total_jumlah 
from insentif_driver group by tipe_insentif order by jumlah_data desc;

(21)
select z.zona_id, z.nama_zona, w.nama_wilayah, w.provinsi, z.is_premium 
from zona z join wilayah w on z.wilayah_id = w.wilayah_id order by zona_id asc;

(22)
select d.driver_id, d.nama as nama_driver, t.nama_tipe, d.status, d.is_mitra_premium 
from driver d join tipe_kendaraan t on d.tipe_kendaraan_id = t.tipe_id order by driver_id asc;

(23)
select d.driver_id, d.nama as nama_driver, z.nama_zona, d.status from driver d 
join zona z on d.zona_id = z.zona_id order by driver_id asc;

(24)
select d.driver_id, d.nama as nama_driver, z.nama_zona, t.nama_tipe, d.status from driver d 
join zona z on d.zona_id = z.zona_id 
join tipe_kendaraan t on d.tipe_kendaraan_id = t.tipe_id order by driver_id asc;

(25)
select u.user_id, u.nama as nama_user, u.tier, z.nama_zona, u.tanggal_daftar 
from "user" u join zona z on z.zona_id = u.zona_domisili_id order by user_id asc;

(26)
select o.order_id, u.nama as nama_user, d.nama as nama_driver, o.waktu_order, o.tarif_final, o.status 
from "order" o join "user" u on o.user_id = u.user_id join driver d on d.driver_id = o.driver_id 
order by order_id asc;

(27)
select o.order_id, p.nama_zona as pickup_zone, d.nama_zona as dropoff_zone, o.jarak_km, o.tarif_final, o.status
from "order" o join zona p on o.zona_pickup_id = p.zona_id join zona d on o.zona_dropoff_id = d.zona_id
order by order_id asc;

(28)
select o.order_id, p.kode_promo, p.tipe, o.tarif_normal, o.diskon, o.tarif_final, o.status
from "order" o join promo p on o.promo_id = p.promo_id order by order_id asc;

(29)
select date_trunc('month', waktu_order)::date as bulan, coalesce(count(*), 0) as total_order
from "order" group by bulan order by bulan asc; 

(30)
select date_trunc('month', waktu_order)::date as bulan, 
coalesce(count(*) filter (where status ='selesai'), 0) as total_order
from "order" group by bulan order by bulan asc; 

(31)
select date_trunc('month', waktu_order)::date as bulan, 
coalesce(sum(tarif_final) filter (where status ='selesai'), 0) as gross_revenue
from "order" group by bulan order by bulan asc; 

(32)
select extract (hour from waktu_order) as jam, coalesce(count(*), 0) as total_order
from "order" group by jam order by jam asc;

(33)
select extract (isodow from waktu_order) as hari_iso, coalesce(count(*), 0) as total_order
from "order" group by hari_iso order by hari_iso asc;

(34)
select COUNT(*) FILTER (WHERE status = 'selesai') AS order_selesai, 
COUNT(*) FILTER (WHERE status = 'dibatalkan') AS order_batal,
COUNT(*) FILTER (WHERE status = 'dalam_perjalanan') AS order_dalam_perjalanan
from "order";

(35)
select coalesce(count(*), 0) as total_order, 
coalesce(count(*) filter (where status ='selesai'), 0) as order_selesai, 
round (coalesce(count(*) filter (where status ='selesai'), 0) * 100.0/nullif(coalesce(count(*), 0), 0), 2) as completion_rate_pct
from "order";

(36)
select coalesce(count(*), 0) as total_order, 
coalesce(count(*) filter (where status ='dibatalkan'), 0) as order_batal, 
round (coalesce(count(*) filter (where status ='dibatalkan'), 0) * 100.0/nullif(coalesce(count(*), 0), 0), 2) as cancellation_rate_pct
from "order";

(37)
select date_trunc('month', waktu_order)::date as bulan,
coalesce(count(*), 0) as total_order, 
coalesce(count(*) filter (where status ='selesai'), 0) as order_selesai, 
round (coalesce(count(*) filter (where status ='selesai'), 0) * 100.0/nullif(coalesce(count(*), 0), 0), 2) as completion_rate_pct
from "order" group by bulan order by bulan asc;

(38)
select date_trunc('month', waktu_order)::date as bulan,
coalesce(count(*), 0) as total_order, 
coalesce(count(*) filter (where status ='dibatalkan'), 0) as order_batal, 
round (coalesce(count(*) filter (where status ='dibatalkan'), 0) * 100.0/nullif(coalesce(count(*), 0), 0), 2) as cancellation_rate_pct
from "order" group by bulan order by bulan asc;

(39)
select distinct p.promo_id, p.kode_promo, p.tipe, p.kuota from promo p 
left join "order" o on o.promo_id = p.promo_id where o.status is null order by promo_id asc;

(40)
select u.user_id, u.nama, u.tier, count(order_id) as actual_total_order 
from "user" u left join "order" o on o.user_id = u.user_id 
group by u.user_id, u.nama, u.tier order by user_id asc;