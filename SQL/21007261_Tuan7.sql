--TUẦN 8 (3 TIẾT)
--BÀI TẬP 4: LỆNH SELECT – TRUY VẤN LỒNG NHAU
--1. Liệt kê các product có đơn giá mua lớn hơn đơn giá mua trung bình của
--tất cả các product.
use Northwind
select AVG(UnitPrice) as TrungBinh from Products 
--2. Liệt kê các product có đơn giá mua lớn hơn đơn giá mua nhỏ nhất của tất
--cả các product.
SELECT *
FROM products
WHERE UnitPrice > (SELECT MIN(UnitPrice) FROM products)

--3. Liệt kê các product có đơn giá bán lớn hơn đơn giá bán trung bình của
--các product. Thông tin gồm ProductID, ProductName, OrderID,
--Orderdate, Unitprice .

SELECT p.ProductID, p.ProductName, p.UnitPrice
FROM products p
INNER JOIN [Order Details] o ON p.ProductID = o.ProductID
WHERE p.UnitPrice > (SELECT AVG(UnitPrice) FROM products)

--4. Liệt kê các product có đơn giá bán lớn hơn đơn giá bán trung bình của
--các product có ProductName bắt đầu là ‘N’.
SELECT p.ProductID, p.ProductName, o.OrderID, p.UnitPrice
FROM products p
INNER JOIN [Order Details] o ON p.ProductID = o.ProductID
WHERE p.ProductName LIKE 'N%'
  AND p.UnitPrice > (SELECT AVG(UnitPrice) FROM products)

--5. Cho biết những sản phẩm có tên bắt đầu bằng ‘T’ và có đơn giá bán lớn
--hơn đơn giá bán của (tất cả) những sản phẩm có tên bắt đầu bằng chữ
--‘V’.
SELECT p.ProductID, p.ProductName, p.UnitPrice
FROM products p
WHERE p.ProductName LIKE 'T%'
  AND p.UnitPrice > ALL (SELECT UnitPrice FROM products WHERE ProductName LIKE 'V%')

--6. Cho biết sản phẩm nào có đơn giá bán cao nhất trong số những sản phẩm
--có đơn vị tính có chứa chữ ‘box’ .
SELECT ProductName , UnitPrice
FROM products
WHERE UnitPrice >= ALL  (SELECT UnitPrice FROM products WHERE ProductName LIKE '%box%')

--7. Liệt kê các product có tổng số lượng bán (Quantity) trong năm 1998 lớn
--hơn tổng số lượng bán trong năm 1998 của mặt hàng có mã 71
SELECT p.ProductID, p.ProductName, SUM(o.Quantity) AS TotalQuantity
FROM products p
INNER JOIN [Order Details] o ON p.ProductID = o.ProductID
WHERE YEAR(o.OrderID) = 1998
GROUP BY p.ProductID, p.ProductName
HAVING SUM(o.Quantity) > (SELECT SUM(Quantity) FROM [Order Details] WHERE ProductID = 71 AND YEAR(OrderID) = 1998)

--8. Thực hiện :
-- Thống kê tổng số lượng bán ứng với mỗi mặt hàng thuộc nhóm
--hàng có CategoryID là 4. Thông tin : ProductID, QuantityTotal
--(tập A)
-- Thống kê tổng số lượng bán ứng với mỗi mặt hàng thuộc nhóm
--hàng khác 4 . Thông tin : ProductID, QuantityTotal (tập B)
-- Dựa vào 2 truy vấn trên : Liệt kê danh sách các mặt hàng trong
--tập A có QuantityTotal lớn hơn tất cả QuantityTotal của tập B
SELECT ProductID, SUM(Quantity) AS QuantityTotal
FROM [Order Details]
WHERE ProductID IN (SELECT ProductID FROM products WHERE CategoryID = 4)
GROUP BY ProductID

SELECT ProductID, SUM(Quantity) AS QuantityTotal
FROM [Order Details]
WHERE ProductID IN (SELECT ProductID FROM products WHERE CategoryID <> 4)
GROUP BY ProductID

