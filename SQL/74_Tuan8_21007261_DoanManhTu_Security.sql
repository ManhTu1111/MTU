--TK SA
--1)  Đăng nhập vào  SQL  bằng SQL  Server authentication, tài khoản sa.  Sử dụng TSQL.
--2)  Tạo hai login SQL server Authentication User2 và  User3
----------------------------------------------BAI LAM------------------------------------------------------------------------
-- Tạo login User2
CREATE LOGIN User2 WITH PASSWORD = '123'
GO

-- Tạo login User3
CREATE LOGIN User3 WITH PASSWORD = '123'
GO

-----------------------------------------------------------------------------------------------------------------------------
--3)  Tạo một database user User2 ứng với login User2 và một database user   User3
--ứng với login User3 trên CSDL AdventureWorks2008.
----------------------------------------------BAI LAM------------------------------------------------------------------------
USE AdventureWorks2008R2
GO

CREATE USER User2 FOR LOGIN User2
GO

CREATE USER User3 FOR LOGIN User3
GO

-----------------------------------------------------------------------------------------------------------------------------
--4)  Tạo 2 kết nối đến server thông qua login  User2  và  User3, sau đó thực hiện các 
--thao tác truy cập CSDL  của 2 user  tương ứng (VD: thực hiện  câu Select). Có thực 
--hiện được không?
----------------------------------------------BAI LAM------------------------------------------------------------------------

EXECUTE AS USER = 'User2';
SELECT * FROM HumanResources.Employee
REVERT
GO

EXECUTE AS USER = 'User3';
SELECT * FROM HumanResources.Employee
REVERT
GO
--Không thể kết nối được vì không được cấp quyền truy cập
-----------------------------------------------------------------------------------------------------------------------------
--5)  Gán quyền select trên Employee cho User2, kiểm tra kết quả.  Xóa quyền select 
--trên Employee cho User2. Ngắt 2 kết nối của User2 và  User3
----------------------------------------------BAI LAM------------------------------------------------------------------------

GRANT SELECT ON HumanResources.Employee TO User2
GO

EXECUTE AS USER = 'User2'
SELECT * FROM HumanResources.Employee
REVERT
GO

REVOKE SELECT ON HumanResources.Employee TO User2
GO

-----------------------------------------------------------------------------------------------------------------------------
--6)  Trở lại kết nối của sa, tạo một user-defined database Role tên Employee_Role trên 
--CSDL  AdventureWorks2008,  sau  đó  gán  các  quyền  Select,  Update,  Delete  cho 
--Employee_Role.
----------------------------------------------BAI LAM------------------------------------------------------------------------

CREATE ROLE Employee_Role
GO

GRANT SELECT, UPDATE, DELETE ON HumanResources.Employee TO Employee_Role
GO

-----------------------------------------------------------------------------------------------------------------------------
--7)  Thêm các  User2  và  User3  vào  Employee_Role.  Tạo  lại  2  kết  nối  đến  server  thông 
--qua login User2 và User3 thực hiện các thao tác  sau:
--a)  Tại kết nối với User2, thực hiện câu lệnh Select để xem thông tin của bảng 
--Employee
--b)  Tại kết nối của User3, thực hiện cập nhật JobTitle=’Sale Manager’ của  nhân 
--viên có BusinessEntityID=1
--c)  Tại kết nối User2, dùng câu lệnh Select xem lại kết  quả.
--d)  Xóa role Employee_Role, (quá trình xóa role    ra sao ?)
----------------------------------------------BAI LAM------------------------------------------------------------------------
--a)
EXEC sp_addrolemember 'Employee_Role', 'User2'
EXEC sp_addrolemember 'Employee_Role', 'User3'
GO
EXECUTE AS USER = 'User2'
SELECT * FROM HumanResources.Employee
REVERT
GO
--b)
EXECUTE AS USER = 'User3'
UPDATE HumanResources.Employee
SET JobTitle = 'Sale Manager'
WHERE BusinessEntityID = 1
REVERT
GO
--c)
EXECUTE AS USER = 'User2';
SELECT * FROM HumanResources.Employee WHERE BusinessEntityID = 1
REVERT
GO
--d)
--Phải xóa các tài khoản liên quan đên role
EXEC sp_droprolemember 'Employee_Role', 'User2';
EXEC sp_droprolemember 'Employee_Role', 'User3';
--Thực hiện xóa Role sau khi đã xóa toàn bộ role đã được cấp cho các tài khoản liên quan
DROP ROLE Employee_Role;
-----------------------------------------------------------------------------------------------------------------------------