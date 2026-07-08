-- ============================================================
-- SKEMA 5: SISTEM MANUFAKTUR DAN SUPPLY CHAIN MULTI-PABRIK
-- PostgreSQL
--
-- Tujuan data:
-- 1. Mendukung seluruh 7 soal OLAP pada Skema 5.
-- 2. Menyediakan data multi-pabrik, gudang, produk, bahan baku,
--    supplier, pembelian, penerimaan, produksi, QC, penjualan,
--    pengiriman, pembayaran, dan pegawai.
-- 3. Menyediakan pola analitik untuk ranking, NOT EXISTS,
--    pertumbuhan bulanan, moving average, persentil, rasio,
--    dan evaluasi kinerja supplier.
--
-- Jalankan seluruh file ini pada database PostgreSQL.
-- ============================================================

DROP SCHEMA IF EXISTS manufaktur_supply_chain CASCADE;
CREATE SCHEMA manufaktur_supply_chain;
SET search_path TO manufaktur_supply_chain, public;

-- ============================================================
-- 1. TABEL WILAYAH
-- ============================================================

CREATE TABLE negara (
    negara_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_negara        varchar(100) NOT NULL UNIQUE,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provinsi (
    provinsi_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_provinsi      varchar(100) NOT NULL,
    negara_id          integer NOT NULL REFERENCES negara(negara_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (nama_provinsi, negara_id)
);

CREATE TABLE kota (
    kota_id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_kota          varchar(100) NOT NULL,
    provinsi_id        integer NOT NULL REFERENCES provinsi(provinsi_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (nama_kota, provinsi_id)
);

CREATE TABLE alamat (
    alamat_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alamat             varchar(200) NOT NULL,
    kecamatan          varchar(100) NOT NULL,
    kota_id            integer NOT NULL REFERENCES kota(kota_id),
    kode_pos           varchar(10) NOT NULL,
    telepon            varchar(30),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. MASTER SATUAN, KATEGORI, PRODUK, DAN BAHAN
-- ============================================================

CREATE TABLE satuan (
    satuan_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_satuan        varchar(50) NOT NULL UNIQUE,
    simbol             varchar(10) NOT NULL UNIQUE,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kategori_produk (
    kategori_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama               varchar(100) NOT NULL UNIQUE,
    parent_kategori_id integer REFERENCES kategori_produk(kategori_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE produk (
    produk_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kategori_id        integer NOT NULL REFERENCES kategori_produk(kategori_id),
    kode_produk        varchar(30) NOT NULL UNIQUE,
    nama_produk        varchar(150) NOT NULL UNIQUE,
    harga_jual         numeric(16,2) NOT NULL CHECK (harga_jual > 0),
    satuan_id          integer NOT NULL REFERENCES satuan(satuan_id),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kategori_bahan (
    kategori_bahan_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama                     varchar(100) NOT NULL UNIQUE,
    parent_kategori_id       integer REFERENCES kategori_bahan(kategori_bahan_id),
    last_update              timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bahan_baku (
    bahan_id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kategori_bahan_id  integer NOT NULL REFERENCES kategori_bahan(kategori_bahan_id),
    kode_bahan         varchar(30) NOT NULL UNIQUE,
    nama_bahan         varchar(150) NOT NULL UNIQUE,
    harga_standar      numeric(16,2) NOT NULL CHECK (harga_standar > 0),
    satuan_id          integer NOT NULL REFERENCES satuan(satuan_id),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. BOM
-- ============================================================

CREATE TABLE bill_of_material (
    bom_id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produk_id          integer NOT NULL REFERENCES produk(produk_id),
    versi              varchar(20) NOT NULL,
    tanggal_berlaku    date NOT NULL,
    aktif              boolean NOT NULL DEFAULT true,
    UNIQUE (produk_id, versi)
);

CREATE TABLE detail_bom (
    detail_bom_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bom_id             integer NOT NULL REFERENCES bill_of_material(bom_id),
    bahan_id           integer NOT NULL REFERENCES bahan_baku(bahan_id),
    jumlah             numeric(14,4) NOT NULL CHECK (jumlah > 0),
    satuan_id          integer NOT NULL REFERENCES satuan(satuan_id),
    UNIQUE (bom_id, bahan_id)
);

-- ============================================================
-- 4. SUPPLIER DAN PEMBELIAN
-- ============================================================

CREATE TABLE supplier (
    supplier_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_supplier      varchar(150) NOT NULL UNIQUE,
    email              varchar(150) NOT NULL UNIQUE,
    telepon            varchar(30) NOT NULL,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE supplier_bahan (
    supplier_id        integer NOT NULL REFERENCES supplier(supplier_id),
    bahan_id           integer NOT NULL REFERENCES bahan_baku(bahan_id),
    harga_beli         numeric(16,2) NOT NULL CHECK (harga_beli > 0),
    minimum_order      numeric(14,2) NOT NULL CHECK (minimum_order > 0),
    lead_time_hari     integer NOT NULL CHECK (lead_time_hari >= 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (supplier_id, bahan_id)
);

-- ============================================================
-- 5. PABRIK, GUDANG, PEGAWAI, DAN STOK
-- ============================================================

CREATE TABLE jabatan (
    jabatan_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_jabatan       varchar(100) NOT NULL UNIQUE,
    level_jabatan      integer NOT NULL CHECK (level_jabatan > 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pabrik (
    pabrik_id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_pabrik            varchar(120) NOT NULL UNIQUE,
    manager_pegawai_id     integer,
    alamat_id              bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif                  boolean NOT NULL DEFAULT true,
    last_update            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pegawai (
    pegawai_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pabrik_id          integer NOT NULL REFERENCES pabrik(pabrik_id),
    atasan_id          integer REFERENCES pegawai(pegawai_id),
    nama_depan         varchar(80) NOT NULL,
    nama_belakang      varchar(80) NOT NULL,
    jabatan_id         integer NOT NULL REFERENCES jabatan(jabatan_id),
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    email              varchar(150) NOT NULL UNIQUE,
    aktif              boolean NOT NULL DEFAULT true,
    tanggal_masuk      date NOT NULL,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE pabrik
    ADD CONSTRAINT fk_pabrik_manager
    FOREIGN KEY (manager_pegawai_id)
    REFERENCES pegawai(pegawai_id);

CREATE TABLE gudang (
    gudang_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pabrik_id          integer NOT NULL REFERENCES pabrik(pabrik_id),
    nama_gudang        varchar(120) NOT NULL UNIQUE,
    jenis_gudang       varchar(20) NOT NULL
                       CHECK (jenis_gudang IN ('BAHAN','PRODUK')),
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stok_bahan (
    stok_bahan_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bahan_id           integer NOT NULL REFERENCES bahan_baku(bahan_id),
    gudang_id          integer NOT NULL REFERENCES gudang(gudang_id),
    jumlah             numeric(16,2) NOT NULL CHECK (jumlah >= 0),
    stok_minimum       numeric(16,2) NOT NULL CHECK (stok_minimum >= 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (bahan_id, gudang_id)
);

CREATE TABLE stok_produk (
    stok_produk_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produk_id          integer NOT NULL REFERENCES produk(produk_id),
    gudang_id          integer NOT NULL REFERENCES gudang(gudang_id),
    jumlah             numeric(16,2) NOT NULL CHECK (jumlah >= 0),
    stok_minimum       numeric(16,2) NOT NULL CHECK (stok_minimum >= 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (produk_id, gudang_id)
);

CREATE TABLE purchase_order (
    po_id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id        integer NOT NULL REFERENCES supplier(supplier_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    gudang_id          integer NOT NULL REFERENCES gudang(gudang_id),
    tanggal_po         timestamp NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('DRAFT','DIKIRIM','DITERIMA_SEBAGIAN','SELESAI','DIBATALKAN')),
    total              numeric(18,2) NOT NULL CHECK (total >= 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detail_purchase_order (
    detail_po_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    po_id              bigint NOT NULL REFERENCES purchase_order(po_id),
    bahan_id           integer NOT NULL REFERENCES bahan_baku(bahan_id),
    jumlah             numeric(14,2) NOT NULL CHECK (jumlah > 0),
    harga              numeric(16,2) NOT NULL CHECK (harga > 0),
    subtotal           numeric(18,2) GENERATED ALWAYS AS (jumlah * harga) STORED,
    UNIQUE (po_id, bahan_id)
);

CREATE TABLE penerimaan_bahan (
    penerimaan_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    po_id              bigint NOT NULL REFERENCES purchase_order(po_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    tanggal_terima     timestamp NOT NULL,
    nomor_dokumen      varchar(50) NOT NULL UNIQUE,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('DRAFT','DIVERIFIKASI','DITOLAK')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detail_penerimaan (
    detail_penerimaan_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    penerimaan_id         bigint NOT NULL REFERENCES penerimaan_bahan(penerimaan_id),
    detail_po_id          bigint NOT NULL REFERENCES detail_purchase_order(detail_po_id),
    jumlah_diterima       numeric(14,2) NOT NULL CHECK (jumlah_diterima >= 0),
    jumlah_rusak          numeric(14,2) NOT NULL CHECK (jumlah_rusak >= 0),
    CHECK (jumlah_rusak <= jumlah_diterima)
);

-- ============================================================
-- 6. PRODUKSI DAN KUALITAS
-- ============================================================

CREATE TABLE perintah_produksi (
    produksi_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produk_id          integer NOT NULL REFERENCES produk(produk_id),
    bom_id             integer NOT NULL REFERENCES bill_of_material(bom_id),
    pabrik_id          integer NOT NULL REFERENCES pabrik(pabrik_id),
    tanggal_mulai      timestamp NOT NULL,
    tanggal_selesai    timestamp,
    target_jumlah      numeric(14,2) NOT NULL CHECK (target_jumlah > 0),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('DIRENCANAKAN','BERJALAN','SELESAI','DIBATALKAN')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pemakaian_bahan (
    pemakaian_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produksi_id        bigint NOT NULL REFERENCES perintah_produksi(produksi_id),
    stok_bahan_id      bigint NOT NULL REFERENCES stok_bahan(stok_bahan_id),
    jumlah_rencana     numeric(16,4) NOT NULL CHECK (jumlah_rencana >= 0),
    jumlah_aktual      numeric(16,4) NOT NULL CHECK (jumlah_aktual >= 0)
);

CREATE TABLE hasil_produksi (
    hasil_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produksi_id        bigint NOT NULL REFERENCES perintah_produksi(produksi_id),
    stok_produk_id     bigint NOT NULL REFERENCES stok_produk(stok_produk_id),
    jumlah_baik        numeric(14,2) NOT NULL CHECK (jumlah_baik >= 0),
    jumlah_cacat       numeric(14,2) NOT NULL CHECK (jumlah_cacat >= 0),
    tanggal_produksi   timestamp NOT NULL
);

CREATE TABLE parameter_kualitas (
    parameter_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_parameter     varchar(100) NOT NULL UNIQUE,
    satuan             varchar(20) NOT NULL,
    batas_minimum      numeric(14,4) NOT NULL,
    batas_maksimum     numeric(14,4) NOT NULL,
    CHECK (batas_maksimum >= batas_minimum)
);

CREATE TABLE pemeriksaan_kualitas (
    pemeriksaan_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hasil_id           bigint NOT NULL REFERENCES hasil_produksi(hasil_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    tanggal_periksa    timestamp NOT NULL,
    status             varchar(20) NOT NULL CHECK (status IN ('LULUS','GAGAL','OBSERVASI')),
    catatan            text
);

CREATE TABLE hasil_parameter_kualitas (
    pemeriksaan_id     bigint NOT NULL REFERENCES pemeriksaan_kualitas(pemeriksaan_id),
    parameter_id       integer NOT NULL REFERENCES parameter_kualitas(parameter_id),
    nilai_hasil        numeric(14,4) NOT NULL,
    status             varchar(20) NOT NULL CHECK (status IN ('LULUS','GAGAL')),
    PRIMARY KEY (pemeriksaan_id, parameter_id)
);

-- ============================================================
-- 7. PENJUALAN, PENGIRIMAN, DAN PEMBAYARAN
-- ============================================================

CREATE TABLE pelanggan (
    pelanggan_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_pelanggan     varchar(150) NOT NULL UNIQUE,
    email              varchar(150) NOT NULL UNIQUE,
    telepon            varchar(30) NOT NULL,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sales_order (
    sales_order_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pelanggan_id       integer NOT NULL REFERENCES pelanggan(pelanggan_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    tanggal_order      timestamp NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('DRAFT','DIKONFIRMASI','DIKIRIM','SELESAI','DIBATALKAN')),
    total              numeric(18,2) NOT NULL CHECK (total >= 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detail_sales_order (
    detail_so_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sales_order_id     bigint NOT NULL REFERENCES sales_order(sales_order_id),
    produk_id          integer NOT NULL REFERENCES produk(produk_id),
    jumlah             numeric(14,2) NOT NULL CHECK (jumlah > 0),
    harga              numeric(16,2) NOT NULL CHECK (harga > 0),
    subtotal           numeric(18,2) GENERATED ALWAYS AS (jumlah * harga) STORED,
    UNIQUE (sales_order_id, produk_id)
);

CREATE TABLE pengiriman (
    pengiriman_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sales_order_id     bigint NOT NULL REFERENCES sales_order(sales_order_id),
    gudang_id          integer NOT NULL REFERENCES gudang(gudang_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    tanggal_kirim      timestamp NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('DRAFT','DIKIRIM','DITERIMA','DIKEMBALIKAN')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detail_pengiriman (
    detail_pengiriman_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pengiriman_id        bigint NOT NULL REFERENCES pengiriman(pengiriman_id),
    detail_so_id         bigint NOT NULL REFERENCES detail_sales_order(detail_so_id),
    jumlah_dikirim       numeric(14,2) NOT NULL CHECK (jumlah_dikirim >= 0)
);

CREATE TABLE pembayaran (
    pembayaran_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sales_order_id     bigint NOT NULL REFERENCES sales_order(sales_order_id),
    pelanggan_id       integer NOT NULL REFERENCES pelanggan(pelanggan_id),
    jumlah             numeric(18,2) NOT NULL CHECK (jumlah >= 0),
    metode             varchar(30) NOT NULL
                       CHECK (metode IN ('TRANSFER','VIRTUAL_ACCOUNT','KARTU','E_WALLET')),
    tanggal_bayar      timestamp NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('MENUNGGU','BERHASIL','GAGAL','DIKEMBALIKAN')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 8. INDEKS UNTUK ANALISIS OLAP
-- ============================================================

CREATE INDEX idx_produk_kategori ON produk(kategori_id, produk_id);
CREATE INDEX idx_bahan_kategori ON bahan_baku(kategori_bahan_id, bahan_id);
CREATE INDEX idx_supplier_bahan_bahan ON supplier_bahan(bahan_id, supplier_id);
CREATE INDEX idx_po_supplier_tanggal ON purchase_order(supplier_id, tanggal_po, status);
CREATE INDEX idx_dpo_bahan ON detail_purchase_order(bahan_id, po_id);
CREATE INDEX idx_penerimaan_po ON penerimaan_bahan(po_id, tanggal_terima, status);
CREATE INDEX idx_dp_detail_po ON detail_penerimaan(detail_po_id);
CREATE INDEX idx_stok_bahan_bahan_gudang ON stok_bahan(bahan_id, gudang_id);
CREATE INDEX idx_stok_produk_produk_gudang ON stok_produk(produk_id, gudang_id);
CREATE INDEX idx_produksi_produk_tanggal ON perintah_produksi(produk_id, tanggal_mulai, status);
CREATE INDEX idx_produksi_pabrik_tanggal ON perintah_produksi(pabrik_id, tanggal_mulai, status);
CREATE INDEX idx_hasil_tanggal ON hasil_produksi(tanggal_produksi);
CREATE INDEX idx_pemakaian_produksi ON pemakaian_bahan(produksi_id);
CREATE INDEX idx_sales_order_pelanggan_tanggal ON sales_order(pelanggan_id, tanggal_order, status);
CREATE INDEX idx_detail_so_produk ON detail_sales_order(produk_id, sales_order_id);
CREATE INDEX idx_pembayaran_status_tanggal ON pembayaran(status, tanggal_bayar);

-- ============================================================
-- 9. DATA MASTER
-- ============================================================

INSERT INTO negara (nama_negara) VALUES
('Indonesia'),
('Malaysia'),
('Thailand'),
('Vietnam');

INSERT INTO provinsi (nama_provinsi, negara_id) VALUES
('Aceh', 1),
('Jawa Barat', 1),
('Jawa Timur', 1),
('Selangor', 2),
('Bangkok Metropolitan', 3),
('Ho Chi Minh', 4),
('Sumatera Utara', 1),
('Banten', 1);

INSERT INTO kota (nama_kota, provinsi_id) VALUES
('Banda Aceh', 1),
('Meulaboh', 1),
('Bandung', 2),
('Bekasi', 2),
('Surabaya', 3),
('Sidoarjo', 3),
('Shah Alam', 4),
('Petaling Jaya', 4),
('Bangkok', 5),
('Nonthaburi', 5),
('Ho Chi Minh City', 6),
('Thu Duc', 6),
('Medan', 7),
('Tangerang', 8);

INSERT INTO alamat (
    alamat,
    kecamatan,
    kota_id,
    kode_pos,
    telepon
)
SELECT
    'Jalan Industri Nomor ' || g,
    'Kawasan ' || ((g - 1) % 40 + 1),
    ((g - 1) % 14) + 1,
    lpad((13000 + g)::text, 5, '0'),
    '08' || lpad((4000000000 + g)::text, 10, '0')
FROM generate_series(1, 1600) AS g;

INSERT INTO satuan (nama_satuan, simbol) VALUES
('Unit', 'unit'),
('Kilogram', 'kg'),
('Liter', 'l'),
('Meter', 'm');

INSERT INTO kategori_produk (nama, parent_kategori_id)
SELECT 'Kategori Produk ' || lpad(g::text, 2, '0'), NULL
FROM generate_series(1, 8) AS g;

INSERT INTO kategori_bahan (nama, parent_kategori_id)
SELECT 'Kategori Bahan ' || lpad(g::text, 2, '0'), NULL
FROM generate_series(1, 8) AS g;

INSERT INTO produk (
    kategori_id,
    kode_produk,
    nama_produk,
    harga_jual,
    satuan_id,
    aktif
)
SELECT
    ((g - 1) / 10) + 1,
    'PRD-' || lpad(g::text, 4, '0'),
    'Produk Manufaktur ' || lpad(g::text, 3, '0'),
    CASE
        WHEN g = 77 THEN 950000.00
        ELSE (120000 + (g % 20) * 17500)::numeric(16,2)
    END,
    1,
    true
FROM generate_series(1, 80) AS g;

INSERT INTO bahan_baku (
    kategori_bahan_id,
    kode_bahan,
    nama_bahan,
    harga_standar,
    satuan_id,
    aktif
)
SELECT
    ((g - 1) / 10) + 1,
    'BHN-' || lpad(g::text, 4, '0'),
    'Bahan Baku ' || lpad(g::text, 3, '0'),
    CASE
        WHEN g = 66 THEN 220000.00
        ELSE (25000 + (g % 30) * 2500)::numeric(16,2)
    END,
    2,
    true
FROM generate_series(1, 80) AS g;

INSERT INTO bill_of_material (
    produk_id,
    versi,
    tanggal_berlaku,
    aktif
)
SELECT
    produk_id,
    'V1',
    date '2024-01-01',
    true
FROM produk;

-- Setiap produk menggunakan 3 bahan baku.
INSERT INTO detail_bom (
    bom_id,
    bahan_id,
    jumlah,
    satuan_id
)
SELECT
    bom.bom_id,
    1 + ((bom.produk_id + x.offset_bahan - 2) % 80),
    CASE x.offset_bahan
        WHEN 1 THEN 1.20
        WHEN 2 THEN 0.80
        ELSE 0.50
    END,
    2
FROM bill_of_material bom
CROSS JOIN (VALUES (1), (11), (21)) AS x(offset_bahan);

INSERT INTO jabatan (nama_jabatan, level_jabatan) VALUES
('Direktur Operasional', 1),
('Manajer Pabrik', 2),
('Supervisor Produksi', 3),
('Supervisor Gudang', 3),
('Staf Pembelian', 4),
('Staf Produksi', 4),
('Staf QC', 4),
('Staf Penjualan', 4);

INSERT INTO pabrik (
    nama_pabrik,
    alamat_id,
    aktif
)
SELECT
    'Pabrik Regional ' || lpad(g::text, 2, '0'),
    10 + g,
    true
FROM generate_series(1, 5) AS g;

INSERT INTO pegawai (
    pabrik_id,
    atasan_id,
    nama_depan,
    nama_belakang,
    jabatan_id,
    alamat_id,
    email,
    aktif,
    tanggal_masuk
)
SELECT
    ((g - 1) % 5) + 1,
    NULL,
    'Pegawai',
    lpad(g::text, 3, '0'),
    CASE WHEN g <= 5 THEN 2 ELSE 4 + (g % 4) END,
    100 + g,
    'pegawai' || g || '@manufaktur.id',
    true,
    CURRENT_DATE - ((400 + g * 9) || ' days')::interval
FROM generate_series(1, 60) AS g;

UPDATE pegawai p
SET atasan_id = (
    SELECT MIN(m.pegawai_id)
    FROM pegawai m
    WHERE m.pabrik_id = p.pabrik_id
      AND m.pegawai_id <> p.pegawai_id
)
WHERE p.pegawai_id > 5;

UPDATE pabrik p
SET manager_pegawai_id = (
    SELECT MIN(pg.pegawai_id)
    FROM pegawai pg
    WHERE pg.pabrik_id = p.pabrik_id
);

-- Gudang bahan dan produk untuk setiap pabrik.
INSERT INTO gudang (
    pabrik_id,
    nama_gudang,
    jenis_gudang,
    alamat_id,
    aktif
)
SELECT
    p,
    'Gudang Bahan Pabrik ' || p,
    'BAHAN',
    200 + p,
    true
FROM generate_series(1, 5) AS p
UNION ALL
SELECT
    p,
    'Gudang Produk Pabrik ' || p,
    'PRODUK',
    210 + p,
    true
FROM generate_series(1, 5) AS p;

-- Setiap gudang bahan menyimpan 80 bahan.
INSERT INTO stok_bahan (
    bahan_id,
    gudang_id,
    jumlah,
    stok_minimum
)
SELECT
    b,
    g,
    CASE
        WHEN ((b + g) % 7) IN (0, 1) THEN 80
        ELSE 250 + ((b * 11 + g * 5) % 600)
    END,
    100
FROM generate_series(1, 80) AS b
CROSS JOIN generate_series(1, 5) AS g;

-- Setiap gudang produk menyimpan 80 produk.
INSERT INTO stok_produk (
    produk_id,
    gudang_id,
    jumlah,
    stok_minimum
)
SELECT
    p,
    g,
    50 + ((p * 7 + g * 3) % 300),
    40
FROM generate_series(1, 80) AS p
CROSS JOIN generate_series(6, 10) AS g;

INSERT INTO supplier (
    nama_supplier,
    email,
    telepon,
    alamat_id,
    aktif
)
SELECT
    'Supplier Material ' || lpad(g::text, 2, '0'),
    'supplier' || g || '@supply.id',
    '021' || lpad((8000000 + g)::text, 7, '0'),
    300 + g,
    true
FROM generate_series(1, 24) AS g;

-- Supplier 1-5 memasok bahan 1-20, agar menjadi top supplier
-- dan bahan yang mereka pasok bisa dikeluarkan pada soal NOT EXISTS.
INSERT INTO supplier_bahan (
    supplier_id,
    bahan_id,
    harga_beli,
    minimum_order,
    lead_time_hari
)
SELECT
    s,
    b,
    round((bb.harga_standar * (0.90 + (s % 4) * 0.03))::numeric, 2),
    50,
    3 + (s % 7)
FROM generate_series(1, 5) AS s
CROSS JOIN generate_series(1, 20) AS b
JOIN bahan_baku bb ON bb.bahan_id = b
UNION ALL
SELECT
    s,
    b,
    round((bb.harga_standar * (0.92 + (s % 5) * 0.025))::numeric, 2),
    40,
    4 + (s % 8)
FROM generate_series(6, 24) AS s
CROSS JOIN generate_series(21, 80) AS b
JOIN bahan_baku bb ON bb.bahan_id = b
WHERE ((b + s) % 7) IN (0, 1, 2)
ON CONFLICT (supplier_id, bahan_id) DO NOTHING;

-- Tambahan agar setiap supplier punya minimal lima bahan.
INSERT INTO supplier_bahan (
    supplier_id,
    bahan_id,
    harga_beli,
    minimum_order,
    lead_time_hari
)
SELECT
    s,
    21 + ((s * 3 + x) % 60),
    round((bb.harga_standar * (0.95 + (x % 3) * 0.02))::numeric, 2),
    35,
    5
FROM generate_series(6, 24) AS s
CROSS JOIN generate_series(0, 4) AS x
JOIN bahan_baku bb ON bb.bahan_id = 21 + ((s * 3 + x) % 60)
ON CONFLICT (supplier_id, bahan_id) DO NOTHING;

INSERT INTO parameter_kualitas (
    nama_parameter,
    satuan,
    batas_minimum,
    batas_maksimum
) VALUES
('Dimensi', 'mm', 9.5000, 10.5000),
('Berat', 'kg', 0.9000, 1.1000),
('Kadar Cacat Visual', '%', 0.0000, 2.0000);

INSERT INTO pelanggan (
    nama_pelanggan,
    email,
    telepon,
    alamat_id,
    aktif
)
SELECT
    'Pelanggan Industri ' || lpad(g::text, 3, '0'),
    'pelanggan' || g || '@buyer.id',
    '022' || lpad((9000000 + g)::text, 7, '0'),
    600 + g,
    true
FROM generate_series(1, 300) AS g;

-- ============================================================
-- 10. DATA PURCHASE ORDER DAN PENERIMAAN 15 BULAN
-- ============================================================

DO $$
DECLARE
    v_month_start       date := (date_trunc('month', CURRENT_DATE)::date - interval '14 months')::date;
    v_po_id             bigint;
    v_detail_po_id      bigint;
    v_receipt_id        bigint;
    v_supplier          integer;
    v_bahan             integer;
    v_gudang            integer;
    v_pegawai           integer;
    v_qty               numeric(14,2);
    v_price             numeric(16,2);
    v_total             numeric(18,2);
    v_po_date           timestamp;
    v_received          numeric(14,2);
    v_damaged           numeric(14,2);
    m                   integer;
    s                   integer;
    j                   integer;
BEGIN
    FOR m IN 0..14 LOOP
        -- Supplier 1-5 bernilai PO besar.
        FOR s IN 1..5 LOOP
            FOR j IN 1..3 LOOP
                v_supplier := s;
                v_bahan := 1 + ((s * 3 + m + j) % 20);
                v_gudang := 1 + ((s + j + m) % 5);
                v_pegawai := 1 + ((v_gudang - 1) % 5);
                v_qty := 180 + s * 20 + j * 15;
                SELECT harga_beli * (1 + m * 0.006)
                INTO v_price
                FROM supplier_bahan
                WHERE supplier_id = v_supplier
                  AND bahan_id = v_bahan;

                v_price := round(v_price, 2);
                v_total := v_qty * v_price;
                v_po_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((2 + j + s) || ' days')::interval
                    + interval '09 hours';

                INSERT INTO purchase_order (
                    supplier_id,
                    pegawai_id,
                    gudang_id,
                    tanggal_po,
                    status,
                    total
                )
                VALUES (
                    v_supplier,
                    v_pegawai,
                    v_gudang,
                    v_po_date,
                    'SELESAI',
                    v_total
                )
                RETURNING po_id INTO v_po_id;

                INSERT INTO detail_purchase_order (
                    po_id,
                    bahan_id,
                    jumlah,
                    harga
                )
                VALUES (
                    v_po_id,
                    v_bahan,
                    v_qty,
                    v_price
                )
                RETURNING detail_po_id INTO v_detail_po_id;

                INSERT INTO penerimaan_bahan (
                    po_id,
                    pegawai_id,
                    tanggal_terima,
                    nomor_dokumen,
                    status
                )
                VALUES (
                    v_po_id,
                    v_pegawai,
                    v_po_date + interval '5 days',
                    'RCV-TOP-' || m || '-' || s || '-' || j,
                    'DIVERIFIKASI'
                )
                RETURNING penerimaan_id INTO v_receipt_id;

                v_received := CASE WHEN (s + m + j) % 8 = 0 THEN v_qty - 20 ELSE v_qty END;
                v_damaged := CASE WHEN (s + m + j) % 6 = 0 THEN 6 ELSE 2 END;

                INSERT INTO detail_penerimaan (
                    penerimaan_id,
                    detail_po_id,
                    jumlah_diterima,
                    jumlah_rusak
                )
                VALUES (
                    v_receipt_id,
                    v_detail_po_id,
                    v_received,
                    v_damaged
                );
            END LOOP;
        END LOOP;

        -- Supplier 6-24 untuk bahan 21-80, mendukung evaluasi per negara.
        FOR s IN 6..24 LOOP
            v_supplier := s;
            v_gudang := 1 + ((s + m) % 5);
            v_pegawai := 1 + ((v_gudang - 1) % 5);

            FOR j IN 1..1 LOOP
                SELECT sb.bahan_id
                INTO v_bahan
                FROM supplier_bahan sb
                WHERE sb.supplier_id = v_supplier
                ORDER BY ((sb.bahan_id + m + j) % 100), sb.bahan_id
                LIMIT 1;

                v_qty := 70 + ((s + m) % 6) * 15;

                SELECT harga_beli * (1 + CASE
                    WHEN s IN (8, 13, 18, 23) THEN m * 0.002
                    ELSE m * 0.008
                END)
                INTO v_price
                FROM supplier_bahan
                WHERE supplier_id = v_supplier
                  AND bahan_id = v_bahan;

                v_price := round(v_price, 2);
                v_total := v_qty * v_price;
                v_po_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((10 + (s % 12)) || ' days')::interval
                    + interval '10 hours';

                INSERT INTO purchase_order (
                    supplier_id,
                    pegawai_id,
                    gudang_id,
                    tanggal_po,
                    status,
                    total
                )
                VALUES (
                    v_supplier,
                    v_pegawai,
                    v_gudang,
                    v_po_date,
                    'SELESAI',
                    v_total
                )
                RETURNING po_id INTO v_po_id;

                INSERT INTO detail_purchase_order (
                    po_id,
                    bahan_id,
                    jumlah,
                    harga
                )
                VALUES (
                    v_po_id,
                    v_bahan,
                    v_qty,
                    v_price
                )
                RETURNING detail_po_id INTO v_detail_po_id;

                INSERT INTO penerimaan_bahan (
                    po_id,
                    pegawai_id,
                    tanggal_terima,
                    nomor_dokumen,
                    status
                )
                VALUES (
                    v_po_id,
                    v_pegawai,
                    v_po_date + ((3 + (s % 4)) || ' days')::interval,
                    'RCV-REG-' || m || '-' || s || '-' || j,
                    'DIVERIFIKASI'
                )
                RETURNING penerimaan_id INTO v_receipt_id;

                v_received := CASE
                    WHEN s IN (8, 13, 18, 23) THEN v_qty
                    WHEN (s + m) % 5 = 0 THEN v_qty - 10
                    ELSE v_qty
                END;

                v_damaged := CASE
                    WHEN s IN (8, 13, 18, 23) THEN 1
                    WHEN (s + m) % 4 = 0 THEN 5
                    ELSE 2
                END;

                INSERT INTO detail_penerimaan (
                    penerimaan_id,
                    detail_po_id,
                    jumlah_diterima,
                    jumlah_rusak
                )
                VALUES (
                    v_receipt_id,
                    v_detail_po_id,
                    v_received,
                    v_damaged
                );
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 11. DATA PRODUKSI 15 BULAN
-- ============================================================

DO $$
DECLARE
    v_month_start       date := (date_trunc('month', CURRENT_DATE)::date - interval '14 months')::date;
    v_prod_id           bigint;
    v_hasil_id          bigint;
    v_check_id          bigint;
    v_produk            integer;
    v_bom               integer;
    v_pabrik            integer;
    v_gudang_bahan      integer;
    v_gudang_produk     integer;
    v_stok_bahan        bigint;
    v_stok_produk       bigint;
    v_good              numeric(14,2);
    v_bad               numeric(14,2);
    v_target            numeric(14,2);
    v_plan              numeric(16,4);
    v_actual            numeric(16,4);
    v_date              timestamp;
    m                   integer;
    p                   integer;
    b                   record;
BEGIN
    FOR m IN 0..14 LOOP
        FOR p IN 1..80 LOOP
            v_produk := p;
            v_pabrik := 1 + ((p + m) % 5);

            -- Pabrik 5 tidak produksi pada dua bulan, agar soal
            -- bulan kosong tetap dapat diuji.
            IF v_pabrik = 5 AND m IN (4, 9) THEN
                CONTINUE;
            END IF;

            SELECT bom_id
            INTO v_bom
            FROM bill_of_material
            WHERE produk_id = v_produk
              AND aktif = true
            ORDER BY bom_id
            LIMIT 1;

            v_gudang_bahan := v_pabrik;
            v_gudang_produk := v_pabrik + 5;

            v_good := CASE
                WHEN v_produk = 77 THEN 190 + (m % 4) * 10
                WHEN v_produk IN (1,11,21,31,41,51,61,71) THEN 130 + (m % 5) * 7
                ELSE 55 + ((p * 3 + m * 5) % 50)
            END;

            v_bad := CASE
                WHEN v_pabrik = 3 AND m IN (10, 11) THEN round(v_good * 0.18, 2)
                WHEN (p + m) % 17 = 0 THEN round(v_good * 0.09, 2)
                ELSE round(v_good * 0.025, 2)
            END;

            v_target := v_good + v_bad;
            v_date :=
                v_month_start
                + (m || ' months')::interval
                + ((2 + (p % 24)) || ' days')::interval
                + interval '08 hours';

            INSERT INTO perintah_produksi (
                produk_id,
                bom_id,
                pabrik_id,
                tanggal_mulai,
                tanggal_selesai,
                target_jumlah,
                status
            )
            VALUES (
                v_produk,
                v_bom,
                v_pabrik,
                v_date,
                v_date + interval '2 days',
                v_target,
                'SELESAI'
            )
            RETURNING produksi_id INTO v_prod_id;

            SELECT stok_produk_id
            INTO v_stok_produk
            FROM stok_produk
            WHERE produk_id = v_produk
              AND gudang_id = v_gudang_produk;

            INSERT INTO hasil_produksi (
                produksi_id,
                stok_produk_id,
                jumlah_baik,
                jumlah_cacat,
                tanggal_produksi
            )
            VALUES (
                v_prod_id,
                v_stok_produk,
                v_good,
                v_bad,
                v_date + interval '2 days'
            )
            RETURNING hasil_id INTO v_hasil_id;

            FOR b IN
                SELECT db.bahan_id, db.jumlah
                FROM detail_bom db
                WHERE db.bom_id = v_bom
            LOOP
                SELECT stok_bahan_id
                INTO v_stok_bahan
                FROM stok_bahan
                WHERE bahan_id = b.bahan_id
                  AND gudang_id = v_gudang_bahan;

                v_plan := b.jumlah * v_target;
                v_actual := v_plan * CASE
                    WHEN v_produk = 66 THEN 1.35
                    WHEN v_produk IN (1,11,21,31,41,51,61,71) THEN 1.18
                    WHEN (v_produk + m) % 9 = 0 THEN 1.12
                    ELSE 1.04
                END;

                INSERT INTO pemakaian_bahan (
                    produksi_id,
                    stok_bahan_id,
                    jumlah_rencana,
                    jumlah_aktual
                )
                VALUES (
                    v_prod_id,
                    v_stok_bahan,
                    round(v_plan, 4),
                    round(v_actual, 4)
                );
            END LOOP;

            INSERT INTO pemeriksaan_kualitas (
                hasil_id,
                pegawai_id,
                tanggal_periksa,
                status,
                catatan
            )
            VALUES (
                v_hasil_id,
                10 + ((v_pabrik - 1) % 5),
                v_date + interval '3 days',
                CASE WHEN v_bad / NULLIF(v_good + v_bad, 0) > 0.10 THEN 'OBSERVASI' ELSE 'LULUS' END,
                'Pemeriksaan kualitas produksi'
            )
            RETURNING pemeriksaan_id INTO v_check_id;

            INSERT INTO hasil_parameter_kualitas (
                pemeriksaan_id,
                parameter_id,
                nilai_hasil,
                status
            )
            VALUES
            (v_check_id, 1, 10.0000 + ((p + m) % 5) * 0.0500, 'LULUS'),
            (v_check_id, 2, 1.0000 + ((p + m) % 4) * 0.0100, 'LULUS'),
            (v_check_id, 3, round((v_bad / NULLIF(v_good + v_bad, 0) * 100)::numeric, 4),
                CASE WHEN v_bad / NULLIF(v_good + v_bad, 0) > 0.10 THEN 'GAGAL' ELSE 'LULUS' END);
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 12. DATA PENJUALAN, PENGIRIMAN, DAN PEMBAYARAN 15 BULAN
-- ============================================================

DO $$
DECLARE
    v_month_start       date := (date_trunc('month', CURRENT_DATE)::date - interval '14 months')::date;
    v_so_id             bigint;
    v_detail_id         bigint;
    v_ship_id           bigint;
    v_produk            integer;
    v_customer          integer;
    v_pegawai           integer;
    v_gudang_produk     integer;
    v_qty               numeric(14,2);
    v_price             numeric(16,2);
    v_total             numeric(18,2);
    v_date              timestamp;
    m                   integer;
    p                   integer;
    c                   integer;
    j                   integer;
BEGIN
    -- Penjualan dasar seluruh produk setiap bulan.
    FOR m IN 0..14 LOOP
        FOR p IN 1..80 LOOP
            v_produk := p;
            v_customer := 11 + ((p * 7 + m * 13) % 290);
            v_pegawai := 30 + ((p + m) % 20);
            v_gudang_produk := 6 + ((p + m) % 5);
            v_qty := CASE
                WHEN p = 77 THEN 45
                ELSE 5 + ((p + m) % 8)
            END;

            SELECT harga_jual
            INTO v_price
            FROM produk
            WHERE produk_id = v_produk;

            v_price := round((v_price * (0.94 + ((p + m) % 4) * 0.03))::numeric, 2);
            v_total := v_qty * v_price;
            v_date :=
                v_month_start
                + (m || ' months')::interval
                + ((3 + (p % 24)) || ' days')::interval
                + interval '11 hours';

            INSERT INTO sales_order (
                pelanggan_id,
                pegawai_id,
                tanggal_order,
                status,
                total
            )
            VALUES (
                v_customer,
                v_pegawai,
                v_date,
                'SELESAI',
                v_total
            )
            RETURNING sales_order_id INTO v_so_id;

            INSERT INTO detail_sales_order (
                sales_order_id,
                produk_id,
                jumlah,
                harga
            )
            VALUES (
                v_so_id,
                v_produk,
                v_qty,
                v_price
            )
            RETURNING detail_so_id INTO v_detail_id;

            INSERT INTO pengiriman (
                sales_order_id,
                gudang_id,
                pegawai_id,
                tanggal_kirim,
                status
            )
            VALUES (
                v_so_id,
                v_gudang_produk,
                v_pegawai,
                v_date + interval '2 days',
                'DITERIMA'
            )
            RETURNING pengiriman_id INTO v_ship_id;

            INSERT INTO detail_pengiriman (
                pengiriman_id,
                detail_so_id,
                jumlah_dikirim
            )
            VALUES (
                v_ship_id,
                v_detail_id,
                v_qty
            );

            INSERT INTO pembayaran (
                sales_order_id,
                pelanggan_id,
                jumlah,
                metode,
                tanggal_bayar,
                status
            )
            VALUES (
                v_so_id,
                v_customer,
                v_total,
                CASE (v_so_id % 4)
                    WHEN 0 THEN 'TRANSFER'
                    WHEN 1 THEN 'VIRTUAL_ACCOUNT'
                    WHEN 2 THEN 'KARTU'
                    ELSE 'E_WALLET'
                END,
                v_date + interval '1 day',
                'BERHASIL'
            );
        END LOOP;
    END LOOP;

    -- Pelanggan 1-10 menjadi pelanggan dengan pembayaran terbesar,
    -- tetapi tidak pernah membeli produk 77.
    FOR m IN 0..14 LOOP
        FOR c IN 1..10 LOOP
            FOR j IN 1..2 LOOP
                v_produk := 1 + ((c * 2 + m + j) % 20);
                v_customer := c;
                v_pegawai := 30 + ((c + j) % 20);
                v_gudang_produk := 6 + ((c + j + m) % 5);
                v_qty := 80 + c * 2;

                SELECT harga_jual
                INTO v_price
                FROM produk
                WHERE produk_id = v_produk;

                v_price := round((v_price * 1.10)::numeric, 2);
                v_total := v_qty * v_price;
                v_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((2 + c + j) || ' days')::interval
                    + interval '15 hours';

                INSERT INTO sales_order (
                    pelanggan_id,
                    pegawai_id,
                    tanggal_order,
                    status,
                    total
                )
                VALUES (
                    v_customer,
                    v_pegawai,
                    v_date,
                    'SELESAI',
                    v_total
                )
                RETURNING sales_order_id INTO v_so_id;

                INSERT INTO detail_sales_order (
                    sales_order_id,
                    produk_id,
                    jumlah,
                    harga
                )
                VALUES (
                    v_so_id,
                    v_produk,
                    v_qty,
                    v_price
                )
                RETURNING detail_so_id INTO v_detail_id;

                INSERT INTO pengiriman (
                    sales_order_id,
                    gudang_id,
                    pegawai_id,
                    tanggal_kirim,
                    status
                )
                VALUES (
                    v_so_id,
                    v_gudang_produk,
                    v_pegawai,
                    v_date + interval '1 day',
                    'DITERIMA'
                )
                RETURNING pengiriman_id INTO v_ship_id;

                INSERT INTO detail_pengiriman (
                    pengiriman_id,
                    detail_so_id,
                    jumlah_dikirim
                )
                VALUES (
                    v_ship_id,
                    v_detail_id,
                    v_qty
                );

                INSERT INTO pembayaran (
                    sales_order_id,
                    pelanggan_id,
                    jumlah,
                    metode,
                    tanggal_bayar,
                    status
                )
                VALUES (
                    v_so_id,
                    v_customer,
                    v_total,
                    'VIRTUAL_ACCOUNT',
                    v_date + interval '2 hours',
                    'BERHASIL'
                );
            END LOOP;
        END LOOP;
    END LOOP;

    -- Contoh pembayaran gagal dan order dibatalkan sebagai data pembanding.
    FOR m IN 0..14 LOOP
        v_produk := 30 + (m % 15);
        v_customer := 200 + (m % 80);
        v_pegawai := 40;
        v_gudang_produk := 6 + (m % 5);
        v_qty := 3;

        SELECT harga_jual INTO v_price FROM produk WHERE produk_id = v_produk;
        v_total := v_qty * v_price;
        v_date :=
            v_month_start
            + (m || ' months')::interval
            + interval '25 days';

        INSERT INTO sales_order (
            pelanggan_id,
            pegawai_id,
            tanggal_order,
            status,
            total
        )
        VALUES (
            v_customer,
            v_pegawai,
            v_date,
            'DIBATALKAN',
            v_total
        )
        RETURNING sales_order_id INTO v_so_id;

        INSERT INTO detail_sales_order (
            sales_order_id,
            produk_id,
            jumlah,
            harga
        )
        VALUES (
            v_so_id,
            v_produk,
            v_qty,
            v_price
        );

        INSERT INTO pembayaran (
            sales_order_id,
            pelanggan_id,
            jumlah,
            metode,
            tanggal_bayar,
            status
        )
        VALUES (
            v_so_id,
            v_customer,
            v_total,
            'KARTU',
            v_date + interval '1 hour',
            'GAGAL'
        );
    END LOOP;
END $$;

ANALYZE;

-- ============================================================
-- 13. RINGKASAN POLA DATA
-- ============================================================
-- Tabel utama:
--   negara               : 4
--   pabrik               : 5
--   gudang               : 10, terdiri dari 5 gudang bahan
--                          dan 5 gudang produk
--   produk               : 80 produk, 8 kategori, masing-masing 10
--   bahan_baku           : 80 bahan, 8 kategori, masing-masing 10
--   supplier             : 24 supplier
--   pelanggan            : 300 pelanggan
--   periode data         : 15 bulan
--
-- Pola analitik:
--   * Produk 77 memiliki pendapatan penjualan tinggi, tetapi tidak
--     pernah dibeli pelanggan 1-10.
--   * Pelanggan 1-10 menjadi pelanggan dengan pembayaran berhasil
--     terbesar.
--   * Supplier 1-5 memiliki nilai purchase order terbesar dan hanya
--     memasok bahan 1-20.
--   * Bahan 66 memiliki pemakaian aktual tinggi dan tidak dipasok
--     oleh supplier 1-5.
--   * Setiap kategori produk memiliki minimal 10 produk yang diproduksi
--     per bulan, sehingga analisis persentil valid.
--   * Produk 1, 11, 21, 31, 41, 51, 61, dan 71 memiliki rasio pemakaian
--     bahan tinggi pada banyak bulan.
--   * Pabrik 5 tidak memiliki produksi pada dua bulan tertentu.
--   * Pabrik 3 memiliki lonjakan tingkat cacat pada beberapa bulan.
--   * Supplier 8, 13, 18, dan 23 dirancang sebagai supplier berperforma
--     kuat pada negara masing-masing.
--
-- Filter transaksi valid yang disarankan:
--   purchase_order.status = 'SELESAI'
--   penerimaan_bahan.status = 'DIVERIFIKASI'
--   perintah_produksi.status = 'SELESAI'
--   sales_order.status = 'SELESAI'
--   pembayaran.status = 'BERHASIL'
-- ============================================================