SELECT A.ProductID, A.QuantityTotal
FROM (
    SELECT ProductID, SUM(Quantity) AS QuantityTotal
    FROM [Order Details]
    WHERE ProductID IN (SELECT ProductID FROM products WHERE CategoryID = 4)
    GROUP BY ProductID
) AS A
WHERE A.QuantityTotal > ALL (
    SELECT SUM(Quantity) AS QuantityTotal
    FROM [Order Details]
    WHERE ProductID IN (SELECT ProductID FROM products WHERE CategoryID <> 4)
    GROUP BY ProductID
)

--9. Danh sách các Product có tổng số lượng bán được lớn nhất trong năm
--1998
--Lưu ý : Có nhiều phương án thực hiện các truy vấn sau (dùng JOIN hoặc
--subquery ). Hãy đưa ra phương án sử dụng subquery.
SELECT p.ProductID, p.ProductName, TotalQuantity
FROM products p
INNER JOIN (
  SELECT ProductID, SUM(Quantity) AS TotalQuantity
  FROM [Order Details]
  WHERE YEAR(OrderID) = 1998
  GROUP BY ProductID
) AS q ON p.ProductID = q.ProductID
WHERE TotalQuantity = (
  SELECT MAX(TotalQuantity)
  FROM (
    SELECT SUM(Quantity) AS TotalQuantity
    FROM [Order Details]
    WHERE YEAR(OrderID) = 1998
    GROUP BY ProductID
  ) AS t
)

--10. Danh sách các products đã có khách hàng mua hàng (tức là ProductID có
--trong [Order Details]). Thông tin bao gồm ProductID, ProductName,
--Unitprice
SELECT p.ProductID, p.ProductName, p.UnitPrice
FROM products p
WHERE p.ProductID IN (SELECT DISTINCT ProductID FROM [Order Details])

--11. Danh sách các hóa đơn của những khách hàng ở thành phố LonDon và
--Madrid.
SELECT o.OrderID, o.CustomerID, c.City
FROM orders o
JOIN customers c ON o.CustomerID = c.CustomerID
WHERE c.City IN ('London', 'Madrid')

--12.Liệt kê các sản phẩm có trên 20 đơn hàng trong quí 3 năm 1998, thông
--tin gồm ProductID, ProductName.
SELECT p.ProductID, p.ProductName
FROM products p
JOIN [Order Details] od ON p.ProductID = od.ProductID
JOIN orders o ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 1998 AND DATEPART(QUARTER, o.OrderDate) = 3
GROUP BY p.ProductID, p.ProductName
HAVING COUNT(DISTINCT o.OrderID) > 20

--13.Liệt kê danh sách các sản phẩm chưa bán được trong tháng 6 năm 1996

SELECT p.ProductID, p.ProductName
FROM products p
WHERE p.ProductID NOT IN (
  SELECT DISTINCT od.ProductID
  FROM [Order Details] od
  JOIN orders o ON od.OrderID = o.OrderID
  WHERE YEAR(o.OrderDate) = 1996 AND MONTH(o.OrderDate) = 6
)



--14. Liệt kê danh sách các Employes không lập hóa đơn vào ngày hôm nay
--14. Liệt kê danh sách các Employees không lập hóa đơn vào ngày hôm nay
--14. Liệt kê danh sách các Employees không lập hóa đơn vào ngày hôm nay
SELECT EmployeeID, FirstName, LastName
FROM Employees
WHERE EmployeeID NOT IN (
  SELECT DISTINCT EmployeeID
  FROM [dbo].[Orders]
  WHERE CAST(OrderDate AS DATE) = CAST(GETDATE() AS DATE)
)

--15.Liệt kê danh sách các Customers chưa mua hàng trong năm 1997
SELECT c.CustomerID, c.CompanyName 
FROM customers c
LEFT JOIN orders o ON c.CustomerID = o.CustomerID AND YEAR(o.OrderDate) = 1997
WHERE o.OrderID IS NULL
--16.Tìm tất cả các Customers mua các sản phẩm có tên bắt đầu bằng chữ T
--trong tháng 7 năm 1997
SELECT DISTINCT c.CustomerID, c.CompanyName
FROM customers c
JOIN orders o ON c.CustomerID = o.CustomerID
JOIN [dbo].[Order Details] od ON o.OrderID = od.OrderID
JOIN products p ON od.ProductID = p.ProductID
WHERE p.ProductName LIKE 'T%' AND YEAR(o.OrderDate) = 1997 AND MONTH(o.OrderDate) = 7

