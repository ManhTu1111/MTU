--I
--1.Liệt kê danh sách các hóa đơn (SalesOrderID) lập trong tháng 6 năm 2008 có 
--tổng tiền >70000, thông tin gồm SalesOrderID, Orderdate, SubTotal, trong đó 
--SubTotal =SUM(OrderQty*UnitPrice).

use AdventureWorks2008R2

select
	[Sales].[SalesOrderHeader].[SalesOrderID],
	[Sales].[SalesOrderHeader].[OrderDate],
	sum([Sales].[SalesOrderDetail].[OrderQty]*[Sales].[SalesOrderDetail].[UnitPrice]) as SubTotal
from
	[Sales].[SalesOrderHeader]
join
	[Sales].[SalesOrderDetail] on [Sales].[SalesOrderHeader].[SalesOrderID] = [Sales].[SalesOrderDetail].[SalesOrderID]
where
	year([Sales].[SalesOrderHeader].[OrderDate])=2008 and month([Sales].[SalesOrderHeader].[OrderDate])=6
group by
	[Sales].[SalesOrderHeader].[SalesOrderID], [Sales].[SalesOrderHeader].[OrderDate]
having
	sum([Sales].[SalesOrderDetail].[OrderQty]*[Sales].[SalesOrderDetail].[UnitPrice]) > 70000;

--2.Đếm tổng số khách hàng và tổng tiền của những khách hàng thuộc các quốc gia 
--có mã vùng là US (lấy thông tin từ các bảng Sales.SalesTerritory, 
--Sales.Customer, Sales.SalesOrderHeader, Sales.SalesOrderDetail). Thông tin 
--bao gồm TerritoryID, tổng số khách hàng (CountOfCust), tổng tiền 
--(SubTotal) với SubTotal = SUM(OrderQty*UnitPrice) 

select 
	ST.TerritoryID,
	count(distinct C.CustomerID) as CountOfCust,
	sum(SOD.OrderQty * SOD.UnitPrice) as SubTotal
from
	[Sales].[SalesTerritory] as ST join
	[Sales].[Customer] as C on ST.TerritoryID = C.TerritoryID join
	[Sales].[SalesOrderHeader] as SOH on C.CustomerID = SOH.CustomerID join
	[Sales].[SalesOrderDetail] as SOD on SOH.SalesOrderID = SOD.SalesOrderID
where
	ST.CountryRegionCode = 'US'
GROUP BY 
	ST.TerritoryID;

--3.Tính tổng trị giá của những hóa đơn với Mã theo dõi giao hàng 
--(CarrierTrackingNumber) có 3 ký tự đầu là 4BD, thông tin bao gồm 
--SalesOrderID, CarrierTrackingNumber, SubTotal=SUM(OrderQty*UnitPrice) 

select
	SOH.SalesOrderID,
	SOD.CarrierTrackingNumber,
	sum(SOD.OrderQty * SOD.UnitPrice) as SubTotal
from
	Sales.SalesOrderHeader as SOH join
	Sales.SalesOrderDetail as SOD on SOH.SalesOrderID = SOD.SalesOrderID 
where
	left(SOD.CarrierTrackingNumber,3) = '4BD'
group by
	SOH.SalesOrderID, SOD.CarrierTrackingNumber;

--4.Liệt kê các sản phẩm (Product) có đơn giá (UnitPrice)<25 và số lượng bán 
--trung bình >5, thông tin gồm ProductID, Name, AverageOfQty.

select
	P.ProductID,
	P.Name,
	AVG(SOD.OrderQty) as AverageOfQty
from
	Production.Product as P join
	Sales.SalesOrderDetail as SOD on P.ProductID = SOD.ProductID
where
	P.StandardCost < 25
group by
	P.ProductID,
	P.Name
having
	avg(SOD.OrderQty) > 5;

--5.Liệt kê các công việc (JobTitle) có tổng số nhân viên >20 người, thông tin gồm 
--JobTitle, CountOfPerson=Count(*) 

select
	E.JobTitle, count(*) as CountOfPerson
from
	HumanResources.Employee as E
group by
	E.JobTitle
having count(*) > 20;

--6.Tính tổng số lượng và tổng trị giá của các sản phẩm do các nhà cung cấp có tên 
--kết thúc bằng ‘Bicycles’ và tổng trị giá > 800000, thông tin gồm 
--BusinessEntityID, Vendor_Name, ProductID, SumOfQty, SubTotal 
--(sử dụng các bảng [Purchasing].[Vendor], [Purchasing].[PurchaseOrderHeader] và 
--[Purchasing].[PurchaseOrderDetail])

select
	V.BusinessEntityID,
	V.Name as Vender_Name,
	POD.ProductID,
	sum(POD.OrderQty) as SumOfQty,
	sum(POD.LineTotal) as SubTotal
