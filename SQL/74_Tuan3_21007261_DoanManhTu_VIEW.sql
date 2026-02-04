--Phan insert

--1) Tạo hai bảng mới trong cơ sở dữ liệu AdventureWorks2008 theo cấu trúc sau: 
create table 
MyDepartment ( 
DepID smallint not null primary 
key, DepName nvarchar(50), 
GrpName 
nvarchar(50) 
) 
create table MyEmployee ( 
EmpID int not null primary 
key, FrstName nvarchar(50), 
MidName 
nvarchar(50), 
LstName 
nvarchar(50), 
DepID smallint not null foreign key 
references MyDepartment(DepID) 
) 
--2) Dùng lệnh insert <TableName1> select <fieldList> from 
--<TableName2>  chèn dữ liệu cho bảng MyDepartment, lấy dữ liệu từ 
--bảng [HumanResources].[Department]. 

insert into dbo.MyDepartment (DepID, DepName, GrpName)
select DepartmentID, Name, GroupName 
from [HumanResources].[Department];

select *
from dbo.MyDepartment

--3) Tương tự câu 2, chèn 20 dòng dữ liệu cho bảng MyEmployee lấy dữ liệu 
--từ 2 bảng 
--[Person].[Person] và 
--[HumanResources].[EmployeeDepartmentHistory] 

insert into dbo.MyEmployee(EmpID,FrstName,LstName,DepID)
select top 20
P.BusinessEntityID,
P.FirstName,
P.LastName,
EDH.DepartmentID
from Person.Person as P join 
HumanResources.EmployeeDepartmentHistory as EDH on P.BusinessEntityID = EDH.BusinessEntityID

--4) Dùng lệnh delete xóa 1 record trong bảng MyDepartment với DepID=1, 
--có thực hiện được không? Vì sao? 

delete from MyDepartment where DepID = 1

--có thể thực hiện được
--nếu không thực hiện được thì bị dính ràng buộc nên phải xóa của MyEmployee trước

--5) Thêm một default constraint vào field DepID trong bảng MyEmployee, 
--với giá trị mặc định là 1. 
alter table MyEmployee
add constraint DF_MyEmployee_DepID default 1 for DepID;

--6)Nhập thêm một record mới trong bảng MyEmployee, theo cú pháp sau: 
--insert into MyEmployee (EmpID, FrstName, MidName, 
--LstName) values(1, 'Nguyen','Nhat','Nam'). Quan sát giá trị 
--trong field depID của record mới thêm. 

INSERT INTO MyDepartment (DepID)  
VALUES (1);

insert into MyEmployee (EmpID, FrstName, MidName, LstName) 
values(1, 'Nguyen','Nhat','Nam')

select * 
from MyDepartment

--Bị xung đột vì đã xóa depid 1 của mydepartment

--7) Xóa foreign key constraint trong bảng MyEmployee, thiết lập lại khóa ngoại 
--DepID tham chiếu đến DepID của bảng MyDepartment với thuộc tính on 
--delete set default. 

select name 
from sys.foreign_keys 
where parent_object_id = object_id('MyEmployee');

alter table MyEmployee  
drop constraint FK__MyEmploye__DepID__5B0E7E4A;  

alter table MyEmployee  
add constraint FK_MyEmployee_DepID  
foreign key (DepID) references MyDepartment(DepID)  
on delete set default;

--8) Xóa một record trong bảng MyDepartment có DepID=7, quan sát kết quả 
--trong hai bảng MyEmployee và MyDepartment

delete from MyDepartment where DepID = 7;

select *
from MyDepartment

select *
from MyEmployee

--9) Xóa foreign key trong bảng MyEmployee. Hiệu chỉnh ràng buộc khóa 
--ngoại DepID trong bảng MyEmployee, thiết lập thuộc tính on delete 
--cascade và on update cascade 

select name 
from sys.foreign_keys 
where parent_object_id = object_id('MyEmployee');

alter table MyEmployee  
drop constraint FK_MyEmployee_DepID;  

alter table MyEmployee  
add constraint FK_MyEmployee_DepID  
foreign key (DepID) references MyDepartment(DepID)  
on delete cascade  
on update cascade;

--10) Thực hiện xóa một record trong bảng MyDepartment với DepID =3, có 
--thực hiện được không? 

delete from MyDepartment where DepID = 3;

--11) Thêm ràng buộc check vào bảng MyDepartment tại field GrpName, chỉ cho 
--phép nhận thêm những Department thuộc group Manufacturing

alter table MyDepartment 
with nocheck
add constraint C_GrpName  
check (GrpName = 'Manufacturing');

insert into MyDepartment (DepID, DepName, GrpName)  
values (1301, 'Assembly', 'Manufacturing');  

insert into MyDepartment (DepID, DepName, GrpName)  
values (2222, 'IT Support', 'IT');  

