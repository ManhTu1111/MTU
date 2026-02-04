use [AdventureWorks2008R2]
--  Scalar Function
--1)  Viết hàm tên  CountOfEmployees  (dạng scalar function) với tham số @mapb, 
--giá  trị  truyền  vào  lấy  từ  field  [DepartmentID],  hàm  trả  về  số  nhân  viên  trong 
--phòng ban  tương  ứng. Áp  dụng hàm  đã viết  vào câu truy  vấn  liệt kê danh  sách các
--phòng ban với  số nhân viên  của  mỗi phòng ban, thông  tin gồm: [DepartmentID],
--Name, countOfEmp với countOfEmp= CountOfEmployees([DepartmentID]).
--(Dữ liệu lấy từ bảng 
--[HumanResources].[EmployeeDepartmentHistory] và 
--[HumanResources].[Department])

create function CountOfEmployees (@mapb int)
returns int
as
begin
	declare @count int
	select @count = COUNT(*)
	from HumanResources.EmployeeDepartmentHistory as EDH join
	HumanResources.Department as D on EDH.DepartmentID = D.DepartmentID
	where D.DepartmentID = @mapb

	return @count
end
go

select
    DepartmentID,
    Name,
    dbo.CountOfEmployees(DepartmentID) as countOfEmp
from 
    [HumanResources].[Department]
go


--2)  Viết  hàm  tên  là  InventoryProd  (dạng  scalar  function)  với  tham  số  vào  là
--@ProductID và @LocationID trả về số lượng tồn kho của sản phẩm trong khu 
--vực tương ứng với giá trị của tham số
--(Dữ liệu lấy từ bảng[Production].[ProductInventory])

create function InventoryProd (@ProductID int, @LocationID int)
returns int
as 
begin
	declare @count int
	select @count = COUNT(*)
	from Production.ProductInventory
	where ProductID = @ProductID and LocationID = @LocationID
	return @count
end
go

declare @count int
select @count = dbo.InventoryProd(1,1)
print N'So luong ton la '+ cast(@count as varchar(10))
go

--3)  Viết hàm tên SubTotalOfEmp  (dạng scalar function) trả về tổng doanh thu của 
--một  nhân  viên  trong  một  tháng  tùy  ý  trong  một  năm  tùy  ý,  với  tham  số  vào
--@EmplID, @MonthOrder, @YearOrder
--(Thông tin lấy từ bảng [Sales].[SalesOrderHeader])

create function SubTotalOfEmp (@EmplID int, @MonthOrder int, @YearOrder int)
returns int
as 
begin
	declare @temp int
	select @temp = SUM(SubTotal)
	from Sales.SalesOrderHeader 
	where SalesOrderID = @EmplID and YEAR(OrderDate) = @YearOrder  and MONTH(OrderDate) = @MonthOrder
	return @temp
end
go


declare @temp int
select @temp = dbo.SubTotalOfEmp(43659, 2005, 7)
print N'Tong so tien la '+ cast(@temp as varchar(20))
go

--  In-line Table Valued Functions: 
--4)  Viết hàm SumOfOrder  với hai tham số @thang và @nam trả về danh sách các 
--hóa đơn (SalesOrderID) lập trong tháng và năm được truyền vào từ    2 tham số
--@thang và @nam, có tổng tiền >70000, thông tin gồm SalesOrderID, OrderDate,
--SubTotal, trong đó SubTotal =sum(OrderQty*UnitPrice).

create function SumOfOrder (@thang int, @nam int)
returns table
as
return(
	select SOD.SalesOrderID, OrderDate, SubTotal =sum(OrderQty*UnitPrice)
	from Sales.SalesOrderDetail as SOD join 
	Sales.SalesOrderHeader as SOH on SOD.SalesOrderID = SOH.SalesOrderID
	where year(OrderDate) = @nam and month(OrderDate) = @thang
	group by SOD.SalesOrderID, OrderDate
	having sum(OrderQty*UnitPrice) > 70000)
go

select *
from dbo.SumOfOrder(11,2005)
go

--5)  Viết hàm tên  NewBonus  tính lại tiền thưởng (Bonus) cho nhân viên bán hàng 
--(SalesPerson), dựa trên tổng doanh thu của mỗi nhân viên, mức thưởng mới bằng 
--mức  thưởng  hiện  tại  tăng  thêm  1%  tổng  doanh  thu,  thông  tin  bao  gồm 
--[SalesPersonID], NewBonus (thưởng mới), SumOfSubTotal. Trong đó:
--  SumOfSubTotal  =sum(SubTotal),
--  NewBonus = Bonus+ sum(SubTotal)*0.01