--17.Liệt kê danh sách các khách hàng mua các hóa đơn mà các hóa đơn này
--chỉ mua những sản phẩm có mã >=3
SELECT c.CustomerID, c.CompanyName
FROM customers c
JOIN orders o ON c.CustomerID = o.CustomerID
JOIN [dbo].[Order Details] od ON o.OrderID = od.OrderID
JOIN products p ON od.ProductID = p.ProductID
GROUP BY c.CustomerID, c.CompanyName
HAVING MIN(p.ProductID) >= 3

--18.Tìm các Customer chưa từng lập hóa đơn (viết bằng ba cách: dùng NOT
--EXISTS, dùng LEFT JOIN, dùng NOT IN )
-- su dung not exists
SELECT CustomerID, CompanyName
FROM Customers c
WHERE NOT EXISTS (
  SELECT *
  FROM Orders o
  WHERE o.CustomerID = c.CustomerID
)
-- su dung left join 
SELECT c.CustomerID, c.CompanyName
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL
-- su dung not in 
SELECT CustomerID, CompanyName
FROM Customers
WHERE CustomerID NOT IN (
  SELECT CustomerID
  FROM Orders
)

--19.Bạn hãy mô tả kết quả của các câu truy vấn sau ?
--Select ProductID, ProductName, UnitPrice From [Products]
--Where Unitprice>ALL (Select Unitprice from [Products] where
--ProductName like ‘N%’)
--Select ProductId, ProductName, UnitPrice From [Products]
--Where Unitprice>ANY (Select Unitprice from [Products] where
--ProductName like ‘N%’)
--Select ProductId, ProductName, UnitPrice from [Products]
--Where Unitprice=ANY (Select Unitprice from [Products] where
--ProductName like ‘N%’)
--Select ProductId, ProductName, UnitPrice from [Products]
--Where ProductName like ‘N%’ and
--Unitprice>=ALL (Select Unitprice from [Products] where
--ProductName like ‘N%’)
--giai : 
 
SELECT ProductID, ProductName, UnitPrice
FROM Products
WHERE UnitPrice > ALL (
  SELECT UnitPrice
  FROM Products
  WHERE ProductName LIKE 'N%'
)
-- 
SELECT ProductId, ProductName, UnitPrice
FROM Products
WHERE UnitPrice > ANY (
  SELECT UnitPrice
  FROM Products
  WHERE ProductName LIKE 'N%'
)
--
SELECT ProductId, ProductName, UnitPrice
FROM Products
WHERE UnitPrice = ANY (
  SELECT UnitPrice
  FROM Products
  WHERE ProductName LIKE 'N%'
)
--
SELECT ProductId, ProductName, UnitPrice
FROM Products
WHERE ProductName LIKE 'N%' AND UnitPrice >= ALL (
  SELECT UnitPrice
  FROM Products
  WHERE ProductName LIKE 'N%'
)
--


--------------------------------------------------------------------------

--BÀI TẬP 5: LỆNH SELECT – CÁC LOẠI TRUY VẤN KHÁC
--1. Sử dụng Select và Union để “hợp” tập dữ liệu lấy từ bảng Customers và
--Employees. Thông tin gồm CodeID, Name, Address, Phone. Trong đó
--CodeID là CustomerID/EmployeeID, Name là Companyname/LastName
--+ FirstName, Phone là Homephone.
SELECT ProductId, ProductName, UnitPrice
FROM Products
WHERE UnitPrice > ANY (
  SELECT CAST(UnitPrice AS FLOAT)
  FROM Products
  WHERE ProductName LIKE 'N%'
)

