use master
create database QLBH
on primary
(name=QLBH_Data,
filename= 'T:\QLBH_Data.mdf',
size=10mb,
maxsize=40mb,
filegrowth=1mb)
log on
(name=QLBH_Log,
filename= 'T:\QLBH_Log.idf',
size=6mb,
maxsize=8mb,
filegrowth=1mb)

use QLBH
create table KhachHang
(MaKH char(5) not null primary key,
TenKH nvarchar(40) not null,
LoaiKH nvarchar(3),
check (LoaiKH in ('VIP','TV','VL')),
DiaChi nvarchar(60),
Phone nvarchar(24),
DCMail nvarchar(50),
DiemTL int)

create table NhomSanPham
(MaNhom int not null,
TenNhom nvarchar(15))

create table NhaCungCap
(MaNCC int not null,
TenNCC nvarchar(40) not null,
DiaChi nvarchar(60),
Phone nvarchar(24),
SoFax nvarchar(24),
DCMail nvarchar(50))

create table SanPham
(MaSP int not null,
TenSP nvarchar(40) not null,
MaNCC int,
MoTa nvarchar(50),
MaNhom int,
Donvitinh nvarchar(20))

create table HoaDon
(MaHD int not null,
NgayLapHD datetime,
NgayGiao datetime,
NoiChuyen nvarchar(60),
MaKH char(5))

create table CT_HoaDon
(MaHD int not null,
MaSP int not null,
SoLuong smallint,
DonGia money,
ChietKhau money)

alter table NhomSanPham
add primary key(MaNhom)

alter table NhaCungCap
add primary key(MaNCC)

alter table SanPham
add primary key(MaSP),
foreign key(MaNCC) references NhaCungCap(MaNCC)

alter table HoaDon
add primary key(MaHD),
check (NgayLapHD >= getdate()),
default getdate() for NgayLapHD,
foreign key(MaKH) references KhachHang(MaKH)

alter table CT_HoaDon
add primary key(MaHD,MaSP),
check(SoLuong>0),
check(ChietKhau>=0),
foreign key(MaHD) references HoaDon(MaHD),
foreign key(MaSP) references SanPham(MaSP)

alter table HoaDon
add LoaiHD char(1) default 'N'
check (LoaiHD in ('N','X','C','T'))

alter table HoaDon
add check(NgayGiao>=NgayLapHD)

alter table SanPham
add GiaGoc int
alter table SanPham
add Slton int
alter table KhachHang
add SoFax int