create function NewBonus ()
returns table
as 
return
(	
	select SalesPersonID, NewBonus = Bonus + sum(SubTotal) * 0.01, SumOfSubTotal  =sum(SubTotal)
	from Sales.SalesPerson as SP join 
	Sales.SalesOrderHeader as SOH on SP.BusinessEntityID = SOH.SalesPersonID
	group by SalesPersonID, Bonus
)
go

select *
from dbo.NewBonus()

--6)  Viết  hàm  tên  SumOfProduct  với  tham  số  đầu  vào  là  @MaNCC  (VendorID),hàm dùng để tính tổng số lượng (SumOfQty) và tổng trị giá (SumOfSubTotal)
--của  các  sản  phẩm  do  nhà  cung  cấp  @MaNCC  cung  cấp,  thông  tin  gồm 
--ProductID, SumOfProduct, SumOfSubTotal
--(sử dụng các bảng [Purchasing].[Vendor] [Purchasing].[PurchaseOrderHeader] 
--và [Purchasing].[PurchaseOrderDetail])


CREATE FUNCTION SumOfProduct (@MaNCC INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        pod.ProductID,
        SUM(pod.OrderQty) AS SumOfQty,
        SUM(pod.LineTotal) AS SumOfSubTotal
    FROM Purchasing.PurchaseOrderDetail pod
    JOIN Purchasing.PurchaseOrderHeader poh ON pod.PurchaseOrderID = poh.PurchaseOrderID
    JOIN Purchasing.Vendor v ON poh.VendorID = v.BusinessEntityID
    WHERE poh.VendorID = @MaNCC
    GROUP BY pod.ProductID
);
GO

-- Cách sử dụng hàm
SELECT * FROM dbo.SumOfProduct(1652); -- Thay 1652 bằng mã nhà cung cấp cần truy vấn


--7)  Viết hàm tên Discount_Func tính số tiền giảm trên các hóa đơn  (SalesOrderID), 
--thông  tin gồm  SalesOrderID,  [SubTotal],  Discount;  trong  đó  Discount  được  tính 
--như sau:
--Nếu [SubTotal]<1000 thì Discount=0 
--Nếu 1000<=[SubTotal]<5000 thì Discount = 5%[SubTotal]
--Nếu 5000<=[SubTotal]<10000 thì Discount = 10%[SubTotal] 
--Nếu [SubTotal>=10000 thì Discount = 15%[SubTotal]
--Gợi ý: Sử dụng Case.. When … Then …
--(Sử dụng dữ liệu từ bảng [Sales].[SalesOrderHeader])

CREATE FUNCTION Discount_Func()
RETURNS TABLE
AS
RETURN
(
    SELECT 
        SalesOrderID,
        SubTotal,
        Discount = 
            CASE 
                WHEN SubTotal < 1000 THEN 0
                WHEN SubTotal >= 1000 AND SubTotal < 5000 THEN SubTotal * 0.05
                WHEN SubTotal >= 5000 AND SubTotal < 10000 THEN SubTotal * 0.10
                ELSE SubTotal * 0.15
            END
    FROM Sales.SalesOrderHeader
);
GO

SELECT * FROM dbo.Discount_Func();


--8)  Viết hàm  TotalOfEmp  với tham số  @MonthOrder, @YearOrder để tính  tổng 
--doanh thu của các nhân viên bán hàng (SalePerson) trong tháng và năm được 
--truyền  vào  2  tham  số,  thông  tin  gồm  [SalesPersonID],  Total,  với 
--Total=Sum([SubTotal])
--  Multi-statement Table Valued  Functions:

CREATE FUNCTION TotalOfEmp (@MonthOrder INT, @YearOrder INT)
RETURNS @Result TABLE
(
    SalesPersonID INT,
    Total MONEY
)
AS
BEGIN
    INSERT INTO @Result
    SELECT 
        SalesPersonID, 
        SUM(SubTotal) AS Total
    FROM Sales.SalesOrderHeader
    WHERE SalesPersonID IS NOT NULL 
        AND MONTH(OrderDate) = @MonthOrder
        AND YEAR(OrderDate) = @YearOrder
    GROUP BY SalesPersonID;

    RETURN;
END;
GO

SELECT * FROM dbo.TotalOfEmp(3, 2008);

--9)  Viết lại các câu 5,6,7,8 bằng Multi-statement table valued  function
--5

