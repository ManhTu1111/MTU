USE AdventureWorks2008R2
GO
--1)  Thêm  vào  bảng  Department  một  dòng  dữ  liệu  tùy  ý  bằng  câu  lệnh 
--INSERT..VALUES…
--a)  Thực hiện lệnh chèn thêm vào bảng Department một dòng dữ liệu tùy ý bằng 
--cách thực hiện lệnh Begin tran và Rollback, dùng câu lệnh Select * From 
--Department xem kết quả.
--b)  Thực hiện câu lệnh trên với lệnh Commit và kiểm tra kết  quả.
-------------------------------------------------------BAI LAM ---------------------------------------------------------------------
--a)
BEGIN TRAN
INSERT INTO HumanResources.Department (Name, GroupName, ModifiedDate)
VALUES ('New Department', 'Group A', GETDATE())
SELECT * FROM HumanResources.Department;
ROLLBACK
SELECT * FROM HumanResources.Department;
GO

SELECT * FROM HumanResources.Department
GO
--b)
BEGIN TRAN
INSERT INTO HumanResources.Department (Name, GroupName)
VALUES ('New Department','ABC')
SELECT * FROM HumanResources.Department
COMMIT
GO

SELECT * FROM HumanResources.Department
GO

------------------------------------------------------------------------------------------------------------------------------------
--2)  Tắt chế độ autocommit của SQL Server (SET IMPLICIT_TRANSACTIONS 
--ON). Tạo đoạn batch gồm các thao  tác:
--  Thêm một dòng vào bảng  Department
--  Tạo một bảng Test (ID int, Name  nvarchar(10))
--  Thêm một dòng vào Test
--  ROLLBACK;
--  Xem dữ liệu ở bảng Department và Test để kiểm tra dữ liệu, giải thích kết 
--quả.
-------------------------------------------------------BAI LAM ---------------------------------------------------------------------
-- Tắt chế độ autocommit
SET IMPLICIT_TRANSACTIONS ON
GO

BEGIN TRAN
INSERT INTO HumanResources.Department (Name, GroupName, ModifiedDate)
VALUES ('New Department', 'Group A', GETDATE())
CREATE TABLE Test (ID INT, Name NVARCHAR(10))
INSERT INTO Test (ID, Name)
VALUES (1, 'Test Name')
ROLLBACK
GO

SELECT * FROM HumanResources.Department
SELECT * FROM Test
GO

--Khi chế độ IMPLICIT_TRANSACTIONS được bật, SQL Server sẽ tự động bắt đầu một giao dịch khi thực hiện bất kỳ câu lệnh DML nào (INSERT, UPDATE, DELETE).

--Sau khi thực hiện ROLLBACK, dữ liệu đã được chèn vào cả bảng Department và Test sẽ bị hủy.

--Kết quả sẽ là bảng Department và bảng Test không có dữ liệu nào mới.

------------------------------------------------------------------------------------------------------------------------------------
--3)  Viết  đoạn  batch  thực  hiện  các  thao  tác  sau  (lưu  ý  thực  hiện  lệnh  SET 
--XACT_ABORT ON: nếu câu lệnh T-SQL làm phát sinh lỗi run-time, toàn bộ giao 
--dịch được chấm dứt và  Rollback)
--  Câu lệnh SELECT với phép chia 0 :SELECT 1/0 as  Dummy
--  Cập nhật một dòng trên bảng Department với DepartmentID=’9’ (id này 
--không tồn  tại)
--  Xóa một dòng không tồn tại trên bảng Department  (DepartmentID =’66’)
--  Thêm một dòng bất kỳ vào bảng  Department
--  COMMIT;
--Thực thi đoạn batch, quan sát kết quả và các thông báo lỗi và giải thích kết quả.
-------------------------------------------------------BAI LAM ---------------------------------------------------------------------
SET XACT_ABORT ON
GO

BEGIN TRAN

SELECT 1/0 AS DIV

UPDATE HumanResources.Department
SET Name = 'Updated Department'
WHERE DepartmentID = 9;

DELETE FROM HumanResources.Department WHERE DepartmentID = 66;

INSERT INTO HumanResources.Department (Name, GroupName)
VALUES ('Another Department','ABC');

COMMIT
GO

--SET XACT_ABORT ON sẽ tự động ROLLBACK giao dịch nếu có lỗi runtime.

--Vì phép chia 0 (SELECT 1/0) gây lỗi, toàn bộ giao dịch sẽ bị hủy và ROLLBACK sẽ được thực hiện.

--Các câu lệnh tiếp theo không được thực thi do giao dịch đã bị hủy. Do đó, bảng Department sẽ không có thay đổi nào.

------------------------------------------------------------------------------------------------------------------------------------
--4)  Thực  hiện  lệnh  SET  XACT_ABORT  OFF  (những  câu  lệnh  lỗi  sẽ  rollback, 
--transaction vẫn tiếp tục) sau đó thực thi lại các thao tác của đoạn batch ở câu 3. Quan 
--sát kết quả và giải thích kết  quả?
-------------------------------------------------------BAI LAM ---------------------------------------------------------------------
SET XACT_ABORT OFF
GO

BEGIN TRAN

SELECT 1/0 AS DIV

UPDATE HumanResources.Department
SET Name = 'Updated Department'
WHERE DepartmentID = 9;

DELETE FROM HumanResources.Department WHERE DepartmentID = 66;

INSERT INTO HumanResources.Department (Name, GroupName)
VALUES ('Another Department','ABC');

COMMIT
GO

--Với SET XACT_ABORT OFF, SQL Server không tự động hủy giao dịch khi gặp lỗi.

--Tuy phép chia 0 gây lỗi, giao dịch vẫn tiếp tục và các thao tác sau vẫn thực thi.

--Mặc dù có lỗi ở bước đầu tiên, các câu lệnh sau vẫn thực hiện bình thường.

--Do đó, một dòng sẽ được thêm vào bảng Department ngay cả khi có lỗi trong giao dịch, vì ROLLBACK không tự động xảy ra.
------------------------------------------------------------------------------------------------------------------------------------