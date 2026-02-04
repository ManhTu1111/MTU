--I.
--2.Sử  dụng T-SQL  tạo  một cơ sở dữ  liệu  mới tên  SmallWorks, 
--với 2 file group tên SWUserData1 và SWUserData2, lưu theo đường dẫn T:\HoTen\TenTapTin.
create database SmallWorks
on primary
(
	name = 'SmallWorkPrimary',
	filename = 'D:\HoTen\SmallWorksData1.mdf',
	size = 10mb,
	filegrowth = 20%,
	maxsize = 50mb
),

filegroup SWUserData1
(
	name = 'SmallWorkData1',
	filename = 'D:\HoTen\SmallWorksData1.ndf',
	size = 10mb,
	filegrowth = 20%,
	maxsize = 50mb
),

filegroup SWUserData2
(
	name = 'SmallWorkData2',
	filename = 'D:\HoTen\SmallWorksData2.ndf',
	size = 10mb,
	filegrowth = 20%,
	maxsize = 50mb
)
log on
(
	name = 'SmallWorks_log',
	filename = 'D:\HoTen\SmallWorks_log.ldf',
	size = 10mb,
	filegrowth = 10%,
	maxsize =20mb
);

--3.Dùng SSMS để xem kết quả: Click phải trên tên của CSDL vừa tạo 
--a. Chọn filegroups, quan sát kết quả: 
-- Có bao nhiêu filegroup, liệt kê tên các filegroup hiện tại 
--	có 3 filegroup hiện tại là PRIMARY, SWUserData1, SWUserData2
-- Filegroup mặc định là gì? 
-- là PRIMARY 
--b.Chọn file, quan sát có bao nhiêu database file? 
--	có 4 file database 

--4.Dùng T-SQL tạo thêm một filegroup tên Test1FG1 trong SmallWorks, 
--sau đó add thêm 2 file filedat1.ndf và filedat2.ndf dung lượng 5MB vào filegroup Test1FG1. Dùng SSMS xem kết quả. 
use SmallWorks
alter database SmallWorks
add filegroup Test1FG1;

alter database SmallWorks
add file
(
	name = 'filedat1',
	filename = 'D:\HoTen\filedat1.ndf',
	size = 5mb,
	filegrowth = 10%,
	maxsize = 50mb
),
(
	name = 'filedat2',
	filename = 'D:\Hoten\filedat2.ndf',
	size = 5mb,
	filegrowth = 10%,
	maxsize = 50mb
)
to filegroup Test1FG1

select name, type_desc
from sys.filegroups;

select name, physical_name, size, max_size, growth, file_id, data_space_id
from sys.master_files
where database_id = db_id('SmallWorks')

--5.Dùng T-SQL tạo thêm một một file thứ cấp filedat3.ndf dung lượng 3MB trong filegroup Test1FG1. 
--Sau đó sửa kích thước tập tin này lên 5MB. Dùng SSMS xem kết quả. Dùng T-SQL xóa file thứ cấp filedat3.ndf. Dùng SSMS xem kết quả 

alter database SmallWorks
add file
(
	name = 'filedat3',
	filename = 'D:\HoTen\filedat3.ndf',
	size = 3mb
)
to filegroup Test1FG1;

alter database SmallWorks
modify file
(
	name = 'filedat3',
	size = 5mb
);

SELECT name, physical_name, size, max_size, growth, file_id, data_space_id  
FROM sys.master_files  
WHERE database_id = DB_ID('SmallWorks');

alter database SmallWorks
remove file filedat3;

SELECT name, physical_name, size, max_size, growth, file_id, data_space_id  
FROM sys.master_files  
WHERE database_id = DB_ID('SmallWorks');

--6.Xóa filegroup Test1FG1? Bạn có xóa được không? 
--Nếu không giải thích? Muốn xóa được bạn phải làm gì? 

ALTER DATABASE SmallWorks 
REMOVE FILEGROUP Test1FG1;

--không thể xóa, vì filegroup chỉ có thể xóa khi không còn file nào trong đó.
--để xóa ta sẽ xóa các file có trong đó 