select * from MyDepartment

--12) Thêm ràng buộc check vào bảng [HumanResources].[Employee], tại cột 
--BirthDate, chỉ cho phép nhập thêm nhân viên mới có tuổi từ 18 đến 60 


alter table HumanResources.Employee
with nocheck
add constraint BD_C 
check (datediff(year, BirthDate, getdate()) BETWEEN 18 AND 60);


--Phan VIEW
--1)  Tạo  view  dbo.vw_Products  hiển  thị  danh  sách  các  sản  phẩm  từ  bảng 
--Production.Product và bảng  Production.ProductCostHistory. Thông tin  bao gồm 
--ProductID, Name, Color, Size, Style, StandardCost, EndDate, StartDate

create view dbo.vw_Products
as
select P.ProductID, Name, Color, Size, Style, PCH.StandardCost, EndDate, StartDate
from Production.Product as P join
Production.ProductCostHistory as PCH on P.ProductID = PCH.ProductID

select * from dbo.vw_Products

--2)  Tạo view List_Product_View chứa danh sách các sản phẩm có trên 500 đơn đặt 
--hàng trong quí 1 năm 2008  và có tổng trị giá >10000, thông tin gồm ProductID, 
--Product_Name, CountOfOrderID và SubTotal.

create view List_Product_View 
as
select P.ProductID, P.Name as Product_Name, count(SOD.SalesOrderID) as CountOfOrderID,sum(SOD.OrderQty*SOD.UnitPrice) as SubTotal
from 
	Production.Product as P join 
	Sales.SalesOrderDetail as SOD on P.ProductID = SOD.ProductID join
	Sales.SalesOrderHeader as SOH on SOD.SalesOrderID = SOH.SalesOrderID
where 
	datepart(q, SOH.OrderDate) = 1 and year(SOH.OrderDate) = 2008
group by 
	P.ProductID, P.Name
having
	count(SOD.SalesOrderID) > 500 and sum(SOD.OrderQty*SOD.UnitPrice) > 1000

select * from List_Product_View

--3)  Tạo view dbo.vw_CustomerTotals  hiển thị tổng tiền bán được (total sales) từ cột 
--TotalDue của mỗi khách hàng (customer) theo tháng và theo năm. Thông tin gồm 
--CustomerID,  YEAR(OrderDate)  AS  OrderYear,  MONTH(OrderDate)  AS 
--OrderMonth,  SUM(TotalDue).

create view dbo.vw_CustomerTotals
as
select CustomerID,  YEAR(OrderDate)  AS  OrderYear,  MONTH(OrderDate)  AS OrderMonth,  SUM(TotalDue) as Total
from
	Sales.SalesOrderHeader as SOH 
group by CustomerID, OrderDate

select * from dbo.vw_CustomerTotals

--4)  Tạo view trả về tổng số lượng sản phẩm (Total Quantity) bán được của mỗi nhân 
--viên  theo  từng  năm.  Thông  tin gồm  SalesPersonID,  OrderYear,  sumOfOrderQty

create view Total_Quantity 
as
select  SOH.SalesPersonID,  year(OrderDate) as OrderYear,  sum(OrderQty) as sumOfOrderQty
from 
	Sales.SalesOrderHeader as SOH join
	Sales.SalesOrderDetail as SOD on SOH.SalesOrderID = SOD.SalesOrderID
group by OrderDate,OrderQty, SOH.SalesPersonID

select * from Total_Quantity 

--5)  Tạo view ListCustomer_view chứa danh sách các khách hàng có trên 25 hóa đơn 
--đặt hàng từ năm 2007 đến 2008, thông tin  gồm  mã khách (PersonID) , họ tên 
--(FirstName +'  '+ LastName as FullName), Số hóa đơn  (CountOfOrders).

create view ListCustomer_view
as 
select PersonID, FirstName +'  '+ LastName as FullName, count(SalesOrderID) as CountOfOrders
from 
	Sales.Customer as C join
	Sales.SalesOrderHeader as SOH on C.CustomerID = SOH.CustomerID join
	Person.Person as P on C.PersonID = P.BusinessEntityID
where
	year(OrderDate) between 2007 and 2008
group by 
	PersonID, FirstName, LastName
having
	count(SalesOrderID) >= 25

select * from ListCustomer_view

--6)  Tạo view ListProduct_view chứa danh sách những sản phẩm có tên bắt đầu với 
--‘Bike’ và ‘Sport’ có tổng số lượng bán trong mỗi năm trên  50 sản phẩm, thông 
--tin  gồm  ProductID,  Name,  SumOfOrderQty,  Year.  (dữ  liệu  lấy  từ  các  bảng
--Sales.SalesOrderHeader,          Sales.SalesOrderDetail,          và
--Production.Product)