from
	Purchasing.Vendor as V join
	Purchasing.PurchaseOrderHeader as POH on V.BusinessEntityID = POH.VendorID join
	Purchasing.PurchaseOrderDetail AS POD on POH.PurchaseOrderID = POD.PurchaseOrderID
where 
	V.Name like '%Bicycles'
group by
	V.BusinessEntityID,
	V.Name,
	POD.ProductID
having
	SUM(POD.LineTotal) > 800000;

--7.Liệt kê các sản phẩm có trên 500 đơn đặt hàng trong quí 1 năm 2008 và có tổng 
--trị giá >10000, thông tin gồm ProductID, Product_Name, CountOfOrderID và 
--SubTotal

select
	P.ProductID,
	P.Name as Product_Name,
	count(SOH.SalesOrderID) as CountOfOrderID,
	sum(SOD.LineTotal) as SubTotal
from
	Production.Product as P join
	Sales.SalesOrderDetail as SOD on P.ProductID = SOD.ProductID join
	Sales.SalesOrderHeader as SOH on SOD.SalesOrderID = SOH.SalesOrderID
where
	year(SOH.OrderDate) = 2008
	and datepart(quarter, SOH.OrderDate) = 1
group by
	P.ProductID,
	P.Name

--8.Liệt kê danh sách các khách hàng có trên 25 hóa đơn đặt hàng từ năm 2007 đến 
--2008, thông tin gồm mã khách (PersonID) , họ tên (FirstName +'   '+ LastName 
--as FullName), Số hóa đơn (CountOfOrders).

select
	C.PersonID,
	concat(P.FirstName, ' ', P.LastName) as FullName,
	count(SOH.SalesOrderID) as CountOfOrders
from
	Sales.Customer as C join
	Person.Person as P on C.PersonID = P.BusinessEntityID join
	Sales.SalesOrderHeader as SOH on C.CustomerID = SOH.CustomerID
where
	year(SOH.OrderDate) between 2007 and 2008
group by
	C.PersonID,
	P.FirstName,
	P.LastName
having
	count(SOH.SalesOrderID) > 25

--9.Liệt kê những sản phẩm có tên bắt đầu với ‘Bike’ và ‘Sport’ có tổng số lượng 
--bán trong mỗi năm trên 500 sản phẩm, thông tin gồm ProductID, Name, 
--CountOfOrderQty, Year. (Dữ liệu lấy từ các bảng Sales.SalesOrderHeader, 
--Sales.SalesOrderDetail  và Production.Product) 

select
	P.ProductID,
	P.Name,
	year(SOH.OrderDate) as Year,
	sum(SOD.OrderQty) as CountOfOrderQty
from
	Production.Product as P join
	Sales.SalesOrderDetail as SOD on P.ProductID = SOD.ProductID join
	Sales.SalesOrderHeader as SOH on SOH.SalesOrderID = SOD.SalesOrderID
where
	P.Name like 'Bike%' or P.Name like 'Sport%'
group by
	P.ProductID,
	P.Name,
	year(SOH.OrderDate)
having
	sum(SOD.OrderQty) > 500

--10. Liệt kê những phòng ban có lương (Rate: lương theo giờ) trung bình >30, thông 
--tin gồm Mã phòng ban (DepartmentID), tên phòng ban (Name), Lương trung 
--bình (AvgofRate)

select
	D.DepartmentID,
	D.Name,
	avg(EPH.Rate) as AvgofRate
from
	HumanResources.Department as D join
	HumanResources.EmployeeDepartmentHistory as EDH on D.DepartmentID = EDH.DepartmentID join
	HumanResources.EmployeePayHistory as EPH on EDH.BusinessEntityID = EPH.BusinessEntityID
group by
	D.DepartmentID,
	D.Name
having
	avg(EPH.Rate) > 30

--II--------------------------------------------------------------------------------
--1.Liệt kê các sản phẩm gồm các thông tin Product Names và Product ID có 
--trên 100 đơn đặt hàng trong tháng 7 năm 2008 

select
	P.ProductID,
	P.Name as ProductName
from
	Production.Product as P join
	Sales.SalesOrderDetail as SOD on P.ProductID = SOD.ProductID join
	Sales.SalesOrderHeader as SOH on SOD.SalesOrderID = SOH.SalesOrderID
where
	year(SOH.OrderDate) = 2008
	and month(SOH.OrderDate) = 7
group by
	P.ProductID,
	P.Name
having
	count(SOH.SalesOrderID) > 10;

--2.Liệt kê các sản phẩm (ProductID, Name) có số hóa đơn đặt hàng nhiều nhất 
--trong tháng 7/2008 

select top 1
	P.ProductID,
	P.Name,
	count(SOH.SalesOrderID) as OrderCount
from
	Production.Product as P join
	Sales.SalesOrderDetail as SOD on P.ProductID = SOD.ProductID join
	Sales.SalesOrderHeader as SOH on SOD.SalesOrderID = SOH.SalesOrderID
where 
	year(SOH.OrderDate) = 2008 and month(SOH.OrderDate) = 7