CREATE FUNCTION NewBonus()
RETURNS @Result TABLE
(
    SalesPersonID INT,
    SumOfSubTotal MONEY,
    NewBonus MONEY
)
AS
BEGIN
    INSERT INTO @Result
    SELECT 
        SalesPersonID, 
        SUM(SubTotal) AS SumOfSubTotal,
        MAX(Bonus) + SUM(SubTotal) * 0.01 AS NewBonus
    FROM Sales.SalesPerson sp
    JOIN Sales.SalesOrderHeader soh ON sp.BusinessEntityID = soh.SalesPersonID
    WHERE SalesPersonID IS NOT NULL
    GROUP BY SalesPersonID;

    RETURN;
END;
GO

-- Gọi hàm
SELECT * FROM dbo.NewBonus();

--6
CREATE FUNCTION SumOfProduct (@MaNCC INT)
RETURNS @Result TABLE
(
    ProductID INT,
    SumOfQty INT,
    SumOfSubTotal MONEY
)
AS
BEGIN
    INSERT INTO @Result
    SELECT 
        pod.ProductID,
        SUM(pod.OrderQty) AS SumOfQty,
        SUM(pod.LineTotal) AS SumOfSubTotal
    FROM Purchasing.PurchaseOrderDetail pod
    JOIN Purchasing.PurchaseOrderHeader poh ON pod.PurchaseOrderID = poh.PurchaseOrderID
    WHERE poh.VendorID = @MaNCC
    GROUP BY pod.ProductID;

    RETURN;
END;
GO

-- Gọi hàm
SELECT * FROM dbo.SumOfProduct(1652);

--7
CREATE FUNCTION Discount_Func()
RETURNS @Result TABLE
(
    SalesOrderID INT,
    SubTotal MONEY,
    Discount MONEY
)
AS
BEGIN
    INSERT INTO @Result
    SELECT 
        SalesOrderID,
        SubTotal,
        CASE 
            WHEN SubTotal < 1000 THEN 0
            WHEN SubTotal >= 1000 AND SubTotal < 5000 THEN SubTotal * 0.05
            WHEN SubTotal >= 5000 AND SubTotal < 10000 THEN SubTotal * 0.10
            ELSE SubTotal * 0.15
        END AS Discount
    FROM Sales.SalesOrderHeader;

    RETURN;
END;
GO

-- Gọi hàm
SELECT * FROM dbo.Discount_Func();

--8
CREATE FUNCTION TotalOfEmp (@MonthOrder INT, @YearOrder INT)
RETURNS @Result TABLE
(
    SalesPersonID INT,
    Total MONEY
)
AS
BEGIN
    INSERT INTO @Result
    SELECT 
        SalesPersonID, 
        SUM(SubTotal) AS Total
    FROM Sales.SalesOrderHeader
    WHERE SalesPersonID IS NOT NULL
        AND MONTH(OrderDate) = @MonthOrder
        AND YEAR(OrderDate) = @YearOrder
    GROUP BY SalesPersonID;

    RETURN;
END;
GO

-- Gọi hàm
SELECT * FROM dbo.TotalOfEmp(3, 2008);


--10)  Viết hàm tên SalaryOfEmp trả về kết quả là bảng lương của nhân viên, với tham 
--số  vào  là  @MaNV  (giá  trị  của  [BusinessEntityID]),  thông  tin  gồm 
--BusinessEntityID, FName, LName, Salary (giá trị của cột  Rate).
--  Nếu giá trị của tham số truyền vào là Mã nhân viên khác Null thì kết 
--quả là bảng lương của nhân viên  đó.

CREATE FUNCTION SalaryOfEmp(@MaNV INT)
RETURNS @Result TABLE
(
    BusinessEntityID INT,
    FName NVARCHAR(50),
    LName NVARCHAR(50),
    Salary MONEY
)
AS
BEGIN
    INSERT INTO @Result
    SELECT 
        e.BusinessEntityID,
        p.FirstName AS FName,
        p.LastName AS LName,
        e.Rate AS Salary
    FROM HumanResources.EmployeePayHistory e
    JOIN HumanResources.Employee emp ON e.BusinessEntityID = emp.BusinessEntityID
    JOIN Person.Person p ON emp.BusinessEntityID = p.BusinessEntityID
    WHERE (@MaNV IS NULL OR e.BusinessEntityID = @MaNV);

    RETURN;
END;
GO


SELECT * FROM dbo.SalaryOfEmp(NULL);

SELECT * FROM dbo.SalaryOfEmp(123);