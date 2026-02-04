
 bai tap 1 : LENH INSERT 

use QLBH 
--1 
--chọn các cột cần thiết từ bảng Customers
select CustomerID,CompanyName,Address,Phone, Fax
from Northwind.dbo.Customers 
--Chỉ lấy các cột tương ứng giữa 2 bảng KhachHang và Customers
select Makh,Tenkh,Diachi,Phone, SoFax
from KhachHang
insert into KhachHang (Makh, Tenkh, Diachi, Phone, SoFax)
	select CustomerID,CompanyName,Address,Phone,Fax --dùng Subquery from Northwind.dbo.Customers
	from Northwind.dbo.Customers

select Makh, Tenkh, DiaChi, Phone, SoFax from KhachHang
--lệnh INSERT... SELECT...
insert into KhachHang (Makh, Tenkh, DiaChi, Phone, SoFax)
	select CustomerID, CompanyName, Address, Phone, Fax 
	from Northwind.dbo.Customers
--kiểm tra
select * from KhachHang

--b.Insert dữ liệu vào bảng Sanpham trong QLBH. Dữ liệu nguồn là các sản phẩm có SupplierID từ
--4 đến 29 trong bảng Northwind.dbo.Products
select ProductID, ProductName, SupplierID, QuantityPerUnit, UnitPrice from Northwind.dbo.Products
where SupplierID between 4 and 29

select MaSp , tenSp , MaNCC , ĐonViTinh, GiaGoc 
from SanPham 

-- loc nha cung cap 
select SupplierID, CompanyName, Address , Phone , Fax
from Northwind.dbo.Suppliers
where SupplierID between 4 and 29 

select MaNCC, TenNCC , DiaChi , Phone , SoFax  from NhaCungCap

-- chen du lieu bang nha cung cap 
insert into NhaCungCap(MaNCC,TenNCC,DiaChi,Phone,SoFax)
	select SupplierID,CompanyName, Address , Phone , Fax 
	from Northwind.dbo.Suppliers 
	where SupplierID between 4 and 9 
	
select * from NhaCungCap

-- lam lai insert into SanPham ...... cho bang con 
insert into SanPham(MaSp,TenSp,MaNCC, ĐonViTinh, GiaGoc)
	select ProductID,ProductName, SupplierId, QuantityPerUnit , UnitPrice	
	from Northwind.dbo.Products where SupplierID between 4 and 29 
select * from SanPham 

--c 
select MaHD, NgayLapHD, NgayGiao, NoiChuyen, MaKh ,LoaiHD from HoaDon 

select OrderID, OrderDate , RequiredDate , ShipAddress, CustomerID, 'X' as LoaiHD 
from Northwind.dbo.Orders
where OrderID between 10248 and 10350 
-- chen dl tu bang orders vao bang hoadon
insert HoaDon(MaHD, NgayLapHD, NgayGiao, NoiChuyen, MaKh ,LoaiHD)
	select OrderID , OrderDate , RequiredDate, ShipAddress , CustomerID, 'X' as LoaiHD
	from Northwind.dbo.Orders
	where OrderID between 10248 and 10350 

select * from HoaDon 

--d 
select MaHD,MaSp, SoLuong, DonGia, Chietkhau from CT_HoaDon --MaHD=1..3, MaSp=1..4
select OrderID, ProductID, Quantity, UnitPrice, Discount from Northwind.dbo.[Order Details]-- các thuộc tính tương ứng 1-1 giữa 2 bảng
where (OrderID between 10248 and 10350)
order by ProductID --ProductID= 1..77, thiếu 9,45,48,61

insert CT_HoaDon(MaHD,MaSp, SoLuong,DonGia, Chietkhau)
	select OrderID, ProductID, Quantity, UnitPrice, Discount from Northwind.dbo. [Order Details] 
	where (OrderID between 10248 and 10350)
	and (ProductID between 1 and 6 ) 
	
select * from CT_hoaDon


--2. Dùng công cụ SQL Server Import/Export Data Wizard

--1.1) Export toàn bộ dữ liệu trong bảng Customers trong NorthWind thành file
--Khachhang.txt
-- xem diagram 
--2) Import : Danh sách các khách hàng có trong tập tin Khachhang.txt vào
--bảng KhachHang2 trong QLBH
--3) Import : Các sản phẩm có SupplierID là 1 hoặc 2 hoặc 3 ở bảng Products
--trong NorthWind vào bảng SanPham trong QLBH. Lưu ý chỉ chọn những
--cột có tương ứng trong bảng SanPham.
select * from QLBH.dbo.NhaCungCap
select * from QLBH.dbo.NhomSanPham
select * from QLBH.dbo.SanPham

-- yeu cau đè 
select ProductID, ProductName , SupplierID, CategoryID , QuantityPerUnit, UnitPrice 
from Northwind.dbo.Products
where SupplierID in (1,2,3) 

-- tương ứng trong bảng SanPham 
select MaSp, TenSp , MaNCC , MaNhom , ĐonViTinh , GiaGoc 
from SanPham 

-- Export tu CSDL Northwind rồi import dữ liệu vào csdl qlbh 
select ProductID, ProductName, SupplierID, CategoryID=cast (CategoryID as char(5)),
QuantityPerUnit, UnitPrice from Northwind.dbo. Products

where SupplierID in (1,2) and CategoryID in (1,2,3,4) and ProductID>6 --2 dòng 65,66
--Source: Query, Destination: SanPham; chọn Edit Mappings, Preview
--xem lại kết quả

select * from QLBH.dbo.SanPham --có 2 dòng mới
where Masp in (65,66)
--4) Import: Các nhà cung cấp có Country là USA ở bảng Suppliers trong NorthWind vào bảng NhaCungCap --trong QLBH. 
--Lưu ý: chỉ chọn những cột mà trong bản Nhacungcap cần. 

