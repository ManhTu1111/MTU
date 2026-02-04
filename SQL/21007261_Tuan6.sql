use Northwind
--1--
SELECT O.OrderID, O.OrderDate, SUM(OD.Quantity * OD.UnitPrice) AS Total
FROM orders AS O
INNER JOIN [dbo].[Order Details] AS OD ON O.OrderID = OD.OrderID
GROUP BY O.OrderID, O.OrderDate
--2--
SELECT O.OrderID, O.OrderDate, O.ShipCity, SUM(OD.Quantity * OD.UnitPrice) AS Total
FROM orders AS O
INNER JOIN [dbo].[Order Details] AS OD ON O.OrderID = OD.OrderID
WHERE O.ShipCity = 'Madrid'
GROUP BY O.OrderID, O.OrderDate, O.ShipCity
--3--
--3.1--
SELECT YEAR(OrderDate) AS Year, COUNT(*) AS CountOfOrders
FROM orders
GROUP BY YEAR(OrderDate)
--3.2--
SELECT YEAR(OrderDate) AS Year, MONTH(OrderDate) AS Month, COUNT(*) AS CountOfOrders
FROM orders
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
--3.3--
SELECT YEAR(OrderDate) AS Year, MONTH(OrderDate) AS Month, O.EmployeeID, COUNT(*) AS CountOfOrders
FROM orders AS O JOIN Employees AS E ON O.EmployeeID = E.EmployeeID
GROUP BY YEAR(OrderDate), MONTH(OrderDate), O.EmployeeID
--4--
SELECT O.EmployeeID, LastName+ ' '+ FirstName AS EmployeeName, COUNT(*) AS CountOfOrder
FROM employees as E
JOIN orders as O ON E.EmployeeID = O.EmployeeID
GROUP BY O.EmployeeID, LastName, FirstName
--5--
SELECT E.EmployeeID, LastName+ ' '+FirstName AS EmployeeName, 
       COUNT(O.OrderID) AS CountOfOrder, SUM(OD.UnitPrice * OD.Quantity) AS Total
FROM employees AS E
JOIN [dbo].[Orders] AS O ON E.EmployeeID = O.EmployeeID
JOIN [dbo].[Order Details] AS OD ON O.OrderID = OD.OrderID
GROUP BY E.EmployeeID, LastName, FirstName
--6--
SELECT employees.EmployeeID, CONCAT(employees.LastName, ' ', employees.FirstName) AS EmployeeName,
       MONTH(orders.OrderDate) AS Month_Salary,
       SUM(OD.Quantity * OD.UnitPrice) * 0.1 AS Salary
FROM employees
JOIN orders ON employees.EmployeeID = orders.EmployeeID
JOIN [dbo].[Order Details] AS OD ON orders.OrderID = OD.OrderID
WHERE YEAR(orders.OrderDate) = 1996
GROUP BY employees.EmployeeID, employees.LastName, employees.FirstName, MONTH(orders.OrderDate)
ORDER BY Month_Salary ASC, Salary DESC
--7--
SELECT employees.EmployeeID, employees.LastName, employees.FirstName,
       COUNT(orders.OrderID) AS CountOfOrder, SUM(OD.Quantity * OD.UnitPrice) AS Salary
FROM employees
JOIN orders ON employees.EmployeeID = orders.EmployeeID
JOIN [dbo].[Order Details] as OD ON orders.OrderID = OD.OrderID
WHERE YEAR(orders.OrderDate) = 1997 AND MONTH(orders.OrderDate) = 3
GROUP BY employees.EmployeeID, employees.LastName, employees.FirstName
HAVING SUM(OD.UnitPrice * OD.Quantity) > 4000;
--8--
SELECT customers.CustomerID, customers.CompanyName,
       COUNT(orders.OrderID) AS TotalOrders,
       SUM(OD.UnitPrice * OD.Quantity) AS TotalAmount
FROM customers
JOIN orders ON customers.CustomerID = orders.CustomerID
JOIN [dbo].[Order Details] AS OD ON orders.OrderID = OD.OrderID
WHERE orders.OrderDate >= '1996-12-31' AND orders.OrderDate <= '1998-01-01'
GROUP BY customers.CustomerID, customers.CompanyName
HAVING SUM(OD.UnitPrice * OD.Quantity) > 20000
ORDER BY customers.CustomerID ASC, TotalAmount DESC
--9--
SELECT customers.CustomerID, customers.CompanyName,
       CONCAT(MONTH(orders.OrderDate), '/', YEAR(orders.OrderDate)) AS Month_Year,
       SUM(OD.UnitPrice * OD.Quantity) AS Total
FROM customers
JOIN orders ON customers.CustomerID = orders.CustomerID
JOIN [dbo].[Order Details] as OD ON orders.OrderID = OD.OrderID
GROUP BY customers.CustomerID, customers.CompanyName, CONCAT(MONTH(orders.OrderDate), '/', YEAR(orders.OrderDate))
ORDER BY customers.CustomerID ASC, Month_Year ASC
--10--
SELECT categories.CategoryID, categories.CategoryName,
       SUM(products.UnitsInStock) AS Total_UnitsInStock,
       AVG(products.UnitPrice) AS Average_UnitPrice
FROM categories
JOIN products ON categories.CategoryID = products.CategoryID
GROUP BY categories.CategoryID, categories.CategoryName
HAVING SUM(products.UnitsInStock) > 300 AND AVG(products.UnitPrice) < 25
--11--
SELECT categories.CategoryID, categories.CategoryName, 
       COUNT(products.ProductID) AS CountOfProducts
FROM categories
JOIN products ON categories.CategoryID = products.CategoryID
GROUP BY categories.CategoryID, categories.CategoryName
HAVING COUNT(products.ProductID) > 10
ORDER BY categories.CategoryName ASC, CountOfProducts DESC
--12--
SELECT products.ProductID, products.ProductName,
       SUM(OD.Quantity) AS SumofQuantity
FROM products
JOIN [dbo].[Order Details] AS OD ON products.ProductID = OD.ProductID
JOIN orders ON OD.OrderID = orders.OrderID
WHERE YEAR(orders.OrderDate) = 1998 AND MONTH(orders.OrderDate) BETWEEN 1 AND 3
GROUP BY products.ProductID, products.ProductName
HAVING SUM(OD.Quantity) > 200
--13--
SELECT TOP 1 employees.EmployeeID, employees.FirstName, employees.LastName, 
       SUM(OD.Quantity * OD.UnitPrice) AS TotalSales
FROM employees
JOIN orders ON employees.EmployeeID = orders.EmployeeID
JOIN [dbo].[Order Details] AS OD ON orders.OrderID = OD.OrderID
WHERE YEAR(orders.OrderDate) = 1997 AND MONTH(orders.OrderDate) = 7 
GROUP BY employees.EmployeeID, employees.FirstName, employees.LastName
ORDER BY TotalSales DESC
--14--
SELECT top 3 customers.CustomerID, customers.CompanyName, 
       COUNT(orders.OrderID) AS OrderCount
FROM customers
JOIN orders ON customers.CustomerID = orders.CustomerID
WHERE YEAR(orders.OrderDate) = 1996
GROUP BY customers.CustomerID, customers.CompanyName
ORDER BY OrderCount DESC
--15--
SELECT top 1 products.ProductID, products.ProductName, COUNT(orders.OrderID) AS CountOfOrders
FROM products
JOIN [dbo].[Order Details] AS OD ON products.ProductID = OD.ProductID
JOIN orders ON OD.OrderID = orders.OrderID
GROUP BY products.ProductID, products.ProductName
ORDER BY CountOfOrders DESC

