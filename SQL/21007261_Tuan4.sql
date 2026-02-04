use Northwind

-- tuan 4 
-- bai tao 1 lenh select 0 truy van don gian 
--1
SELECT *
FROM Products
  --2 
  SELECT
  ProductID,
  ProductName,
  UnitPrice
FROM
  Products
-- 3 Danh sach cac nhan vien (employees) 



-- lay thuoc tinh tu bang 
select EmployeeID, LastName, FirstName, HomePhone, BirthDate -- danh sach thuoc tinh 
from Employees -- ten bang 


select * [EmployeeID], [LastName] , [FirstName]
from [dbo].[Employees]



-- them cac pphep tinh tren cac thuoc tinh 
select EmployeeID , LastName+ ' ' + FirstName as Name, HomePhone , BirthDate, -- danh sach thuoc tinh 
Age = year(GetDate())-year(Birthdate)
from Employees
--4
SELECT
  CustomerID,
  CompanyName,
  ContactName,
  ContactTitle,
  City,
  Phone
FROM
  Customers
WHERE
  ContactTitle LIKE 'O%'
  --5
  SELECT
  CustomerID,
  CompanyName,
  ContactName,
  City
FROM
  Customers
WHERE
  City IN ('London', 'Boise', 'Paris')
--6 liet ke dan hsach khach hang co ten bat dau bagn chu V
-- ma o thanh pho Lyon
select * from Customers

select * from customers where CompanyName Like 'V%'

select * from Customers
where CompanyName like 'V%' and City = 'Lyon'

-- 7 liet ke danh sach cac khach hang ko co fax
select * 
from Customers
where Fax is null -- k co so fax 

-- chi neu  cac thong tin can thiet trong bang  : customerID , companyName , Fax
select CustomerID,CompanyName,Fax
from Customers
where Fax is null 

-- 8 liet ke danh asch khach hang customers co so fax 
select customerID , CompanyName , Fax
from Customers
where Fax is not null -- co so Fax 
--9 
SELECT
  EmployeeID,
  LastName,
  FirstName,
  BirthDate
FROM
  Employees
WHERE
  year(BirthDate) <= 1960

-- 10 danh sach cac san pham products co tu 'Boxes' trong cot  QuantityPerUnit 
select * from Products 

select * 
from Products
where QuantityPerUnit like ' boxes%'
--11
SELECT
  ProductID,
  ProductName,
  UnitPrice
FROM
  Products
WHERE
  UnitPrice > 10
  AND UnitPrice < 15
  --12 
  SELECT
  ProductID,
  ProductName,
  UnitsInStock
FROM
  Products
WHERE
  UnitsInStock < 5

-- 13 liet ke danh sach cac mat hang ng voi tien ton von, .....
select ProductID , ProductName , [UnitPrice] , [UnitsInStock], Total = [UnitsInStock]*[UnitPrice]
from Products
order by Total DESC -- ten ton von ( giam dan ) 
--14 
SELECT
  OrderID,
  OrderDate,
  CustomerID,
  EmployeeID
FROM
  Orders
WHERE
  OrderID IN ('10248', '10250')
  --15 
  SELECT
  OrderID,
  ProductID,
  Quantity,
  UnitPrice,
  Discount,
  Quantity * UnitPrice * (1 - Discount) AS TotalLine
FROM
  [dbo].[Order Details]
WHERE
  OrderID = '10248'
-- 16 liet ke danh sach cac hoa don co orderdate dc lap ......

SELECT
	DATEPART(YEAR, GETDATE()) AS YY, --N?m--
	DATEPART(MONTH, GETDATE()) AS MM, --Tháng--
	DATEPART(DAY, GETDATE()) AS DD, --Ngày--
	DATEPART(QUARTER, GETDATE()) AS QQ, --Q?y--
	DATEPART(WEEKDAY, GETDATE()) AS DW 
select OrderID , [CustomerID] , OrderDate
from Orders
where month(OrderDate)= 9 and year(OrderDate)= 1996
-- where MM = 9 and YY = 1996 
order by CustomerID ASC , OrderDate DESC

-- 17  liet ke danh sach cac hoa don orders dc lap trong quy 4 nam 1997-- 

SELECT
  OrderID,
  OrderDate,
  CustomerID,
  EmployeeID
FROM
  Orders
WHERE YEAR(OrderDate) = 1997 AND 
DATEPART(QUARTER, OrderDate) = 4


-- 18  liet ke danh sach cac hoa don  dc lap trong ngay thu 7 va cn 

select OrderID, OrderDate, CustomerID, employeeID, DATEPART(WEEKDAY, OrderDate) AS WeekDayOfOrderDate
from Orders
WHERE YEAR(OrderDate) = 1997 AND MONTH(OrderDate) = 12 AND DATEPART(WEEKDAY, OrderDate) IN (7, 1); 

--19 danh sach 5 customers co city bat dau 'M'
select * from Customers where City like 'M%'

select top 5 * -- loc ra 5 customers dau tien 
from Customers where City like 'M%'

-- 20  liet ke dadnh sach 2 employees co tuoi lon nhat...
select EmployeeID, LastName+' '+ FirstName as EmployeeName,
       Age = year(GETDATE())-year(BirthDate)
from Employees
order by Age DESC -- tuoi sap theo thu tu giam 

-- lay 2 khach hang cao tuooi nhat : top 2 
select Top 2 EmployeeID, LastName+' '+FirstName as EmployeeName,
Age = year(GetDate())-year(BirthDate)
from Employees
order by Age  
