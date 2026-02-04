-- tuan 5 
use Northwind

-- bai tap 2 lenh select - truy van co ket noi 

select O.OrderID, OrderDate, CustomerID, EmployeeID, ProductId, Quantity , Unitprice, Discount 
from Orders O inner join [dbo].[Order Details] D
	on O.OrderID=D.OrderID 
where O.OrderID = '10248'

--2  liet ke cac khach hang co lap hoa don trong thang  7/1997 vafa 9 /1997

-- tim hieu cac thuoc tinh 
select * from Customers -- khang 
select * from Orders -- hoa don 
--1 khach hnag lap nhiu hoa don 
-- dung inner hoin ket nhieu bang
select C.CustomerID, C.CompanyName,C.Address, O.OrderID,O.OrderDate
from customers as C inner join Orders as O -- join ... on. ..
			   on C.CustomerID=O.CustomerID

-- vieest tat join thay cho inner join  bo as bo ten tat cho cac cot c hi co tren 1 bang 
select C.CustomerID, CompanyName , Address , OrderID , OrderDate 
from Customers C join Orders O 
			   on C.CustomerID=O.CustomerID

-- thang 7, nam 1997 hoac thang 9 nam 1 1997 dung where 
select C.CustomerID , CompanyName, Address, OrderId, OrderDate 
from Customers C  join Orders O on C.CustomerID=O.CustomerID
where (MONTH(OrderDate)=7 OR MONTH(OrderDate)=9) and YEAR (OrderDate)=1997 -- 70 dong 


-- duoc sap xep theo CustomerId, cung customerId thi sap xxep theo OrderDate giam dan 
order by C.CustomerID ASC, OrderDate DESC

-- casch lam khac 
-- ham datepart ( datepart, date ) 

-- datepart : chu viet tat 
-- year : yy, yyyy
-- quarter : qq, q 
-- Month : mm, m 
-- day : dd, d 
-- day of week : dw 

-- hom nay : ham GETDATE()
select DATEPART("YY",GETDATE()) as YEAR , -- Nam 
	   DATEPART("mm",GETDATE()) as Month , -- thang
	   DATEPART("dd",GETDATE()) as Day , -- ngay
	   DATEPART("qq",GETDATE()) as Quarter , -- quy 
	   DATEPART("dw",GETDATE()) as [Day of week]  -- thu 

--3 liet ke danh sach cac mat hang .....
select * from Products
select * from Orders
-- con quantity o bang nao ? 
select * from [dbo].[Order Details]
-- >  ket 3  bang oorders , [ order details ] , products

-- xuat ban ngay 19/7/1997 tim hieu cac thong so qua 1 bang orders 
select OrderID, CustomerID,OrderDate,RequiredDate,ShippedDate
from Orders
Where DATEPART("yy",OrderDate)=1996 and DATEPART ("mm", OrderDAte)=7
	  and DATEPART("dd",OrderDate)=19
-- viet cach khac , nho dinh dang mac dinh  : yyyy/mm/dd 
select OrderID, CustomerID,OrderDate,RequiredDate,ShippedDate
from Orders
where OrderDate='1996/07/19'

--  hay 
select OrderID, CustomerID, OrderDate, RequiredDate, ShippedDate
from Orders 
where OrderDate = '1996-07-19'

--  giai day du ( co ket 3 bang ) 
select P.ProductID, ProductName, O.OrderID, OrderDate, Quantity
from Orders O join [dbo].[Order Details] OD on O.OrderID=OD.OrderID
			  join Products P on OD.ProductID=P.ProductID
where OrderDate='19/07/1996' -- 6 dong ( neeus dung dinh dang dd/mm/yyyy)


--4 liet ke danh sach cac mat hang tu nha cung cap supplier co ma 1,3,6 ....
SELECT P.ProductID, P.ProductName, P.SupplierID, O.OrderID, Quantity
FROM Products AS P
JOIN Suppliers AS S ON P.SupplierID = S.SupplierID
JOIN [dbo].[Order Details] AS OD ON P.ProductID = OD.ProductID
JOIN Orders AS O ON OD.OrderID = O.OrderID
WHERE S.SupplierID IN (1, 3, 6)
    AND YEAR(O.OrderDate) = 1997
    AND DATEPART(QUARTER, O.OrderDate) = 2
ORDER BY P.SupplierID, P.ProductID;
-- 5 danh sách các mặt hàng có đơn giá bằng don gia mua 
select P.ProductID, ProductName , P.UnitPrice as P_UnitPrice,
	   OD.UnitPrice as OD_UnitPrice
from Products P inner join [dbo].[Order Details] OD
     on P.ProductID=OD.ProductID
where P.UnitPrice=OD.UnitPrice -- basn bang gia von 

-- 6 danh sach cac mat hang ban trong ngay thu 7 va OR chu nhat cua thang 12 nam 1996 
-- thu 7 : DATEPART("dw",OrderDAte)=7
-- chu nhat : DATEPART ("dw", OrderDate)=1
SELECT P.ProductID, P.ProductName, OD.OrderID, OD.Quantity
FROM Products AS P
JOIN [dbo].[Order Details] AS OD ON P.ProductID = OD.ProductID
JOIN Orders AS O ON OD.OrderID = O.OrderID
WHERE (DATEPART(dw, O.OrderDate) = 7 OR DATEPART(dw, O.OrderDate) = 1)
    AND MONTH(O.OrderDate) = 12
    AND YEAR(O.OrderDate) = 1996