alter table SanPham
add foreign key(MaNhom) references NhomSanPham(MaNhom)
go
insert NhomSanPham values (1,N'Điện Tử')
insert NhomSanPham(MaNhom,TenNhom) values (2,N'Gia Dụng'),
(3,N'DụngCụGiaĐình'),(4,N'CácMặtHàngKhác')
go
insert NhaCungCap(MaNCC,TenNCC,DiaChi,Phone,SoFax,DCMail) 
values (1,N'Công ty TNHH Nam Phương',N'1 Lê Lợi Phường 4 Quận Gò Vấp',083843456,4353434,N'NamPhuong@yahoo.com'),
(2,N'Công Ty Lan Ngọc',N'12 Cao Bá Quát Quận 1 Tp.Hồ Chí Minh',086234567,83434355,N'LanNgoc@gmail.com')
go
insert SanPham([MaSP],[TenSP],[Donvitinh],[GiaGoc],[Slton],[MaNhom],[MaNCC],[MoTa])
values (1,N'Máy tính',N'Cái',70000000,100,1,1,N'Máy Sony Ram 2GB')
insert SanPham([MaSP],[TenSP],[Donvitinh],[GiaGoc],[Slton],[MaNhom],[MaNCC],[MoTa])
values (2,N'Bàn Phím',N'Cái',10000000,50,1,1,N'Bàn Phím 101 Phím'),
(3,N'Chuột',N'Cái',8000000,150,1,1,N'Chuột không dây'),
(4,N'CPU',N'Cái',30000000,200,1,1,N'CPU'),
(5,N'USB',N'Cái',5000000,100,1,1,N'8GB')
insert SanPham([MaSP],[TenSP],[Donvitinh],[GiaGoc],[Slton],[MaNhom],[MaNCC])
values (6,N'Lò Vi Sóng',N'Cái',10000000,20,3,2)
go
insert KhachHang([MaKH],[TenKH],[DiaChi],[LoaiKH])
values (N'KH1',N'Nguyễn Thu Hằng',N'12 Nguyễn Du',N'VL')
insert KhachHang([MaKH],[TenKH],[DiaChi],[Phone],[LoaiKH],[DCMail],[DiemTL])
values (N'KH2',N'Lê Minh',N'34 Điện Biên Phủ',0123943455,N'TV',N'LeMinh@yahoo.com',100),
(N'KH3',N'Nguyễn Minh Trung',N'3 Lê Lợi Quận Gò Vấp',098343434,N'VIP',N'Trung@gmail.com',800)
go
insert HoaDon([MaHD],[NgayLapHD],[MaKH],[NgayGiao],[NoiChuyen])
values (1,'2024/09/30',N'KH1','2024/10/05',N'Cửa Hàng ABC 3 Lý Chính Thắng Quận 3')
insert HoaDon([MaHD],[NgayLapHD],[MaKH],[NgayGiao],[NoiChuyen])
values (2,'2024/07/29',N'KH2','2024/08/10',N'23 Lê Lợi Quận Gò Vấp'),
(3,'2024/10/01',N'KH3','2024/10/02',N'2 Nguyễn Du Quận Gò Vấp')
go
insert CT_HoaDon([MaHD],[MaSP],[DonGia],[SoLuong])
values (1,1,80000000,5)
insert CT_HoaDon([MaHD],[MaSP],[DonGia],[SoLuong])
values (1,2,12000000,4)
insert CT_HoaDon([MaHD],[MaSP],[DonGia],[SoLuong])
values (1,3,10000000,15)
insert CT_HoaDon([MaHD],[MaSP],[DonGia],[SoLuong])
values (2,2,12000000,9)
insert CT_HoaDon([MaHD],[MaSP],[DonGia],[SoLuong])
values(2,4,8000000,5)
insert CT_HoaDon([MaHD],[MaSP],[DonGia],[SoLuong])
values(3,2,35000000,20)
insert CT_HoaDon([MaHD],[MaSP],[DonGia],[SoLuong])
values (3,3,10000000,15)
select [MaHD],[MaSP],[DonGia],[SoLuong]
from CT_HoaDon
--2--
--a--
update CT_HoaDon
set DonGia= DonGia*(5/100) where MaSP=2
--b--
update SanPham
set Slton = Slton + 100 where MaNhom=3 and MaNCC=2
--c--
update SanPham
set MoTa = N'Khong co gi' where TenSP=N'Lò Vi Sóng'
--d--
alter table [dbo].[HoaDon]
drop constraint [FK__HoaDon__MaKH__30F848ED]
alter table [dbo].[HoaDon]
add foreign key ([MaKH]) references KhachHang([MaKH])
on delete cascade
on update cascade
update KhachHang
set MaKH =N'VI003' where MaKH =N'KH3'
--e--
update KhachHang
set MaKH =N'VL001' where MaKH =N'KH1'
update KhachHang
set MaKH =N'T0002' where MaKH =N'KH2'
--3--
alter table [dbo].[CT_HoaDon]
drop constraint [FK__CT_HoaDon__MaHD__34C8D9D1]
alter table [dbo].[CT_HoaDon]
add foreign key ([MaHD]) references HoaDon([MaHD])
on delete cascade
on update cascade
--a--
delete from NhomSanPham where MaNhom=4
--b--
delete from CT_HoaDon where MaHD =1 and MaSP =3
--c--
delete from HoaDon where MaHD =1
--d--
delete from CT_HoaDon where MaHD =2