create view ListProduct_view as
select
	P.ProductID,  Name, year(OrderDate) as Year , sum(OrderQty) as SumOfOrderQty
from
	Sales.SalesOrderHeader as SOH join
	Sales.SalesOrderDetail as SOD on SOH.SalesOrderID = SOD.SalesOrderID join
	Production.Product as P on SOD.ProductID = P.ProductID
where
	Name like 'Bike%' or Name like 'Sport%'
group by
	P.ProductID, Name, OrderDate
having
	sum(OrderQty) >= 50

select * from ListProduct_view

--7)  Tạo view List_department_View chứa  danh sách  các  phòng  ban  có lương  (Rate: 
--lương theo giờ) trung bình >30, thông tin gồm Mã phòng ban (DepartmentID), 
--tên phòng ban (Name), Lương trung bình (AvgOfRate). Dữ liệu từ các bảng 
--[HumanResources].[Department], 
--[HumanResources].[EmployeeDepartmentHistory], 
--[HumanResources].[EmployeePayHistory].

create view List_department_View as
select D.DepartmentID, Name, avg(Rate) as AvgOfRate
from
	HumanResources.Department as D join
	HumanResources.EmployeeDepartmentHistory as EDH on D.DepartmentID = EDH.DepartmentID join
	HumanResources.Employee as E on EDH.BusinessEntityID = E.BusinessEntityID join
	HumanResources.EmployeePayHistory as EPH on E.BusinessEntityID = EDH.BusinessEntityID
group by 
	d.DepartmentID,Name, Rate
having
	avg(Rate) > 30

select * from List_department_View

--8)  Tạo view  Sales.vw_OrderSummary  với từ khóa  WITH ENCRYPTION gồm 
--OrderYear  (năm  của  ngày  lập),  OrderMonth  (tháng  của  ngày  lập),  OrderTotal 
--(tổng tiền). Sau đó xem thông tin và trợ giúp về mã lệnh của view  này

create view Sales.vw_OrderSummary  WITH ENCRYPTION as
select
	year(OrderDate) as OrderYear, month(OrderDate) as OrderMonth, sum(OrderQty * UnitPrice) OrderTotal
from
	Sales.SalesOrderHeader as SOH join
	Sales.SalesOrderDetail as SOD on SOH.SalesOrderID = SOD.SalesOrderID
group by
	OrderDate

select * from Sales.vw_OrderSummary

EXEC sp_helptext 'Sales.vw_OrderSummary';

--9)  Tạo  view  Production.vwProducts  với  từ  khóa  WITH  SCHEMABINDING 
--gồm ProductID, Name, StartDate,EndDate,ListPrice  của  bảng Product và bảng 
--ProductCostHistory.  Xem  thông  tin  của  View.  Xóa  cột  ListPrice  của  bảng 
--Product. Có xóa được không? Vì sao?

create view Production.vwProducts with schemabinding as
select
	P.ProductID,
	Name,
	StartDate,EndDate,
	ListPrice
from
	Production.Product as P join
	Production.ProductCostHistory as PCH on P.ProductID = PCH.ProductID

select * from Production.vwProducts;

alter table Production.Product
drop column ListPrice;

--Không thể xóa vì WITH SCHEMABINDING giúp ràng buộc 
--View với bảng gốc, ngăn chặn các thay đổi làm ảnh hưởng đến View

--10) Tạo  view  view_Department  với  từ  khóa  WITH  CHECK  OPTION  chỉ  chứa  các 
--phòng  thuộc  nhóm  có  tên  (GroupName)  là  “Manufacturing”  và  “Quality 
--Assurance”, thông tin gồm: DepartmentID, Name,  GroupName.

create view view_Department  
as
select  
    DepartmentID,  
    Name,  
    GroupName  
from HumanResources.Department  
where GroupName IN ('Manufacturing', 'Quality Assurance')  
with check option;
 

--a.  Chèn thêm một phòng ban mới thuộc nhóm không  thuộc hai nhóm 
--“Manufacturing” và “Quality Assurance” thông qua view vừa tạo. Có 
--chèn được không? Giải thích.

insert into view_Department (Name, GroupName)  
values ('IT Support', 'Information Technology');

--Không chèn được vì WITH CHECK OPTION 
--không cho phép chèn dữ liệu không thỏa điều kiện của View.

--b.  Chèn  thêm  một  phòng  mới  thuộc  nhóm  “Manufacturing”  và  một 
--phòng thuộc nhóm “Quality  Assurance”.

insert into view_Department (Name, GroupName)  
values 
    ('Assembly', 'Manufacturing'),  
    ('Product Testing', 'Quality Assurance'); 

--chèn được vì chèn dữ liệu thỏa điều kiện của View.

--c.  Dùng câu lệnh Select xem kết quả trong bảng  Department.

select * from view_Department