ORDER BY O.OrderDate;

-- 7 Liệt kê danh sách các nhân viên đã lập hóa đơn trong tháng 7 của năm
--1996. Thông tin gồm : EmployeeID, EmployeeName, OrderID,
--Orderdate
SELECT E.EmployeeID, E.LastName,E.FirstName, O.OrderID, O.OrderDate
FROM Employees AS E
JOIN Orders AS O ON E.EmployeeID = O.EmployeeID
WHERE MONTH(O.OrderDate) = 7
    AND YEAR(O.OrderDate) = 1996
ORDER BY E.EmployeeID, O.OrderDate;
-- 8 Liệt kê danh sách các hóa đơn do nhân viên có Lastname là ‘Fuller’ lập.
--Thông tin gồm : OrderID, Orderdate, ProductID, Quantity, Unitprice.

SELECT O.OrderID, O.OrderDate, OD.ProductID, OD.Quantity, OD.UnitPrice
FROM Orders AS O
JOIN Employees AS E ON O.EmployeeID = E.EmployeeID
JOIN [dbo].[Order Details] AS OD ON O.OrderID = OD.OrderID
WHERE E.LastName = 'Fuller';

-- caach khac 
SELECT CustomerID, [ContactName], Fax
FROM Customers
WHERE Fax IS NOT NULL;
-- 9 
--Liệt kê chi tiết bán hàng của mỗi nhân viên theo từng hóa đơn trong năm
--1996. Thông tin gồm: EmployeeID, EmployName, OrderID, Orderdate,
--ProductID, quantity, unitprice, ToTalLine=quantity*unitprice.

SELECT E.EmployeeID, E.LastName,E.FirstName OD.OrderID, O.OrderDate, OD.ProductID, OD.Quantity, OD.UnitPrice, (Quantity * OD.UnitPrice) AS TotalLine
FROM Employees AS E
JOIN Orders AS O ON E.EmployeeID = O.EmployeeID
JOIN [dbo].[Order Details] AS OD
JOIN [dbo].[Order Details]  O.OrderID = OD.OrderID
WHERE YEAR(O.OrderDate) = 1996
ORDER BY E.EmployeeID, O.OrderID;


-- 10  . Danh sách các đơn hàng sẽ được giao trong các thứ 7 của tháng 12 năm
--1996
-- cach khac 
SELECT OrderID, OrderDate, CustomerID
FROM Orders
WHERE DATEPART(dw, OrderDate) = 7
    AND MONTH(OrderDate) = 12
    AND YEAR(OrderDate) = 1996;

-- cach khac 
select P.ProductID,ProductName, OD.OrderID, OrderDate,CustomerID, Od.Unitprice,Quantity,
	ToTal = Quantity*OD.UnitPrice
from Orders O join [dbo].[Order Details] OD on O.OrderID =  OD.OrderID
		      join Products P on OD.ProductID=P.ProductID
where DATEPART (dw,OrderDate) = 7 and 
	  DATEPART (mm,OrderDate)=12 and DATEPART(yy,OrderDate)=1996

order by ProductID, quantity DESC -- khong  co so lieu 

--11 liet ke danh sacsh cac nhan vien chua lap hoa don dung left join/ right join ) 
select * 
from Employees E left join Orders O -- left Join 
				 on E.EmployeeID = O.EmployeeID
where O.EmployeeID is null -- ma nv k co tren hoa don 
-- viet cach khac 
select * 
from Orders O right join Employees E --right join 
			  on E.EmployeeID = O.EmployeeID
where O.EmployeeID is null -- ma nv k co tren hoa don 

-- chen them 1 nv moi 
select * from Employees -- k cos EmployeeID = 10 
insert Employees(LastName, FirstName ) values ( N'Anh',N'Trần') -- bỏ EmployeeID vì có thuộc tính Identity


--12 
--Liệt kê danh sách các sản phẩm chưa bán được (dùng LEFT
--JOIN/RIGHT JOIN)
select P.ProductID as 'P..ProductID' , Quantity , OD.ProductID as 'OD.ProductID'
from Products P left outer join  OD on P.ProductID=OD.ProductID -- left join 
where OD.ProductID is null 
-- k co du lieu => moi san pham ddeu dc ban 

-- chen  1 sp va kt 
select * from Products -- k co productID = 78 

insert Products(ProductName,Discoutinued)
values (N'Sản phẩm mới' , 0 ) -- bỏ productid

--13. Liệt kê danh sách các khách hàng chưa mua hàng lần nào (dùng LEFT
--JOIN/RIGHT JOIN).
SELECT C.CustomerID, C.CustomerName
FROM Customers AS C
LEFT JOIN Orders AS O ON C.CustomerID = O.CustomerID
WHERE O.OrderID IS NULL;