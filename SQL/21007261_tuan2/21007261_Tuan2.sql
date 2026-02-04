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
3.
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
go
--bai2--
create database Movies
on primary
(name=Movies_Data,
filename= 'C:\Movies\Movies_Data.mdf',
size=25mb,
maxsize=40mb,
filegrowth=1mb)
log on
(name=Movies_Log,
filename= 'C:\Movies\Movies_Log.idf',
size=6mb,
maxsize=8mb,
filegrowth=1mb)
go

use Movies

alter database Movies
add file(name=Movies_data2,
filename='C:\Movies\Movies_data2.ndf',
size=10mb)

alter database Movies set single_user
alter database Movies set  restricted_user
alter database Movies set  multi_user
alter database Movies
modify file(NAME='Movies_data2',size=15mb) 
alter database Movies set auto_shrink on;
--bai2.4--
exec sp_addtype Movie_num,'int',Null
exec sp_addtype Category_num,'int',Null
exec sp_addtype Cust_num,'int',NULL
exec sp_addtype Invoices_num,'int',Null
go
exec sp_help
create table Customer
(Cust_num Cust_num not null,
Lname varchar(20) not null,
Fname varchar(20) not null,
Address1 varchar(20) null,
Address2 varchar(20) null)

alter table Customer ADD
City varchar(20) null,
State char(20) null,Zip char(10) null
go
alter table Customer ADD
Phone varchar(10) not null,
Join_date smalldatetime not null
go 
alter table Customer ADD
Cust_num Cust_num IDENTITY(300,1) not null
go
create table Category_num 
(Category_num Category_num IDENTITY(1,1) not null)
alter table Category_num add
Description varchar(20) not null

create table Movie
(Movie_num Movie_num not null,
Title Cust_num not null,
Category_Num Category_num not null,
Date_purch smalldatetime null,
Rental_price int null,
Rating char(5) null)

create table Rental
(Invoice_num Invoices_num not null,
Cust_num Cust_num not null,
Rental_date smalldatetime not null,
Due_date smalldatetime not null)

create table Rental_Detail
(Invoice_num Invoices_num not null,
Line_num int not null,
Movie_num Movie_num not null,
Rental_price smallmoney not null)

--2.9--
alter table Movie 
add constraint PK_movie primary key (Movie_num)
alter table Customer 
add constraint PK_customer primary key(Cust_num)
alter table Category_num
add constraint PK_category primary key(Category_num)
alter table Rental
add constraint PK_rental primary key(Invoice_num)
--2.10--
alter table Movie
add constraint FK_movie foreign key(Category_num) 
references Category_num(Category_num)

alter table Rental
add constraint FK_rental foreign key(Cust_num) 
references Customer(Cust_num)

alter table Rental_detail
add constraint FK_detail_invoice foreign key(Invoice_num) 
references Rental(Invoice_num)

alter table Rental_detail drop constraint FK_detail_invoice

alter table Rental_detail
add constraint FK_detail_invoice foreign key(Movie_num) 
references Movie(Movie_num)
--2.12--
alter table Movie
add constraint DK_movie_date_purch check(Date_purch = getdate())
alter table Customer
add constraint DK_customer_join_date check(join_date = getdate())
alter table Rental
add constraint DK_rental_rental_date check(Rental_date = getdate())
alter table Rental
add constraint DK_rental_due_date check(Due_date = getdate()+2)
2.13
alter table Movie
add constraint CK_movie check( Rating in ('G','PG','R','NC17','NR'))

alter table Rental
add constraint CK_Due_date check( Due_date>=Rental_date)