--2. Dùng lệnh SELECT...INTO tạo bảng HDKH_71997 chứa thông tin về
--các khách hàng gồm : CustomerID, CompanyName, Address, ToTal
--=sum(quantity*Unitprice) , với total là tổng tiền khách hàng đã mua
--trong tháng 7 năm 1997.
SELECT Customers.CustomerID, Customers.CompanyName, Customers.Address, SUM([dbo].[Order Details].Quantity * [dbo].[Order Details].UnitPrice) AS Total
INTO HDKH_71997
FROM Customers
JOIN Orders ON Customers.CustomerID = Orders.CustomerID
JOIN [dbo].[Order Details] ON Orders.OrderID = [dbo].[Order Details].[OrderID]
WHERE YEAR(Orders.OrderDate) = 1997 AND MONTH(Orders.OrderDate) = 7
GROUP BY Customers.CustomerID, Customers.CompanyName, Customers.Address;
--3. Dùng lệnh SELECT...INTO tạo bảng LuongNV chứa dữ liệu về nhân
--viên gổm : EmployeeID, Name = LastName + FirstName, Address,
--ToTal =10%*sum(quantity*Unitprice) , với Total là tổng lương của nhân
--viên trong tháng 12 năm 1996.
SELECT Employees.EmployeeID, CONCAT(Employees.LastName, ' ', Employees.FirstName) AS Name, Employees.Address, 0.1 * SUM([dbo].[Order Details].Quantity * [dbo].[Order Details].UnitPrice) AS Total
INTO LuongNV
FROM Employees
JOIN Orders ON Employees.EmployeeID = Orders.EmployeeID
JOIN [dbo].[Order Details] ON Orders.OrderID = [dbo].[Order Details].OrderID
WHERE YEAR(Orders.OrderDate) = 1996 AND MONTH(Orders.OrderDate) = 12
GROUP BY Employees.EmployeeID, Employees.LastName, Employees.FirstName, Employees.Address;
--4. Dùng lệnh SELECT...INTO tạo bảng Ger_USA chứa thông tin về các
--hóa đơn xuất bán trong quý 1 năm 1998 với địa chỉ nhận hàng thuộc các
--quốc gia (ShipCountry) là 'Germany' và 'USA', do công ty vận chuyển
--‘Speedy Express’ thực hiện.
SELECT Orders.OrderID, Customers.CompanyName, Customers.Address, Orders.ShipCountry
INTO Ger_USA
FROM Orders
JOIN Customers ON Orders.CustomerID = Customers.CustomerID
WHERE Orders.ShipCountry IN ('Germany', 'USA')
  AND Orders.ShipVia = (
    SELECT ShipperID
    FROM Shippers
    WHERE ShipName  = 'Speedy Express'
  )
  AND YEAR(Orders.OrderDate) = 1998
  AND MONTH(Orders.OrderDate) BETWEEN 1 AND 3;

--5. Pivot Query
--Tạo bảng dbo.HoaDonBanHang có cấu trúc sau
--CREATE TABLE dbo.HoaDonBanHang


--( orderid INT NOT NULL,
--orderdate DATE NOT NULL,
--empid INT NOT NULL,
--custid VARCHAR(5) NOT NULL,
--qty INT NOT NULL,
--CONSTRAINT PK_Orders PRIMARY KEY(orderid)
--)
--Chèn dữ liệu vào bảng
--(30001, '20070802', 3, 'A', 10),
--(10001, '20071224', 2, 'A', 12),
--(10005, '20071224', 1, 'B', 20),
--(40001, '20080109', 2, 'A', 40),
--(10006, '20080118', 1, 'C', 14),
--(20001, '20080212', 2, 'B', 12),
--(40005, '20090212', 3, 'A', 10),
--(20002, '20090216', 1, 'C', 20),
--(30003, '20090418', 2, 'B', 15),
--(30004, '20070418', 3, 'C', 22),
--(30007, '20090907', 3, 'D', 30)
--a) Tính tổng Qty cho mỗi nhân viên. Thông tin gồm empid, custid
--b) Tạo bảng Pivot có dạng sau
 -- INSERT INTO [dbo].[HoaDonBanHang] (OrderID, OrderDate, empid, custid, qty)