--kiểm tra file có trong filegroup 
SELECT name, physical_name, data_space_id  
FROM sys.master_files  
WHERE data_space_id = (SELECT data_space_id FROM sys.filegroups WHERE name = 'Test1FG1');

alter database SmallWorks
remove file filedat1;

alter database SmallWorks
remove file filedat2;

ALTER DATABASE SmallWorks 
REMOVE FILEGROUP Test1FG1;

--7.Xem lại thuộc tính (properties) của CSDL SmallWorks bằng cửa sổ thuộc tính properties 
--và bằng thủ tục hệ thống sp_helpDb, sp_spaceUsed, sp_helpFile. Quan sát và cho biết các trang thể hiện thông tin gì?. 
exec sp_helpdb 'SmallWorks';

exec sp_spaceused;

exec sp_helpfile;

--8.Tại cửa sổ properties của CSDL SmallWorks, chọn thuộc tính ReadOnly, 
--sau đó đóng cửa sổ properties. Quan sát màu sắc của CSDL. 
--Dùng lệnh T-SQL gỡ bỏ thuộc tính ReadOnly và đặt thuộc tính cho phép nhiều người sử dụng CSDL SmallWorks. 

-- Sẽ có màu xám hoặc có chữ read-only

alter database SmallWorks
set read_write;

alter database SmallWorks
set multi_user;

--9.Trong CSDL SmallWorks, tạo 2 bảng mới theo cấu trúc như sau:
create table dbo.Person
(
	PersonID int not null,
	FirstName varchar(50) not null,
	MiddleName varchar(50) null,
	LastName varchar(50) not null,
	EmailAddress nvarchar(50) null
) on SWUserData1;

create table dbo.Product
( 
	ProductID int not null,
	ProductName varchar(75) not null,
	ProductNumber nvarchar(25) not null,
	StandardCost money not null,
	ListPrice money not null
) on SWUserData2;

--10.Chèn dữ liệu vào 2 bảng trên, lấy dữ liệu từ bảng Person và bảng Product trong 
--AdventureWorks2008 (lưu ý: chỉ rõ tên cơ sở dữ liệu và lược đồ), dùng lệnh 
--Insert…Select... Dùng lệnh Select * để xem dữ liệu trong 2 bảng Person và bảng 
--Product trong SmallWorks. 

use AdventureWorks2008R2;
select * from Person.Person;

select * from Production.Product;

use SmallWorks

insert into SmallWorks.dbo.Person (PersonID, FirstName, LastName)
select BusinessEntityID, FirstName, LastName
from AdventureWorks2008R2.Person.Person;

insert into SmallWorks.dbo.Product (ProductID, ProductName, ProductNumber, StandardCost, ListPrice)
select ProductID, Name, ProductNumber, StandardCost, ListPrice
from AdventureWorks2008R2.Production.Product;

select * from dbo.Person;
select * from dbo.Product;

--11.Dùng SSMS, Detach cơ sở dữ liệu SmallWorks ra khỏi phiên làm việc của SQL.
--12.Dùng SSMS, Attach cơ sở dữ liệu SmallWorks vào SQL.

--II.bài tập về nhà------------------------------------------------------------------------------------------------------

--1.Tạo các kiểu dữ liệu người dùng sau: 
use master

create database Sales

use Sales

create type Mota from nvarchar(40)
create type IDKH from char(10) not null
create type DT from char(12)

--2.Tạo các bảng theo cấu trúc sau: 
create table SanPham
(
	Masp char(6) not null primary key,
	TenSp varchar(20),
	NgayNhap date,
	DVT char(10),
	SoLuongTon int,
	DonGiaNhap money
);

create table KhachHang
(
	MaKH IDKH primary key,
	TenKH nvarchar(20),
	DiaChi nvarchar(40),
	Dienthoai DT
);

create table HoaDon
(
	MaHD char(10) not null primary key,
	NgayLap date,
	NgayGiao date,
	MaKH IDKH constraint MAKH_FK foreign key (MaKH) references KhachHang (MaKH) on delete cascade on update cascade,
	DienGiai Mota
);