group by
	P.ProductID,
	P.Name
order by
	OrderCount DESC;

--3.Hiển thị thông tin của khách hàng có số đơn đặt hàng nhiều nhất, thông tin gồm: 
--CustomerID, Name, CountOfOrder

select top 1
	C.CustomerID,
	CONCAT(P.FirstName, ' ',P.LastName),
	count(SOH.SalesOrderID) as CountOfOrder
from
	Sales.Customer as C join
	Person.Person as P on C.PersonID = P.BusinessEntityID join
	Sales.SalesOrderHeader as SOH on C.CustomerID = SOH.CustomerID
group by
	C.CustomerID,
	P.FirstName,
	P.LastName
order by
	CountOfOrder DESC;

--4.Liệt kê các sản phẩm (ProductID, Name) thuộc mô hình sản phẩm áo dài tay với 
--tên bắt đầu với “Long-Sleeve Logo Jersey”, dùng phép IN và EXISTS, (sử dụng 
--bảng Production.Product và Production.ProductModel)

select
	P.ProductID,
	P.Name
from
	Production.Product as P
where
	P.ProductModelID in (
		select	
			PM.ProductModelID
		from
			Production.ProductModel as PM
		where
			PM.Name like 'Long-Sleeve Logo Jersey%'
	)
	and exists (
		select 1
		from
			Production.ProductModel as PM
		where
			PM.ProductModelID = P.ProductModelID
			and PM.Name like 'Long-Sleeve Logo Jersey%'
	);

--5.Tìm các mô hình sản phẩm (ProductModelID) mà giá niêm yết (list price) tối 
--đa cao hơn giá trung bình của tất cả các mô hình.

select 
	PM.ProductModelID
from
	Production.ProductModel as PM
where
	(select max(ListPrice) from Production.Product as P where PM.ProductModelID = P.ProductModelID) >
	(select avg(ListPrice) from Production.Product);

--6.Liệt kê các sản phẩm gồm các thông tin ProductID, Name, có tổng số lượng 
--đặt hàng > 5000 (dùng IN, EXISTS)

select
	P.ProductID, P.Name
from
	Production.Product as P 
where
	P.ProductID in (
		select
			SOD.ProductID
		from
			Sales.SalesOrderDetail as SOD
		group by
			SOD.ProductID
		having
			sum(SOD.OrderQty)>5000
	)
	or exists (
		select 1
		from
			Sales.SalesOrderDetail as SOD
		where
			SOD.ProductID = P.ProductID
			and SOD.OrderQty > 5000
	);

--7.Liệt kê những sản phẩm (ProductID, UnitPrice) có đơn giá (UnitPrice) cao 
--nhất trong bảng Sales.SalesOrderDetail

select top 1
	SOD.ProductID,
	SOD.UnitPrice
from
	Sales.SalesOrderDetail as SOD
order by
	SOD.UnitPrice desc;

--8.Liệt kê các sản phẩm không có đơn đặt hàng nào thông tin gồm ProductID, 
--Nam; dùng 3 cách Not in, Not exists và Left join.

select
	p.ProductID,
	p.Name
from
	Production.Product as P
where
	P.ProductID not in (
		select
			SOD.ProductID
		from
			Sales.SalesOrderDetail as SOD
	);

select
	p.ProductID,
	p.Name
from
	Production.Product as P
where
	not exists (
		select 1
		from
			Sales.SalesOrderDetail as SOD
		where
			SOD.ProductID = P.ProductID
	);

--9.Liệt kê các nhân viên không lập hóa đơn từ sau ngày 1/5/2008, thông tin gồm 
--EmployeeID, FirstName, LastName (dữ liệu từ 2 bảng HumanResources.Employees và Sales.SalesOrdersHeader) 

select
	P.BusinessEntityID as EmployeeID,
	P.FirstName,
	P.LastName
from
	HumanResources.Employee as E join
	Person.Person as P on E.BusinessEntityID = P.BusinessEntityID
where
	E.BusinessEntityID not in (
		select
			SOH.SalesPersonID
		from
			Sales.SalesOrderHeader as SOH
		where
			SOH.OrderDate > '2008-05-01'
	);

--10.Liệt kê danh sách các khách hàng (CustomerID, Name) có hóa đơn dặt hàng 
--trong năm 2007 nhưng không có hóa đơn đặt hàng trong năm 2008. 

select
	C.CustomerID,
	concat(P.FirstName, ' ',P.LastName)
from
	Sales.Customer as C join
	Person.Person as P on C.PersonID = P.BusinessEntityID
where
	C.CustomerID in (
		select 
			SOH.CustomerID
		from
			Sales.SalesOrderHeader as SOH
		where
			year(SOH.OrderDate) = 2007
	)
	and C.CustomerID not in (
		select 
			SOH.CustomerID
		from
			Sales.SalesOrderHeader as SOH
		where
			year(SOH.OrderDate) = 2008
	);