--VALUES
  --  (30001, '20070802', 3, 'A', 10),
 --   (10001, '20071224', 2, 'A', 12),
   -- (10005, '20071224', 1, 'B', 20),
  --  (40001, '20080109', 2, 'A', 40),
 --   (10006, '20080118', 1, 'C', 14),
   -- (20001, '20080212', 2, 'B', 12),
  --  (40005, '20090212', 3, 'A', 10),
   -- (20002, '20090216', 1, 'C', 20),
   -- (30003, '20090418', 2, 'B', 15),
   -- (30004, '20070418', 3, 'C', 22),
    --(30007, '20090907', 3, 'D', 30);
CREATE TABLE dbo.HoaDonBanHang
(
orderid INT NOT NULL,
orderdate DATE NOT NULL,
empid INT NOT NULL,
custid VARCHAR(5) NOT NULL,
qty INT NOT NULL,
CONSTRAINT PK_Orders PRIMARY KEY(orderid)
)


-- chèn dữ liệu vào bảng 
insert dbo.HoaDonBanHang values
(30001, '20070802', 3, 'A', 10),
(10001, '20071224', 2, 'A', 12),
(10005, '20071224', 1, 'B', 20),
(40001, '20080109', 2, 'A', 40),
(10006, '20080118', 1, 'C', 14),
(20001, '20080212', 2, 'B', 12),
(40005, '20090212', 3, 'A', 10),
(20002, '20090216', 1, 'C', 20),
(30003, '20090418', 2, 'B', 15),
(30004, '20070418', 3, 'C', 22),
(30007, '20090907', 3, 'D', 30)

select * from HoaDonBanHang 

--a
SELECT empid, custid, SUM(qty) AS  Sum 
FROM dbo.HoaDonBanHang1
GROUP BY empid, custid

-- b) Tạo bảng Pivot có dạng sau
--empid		A	 B		C		D
--1			NULL 20		34		NULL
--2			52	 27		NULL	30
--3			20   NULL	22		30
SELECT empid, [A], [B], [C], [D]
FROM(SELECT empid, custid, qty FROM dbo.HoaDonBanHang) AS D
PIVOT(SUM(qty) FOR custid IN ([A], [B], [C], [D])) AS P

--c) Tạo 1 query lấy dữ liệu từ bảng dbo.HoaDonBanHang trả về số hóa đơn
--đã lập của nhân viên employee trong mỗi năm.
SELECT DATENAME(yy, OrderDate) as OrderYear , count(OrderID) as CountOfOrders
FROM HoaDonBanHang 
group by DATENAME(yy, OrderDate) 
-- viet bang Pivot
select [2007] as Nam2007 , [2008] as Nam2008, [2009] as Nam2009 
from (select DATENAME(yy, OrderDate) as OrderYear, OrderId 
	  from HoaDonBanHang) as D 
PIVOT (count(OrderID) FOR OrderYear IN ([2007], [2008], [2009])) AS P 

--d) Tạo bảng pivot hiển thị số đơn đặt hàng được thực hiện bởi nhân viên có
--mã 1, 3, 4, 8, 9.
-- Tạo bảng tạm thời để lưu kết quả pivot
select E.EmployeeID , O.OrderID
from Employees E join Orders O on E.EmployeeID = O.EmployeeID
where E.EmployeeID in (1, 3, 4, 8, 9)

-- dung pivot 
select [1] as Em1, [3] as Em3 , [4] as Em4, [8] as Em8, as Em8 , [9] as Em9
from (select E.EmployeeID , O.OrderID 
      from Employees E join Orders O on E.EmployeeID=O.EmployeeID) AS D 
PIVOT (COUNT(OrderID) FOR EmployeeID IN ([1], [3], [4], [8], [9])) AS P
-- k dung pivot 
select E.EmployeeID , count(O.OrderID) as SoHD
from Employees E join Orders O on E.EmployeeID=O.EmployeeID) 
group by E.EmployeeID 
having E.EmployeeID in ('1','3','4','8','9')
go