create table ChiTietHD
(
	MaHD char(10) not null primary key,
	Masp char(6) constraint MASP_FK foreign key (Masp) references SanPham (Masp) on delete cascade on update cascade,
	Soluong int
);

--3.Trong Table HoaDon, sửa cột DienGiai thành nvarchar(100).

alter table HoaDon
alter column DienGiai nvarchar(100);

--4.Thêm vào bảng SanPham cột TyLeHoaHong float 

alter table SanPham
add TyLeHoaHong float;

--5.Xóa cột NgayNhap trong bảng SanPham

alter table SanPham
Drop column NgayNhap

--6.Tạo các ràng buộc khóa chính và khóa ngoại cho các bảng trên.

-- alter table HoaDon
-- add constraint MAKH_FK
-- foreign key (MaKH) references KhachHang(MaKH);

-- alter table ChiTietHD
-- add constraint MASP_FK
-- foreign key (Masp) references SanPham(Masp);

--7.Thêm vào bảng HoaDon các ràng buộc sau: 

alter table HoaDon
add constraint CK_NgayGiao check (NgayGiao >= NgayLap);

alter table HoaDon
add constraint CK_MaHD check (MaHD like '[A-Z][A-Z][0-9][0-9][0-9][0-9]');

alter table HoaDon
add constraint CK_NgayLap default getdate() for NgayLap;

--8.Thêm vào bảng Sản phẩm các ràng buộc sau: 

alter table SanPham
add constraint CK_SoLuongTon check (SoLuongTon between 0 and 500);

alter table SanPham
add constraint CK_DonGiaNhap check (DonGiaNhap > 0);

alter table SanPham
add NgayNhap date

alter table SanPham
add constraint CK_NgayNhap default getdate() for NgayNhap;

alter table SanPham
add constraint CK_DVT check (DVT in ('KG',N'Thùng',N'Hộp',N'Cái'));

--9.Dùng lệnh T-SQL nhập dữ liệu vào 4 table trên, dữ liệu tùy ý, chú ý các ràng buộc của mỗi Table 

Insert Into SanPham (Masp , Tensp , DVT ,NgayNhap)
values('0',N'Siêu Nhân',N'Cái','2025-08-01')

insert into KhachHang(MaKH,TenKH,Dienthoai)
values('0',N'Mozart','090000990') 

insert into HoaDon (MaHD, NgayLap, NgayGiao, MaKH)
values ('HD0001', '2025-02-11', '2025-02-20', '0');

select * from SanPham;
select * from KhachHang;
select * from HoaDon;

--10. Xóa 1 hóa đơn bất kỳ trong bảng HoaDon. Có xóa được không? Tại sao? Nếu vẫn muốn xóa thì phải dùng cách nào? 

delete from HoaDon where MaHD = 'HD0000';

--có thể xóa được tại vì ở trên đã dùng lệnh on delete cascade và on update cascade
--không xóa được vì có dữ liệu liên quan ở khóa ngoại ở ChiTietHD chỉ cần xóa ở ChiTietHD trước là xóa được.

--11.Nhập 2 bản ghi mới vào bảng ChiTietHD với MaHD = ‘HD999999999’ và 
--MaHD=’1234567890’. Có nhập được không? Tại sao? 

insert into ChiTietHD (MaHD)
values ('HD999999999'),('HD1234567890')

--Không thể nhập vì độ dài MaHD lớn hơn độ dài cho phép 

--12.Đổi tên CSDL Sales thành BanHang 
use master

ALTER DATABASE Sales SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

ALTER DATABASE Sales MODIFY NAME = BanHang;

ALTER DATABASE BanHang SET MULTI_USER;

--13.Tạo thư mục T:\QLBH, chép CSDL BanHang vào thư mục này, bạn có sao 
--chép được không? Tại sao? Muốn sao chép được bạn phải làm gì? Sau khi sao 
--chép, bạn thực hiện Attach CSDL vào lại SQL. 

-- không thể sao chép vì đang sử dụng phải detach trước rồi mới copy được
-- Muốn attach lại thì phải đổi tên 

--14.Tạo bản BackUp cho CSDL BanHang 
--15.Xóa CSDL BanHang 
--16.Phục hồi lại CSDL BanHang. 