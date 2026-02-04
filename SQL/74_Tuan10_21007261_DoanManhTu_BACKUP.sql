--1.  Trong SQL Server, tạo thiết bị backup có tên adv2008back lưu trong thư mục 
--T:\backup\adv2008back.bak
exec sp_addumpdevice 'disk' , 'adv2009back' , 'D:\backup\adv2009back.bak'
--2.  Attach CSDL AdventureWorks2008, chọn mode recovery cho CSDL này là full, rồi 
--thực hiện full backup vào thiết bị backup vừa tạo
alter database [AdventureWorks2008R2]
set recovery full
go
--
backup database [AdventureWorks2008R2]
to adv2009back 
with FORMAT, description = 'QuanLyDuAn Backup'    -- file 1 
 
--3.  Mở CSDL AdventureWorks2008, tạo một transaction giảm giá tất cả mặt hàng xe 
--đạp trong bảng Product  $15 
use [AdventureWorks2008R2]
go

begin tran 
	update [Production].[Product]
	set [ListPrice] = [ListPrice] - 15 
	where [ProductSubcategoryID] IN (select [ProductSubcategoryID]
									  from [Production].[ProductSubcategory]
									  where [Name] LIKE 'Bike%' OR [NAME] LIKE '%Bikes'
									  )
	commit 
go 


SELECT * 
FROM [Production].[ProductSubcategory]
--4.  Thực hiện các backup sau cho CSDL AdventureWorks2008, tất cả backup đều lưu 
--vào thiết bị backup vừa tạo
--a.  Tạo 1 differential backup 
backup database [AdventureWorks2008R2] -- file 2
to adv2009back
with differential, description = 'adv2009 differential Backup'
--b.  Tạo 1 transaction log backup
backup log [AdventureWorks2008R2] -- file 3 
to adv2009back
with description = 'adv2009 Log Backup' 

--5.  (Lưu ý ở bước 7 thì CSDL AdventureWorks2008 sẽ bị xóa. Hãy lên kế hoạch phục 
--hồi cơ sở dữ liệu cho các hoạt động trong câu 5, 6). 
select * 
from Person.EmailAddress
--Xóa mọi bản ghi trong bảng Person.EmailAddress, tạo 1 transaction log backup
delete Person.EmailAddress

-- 
backup log [AdventureWorks2008R2] -- file 4 
to adv2009back

--6.  Thực hiện lệnh:
--a.  Bổ sung thêm 1 số phone mới cho nhân viên có mã số business là 10000 như 
--sau:
select * 
from Person.PersonPhone
where [BusinessEntityID] = 10000

INSERT INTO Person.PersonPhone VALUES (10000,'123-456-7890',1,GETDATE())

--b.  Sau đó tạo 1 differential backup cho AdventureWorks2008 và lưu vào thiết bị 
--backup vừa tạo.
backup database [AdventureWorks2008R2] -- file 5 
to adv2009back 
with differential

--
backup log [AdventureWorks2008R2] -- file 6 
to adv2009back  
--c.  Chú ý giờ hệ thống của máy. 
--Đợi 1 phút sau, xóa bảng Sales.ShoppingCartItem
drop table Sales.ShoppingCartItem

--7.  Xóa CSDL AdventureWorks2008
use master
drop database [AdventureWorks2008R2]
--8.  Để khôi phục lại CSDL: 
--a.  Như lúc ban đầu (trước câu 3) thì phải restore thế nào?
RESTORE DATABASE AdventureWorks2008R2
 FROM adv2009back
 WITH FILE = 1, NORECOVERY 
--b.  Ở tình trạng giá xe đạp đã được cập nhật và bảng Person.EmailAddress vẫn 
--còn nguyên chưa bị xóa (trước câu 5) thì cần phải restore thế nào?
RESTORE DATABASE AdventureWorks2008R2
 FROM adv2009back
 WITH FILE = 2, NORECOVERY 

--  
RESTORE LOG AdventureWorks2008R2
FROM adv2008back 
WITH FILE = 3, RECOVERY 

--c.  Đến thời điểm đã được chú ý trong câu 6c thì thực hiện việc restore lại CSDL 
--AdventureWorks2008  ra sao?
RESTORE DATABASE AdventureWorks2008R2
FROM adv2008back 
WITH FILE = 5, RECOVERY 