select * from QLBH.dbo.NhaCungCap 

select SupplierID,CompanyName=Cast(CompanyName as nvarchar(50)), Address=Cast(Address as nvarchar (50)), 
	   Phone = Convert(varchar(24),Phone), Fax=CONVERT(varchar(24),Fax)
from Northwind.dbo.Suppliers
where SupplierID=3 and Country='USA' -- 1 dong 

-- kiem tra 
select * from QLBH.dbo.NhaCungCap
----
-- accress file(*.MDB)
--5) Export : Dữ liệu của các bảng Products, Orders, Order Details trong bảng
--NorthWind vào tập tin QLHH.MDB. Lưu ý: Tập tin QLHH.MDB phải tồn
--tại trên đĩa trước khi thực hiện Export.


--6) Export : Dữ liệu các bảng Products, Suppliers trong NorthWind thành tập
--tin SP_NCC.XLS
SELECT ProductID, ProductName, QuantityPerUnit, UnitPrice
FROM Northwind.dbo.Products
UNION
SELECT SupplierID, CompanyName, ContactName, Phone
FROM Northwind.dbo.Suppliers

--7) Export : Các khách hàng có City là LonDon từ bảng Customers trong
--NorthWind ra thành tập tin KH_london.TXT

select CustomerID, CompanyName, Address, City 
from Northwind.dbo.Customers
where City='LonDon' -- 6 dong 

--8) Export : Danh sách các sản phẩm ở Products trong NorthWind thành tập
--tin SanPham.TXT, thông tin cần lấy bao gồm ProductID, ProductName,
--QuantityPerUnit, Unitprice.
SELECT ProductID, ProductName, QuantityPerUnit, UnitPrice
FROM Northwind.dbo.Products 


BAI TAP 2 UPDATE 
use Northwind
--1. Cập nhật chiết khấu 0.1 cho các mặt hàng trong các hóa đơn xuất bán
--vào ngày ‘1/1/1997’
UPDATE [dbo].[Order Details]
SET Discount = 0.1
WHERE OrderID IN (
  SELECT OrderID
  FROM Orders
  WHERE OrderDate = '1997-01-01'
);
--2. Cập nhật đơn giá bán 17.5 cho mặt hàng có mã 11 trong các hóa đơn
--xuất bán vào tháng 2 năm 1997
UPDATE [dbo].[Order Details]
SET UnitPrice = 17.5
WHERE OrderID IN (
  SELECT OrderID
  FROM Orders
  WHERE MONTH(OrderDate) = 2 AND YEAR(OrderDate) = 1997
) AND ProductID = 11;
--3. Cập nhật giá bán các sản phẩm trong bảng [Order Details] bằng với đơn
--giá mua trong bảng [Products] của các sản phẩm được cung cấp từ nhà
--cung cấp có mã là 4 hay 7 và xuất bán trong tháng 4 năm 1997Trường ĐH Công Nghiệp TP.HCM Bài Tập Thực Hành Môn Hệ Cơ Sở Dữ Liệu
--Khoa Công Nghệ Thông Tin 48/51
UPDATE [Order Details]
SET [Order Details].UnitPrice = Products.UnitPrice
FROM [Order Details]
JOIN Products ON [Order Details].ProductID = Products.ProductID
WHERE [Order Details].ProductID IN (
  SELECT ProductID
  FROM Products
  WHERE SupplierID = [SupplierID] -- Thay [SupplierID] bằng giá trị cụ thể của SupplierID
);
--4. Cập nhật tăng phí vận chuyển (Freight) lên 20% cho những hóa đơn có
--tổng trị giá hóa đơn >= 10000 và xuất bán trong tháng 1/1997
UPDATE Orders
SET Freight = Freight * 1.2
WHERE TotalValue >= 10000 AND MONTH(OrderDate) = 1 AND YEAR(OrderDate) = 1997;
--5. Thêm 1 cột vào bảng Customers lưu thông tin về loại thành viên :
--Member97 varchar(3) . Cập nhật cột Member97 là ‘VIP’ cho những
--khách hàng có tổng trị giá các đơn hàng trong năm 1997 từ 50000 trở
--lên.
ALTER TABLE Customers
ADD Member97 varchar(3);

UPDATE Customers
SET Member97 = 'VIP'
WHERE CustomerID IN (
  SELECT CustomerID
  FROM Orders
  WHERE YEAR(OrderDate) = 1997
  GROUP BY CustomerID
  HAVING SUM(TotalAmount) >= 50000
);

Bai Tap 3 lệnh delete 
--1. Xóa các dòng trong [Order Details] có ProductID 24, là “chi tiết của
--hóa đơn” xuất bán cho khách hàng có mã ‘SANTG’
DELETE FROM [Order Details]
WHERE ProductID = 24 
  AND OrderID IN (
    SELECT OrderID
    FROM Orders
    WHERE CustomerID = 'SANTG'
  );
--2. Xóa các dòng trong [Order Details] có ProductID 35, là “chi tiết của
--hóa đơn” xuất bán trong năm 1998 cho khách hàng có mã ‘SANTG’
DELETE FROM [Order Details]
WHERE ProductID = 35
  AND OrderID IN (
    SELECT OrderID
    FROM Orders
    WHERE CustomerID = 'SANTG'
      AND YEAR(OrderDate) = 1998
  );
--3. Thực hiện xóa tất cả các dòng trong [Order Details] là “chi tiết của
--các hóa đơn” bán cho khách hàng có mã ‘SANTG’
DELETE FROM [Order Details]
WHERE OrderID IN (
  SELECT OrderID
  FROM Orders
  WHERE CustomerID = 'SANTG'
);