use [AdventureWorks2008R2]
go

--1)  Viết  một  thủ  tục  tính  tổng  tiền  thu  (TotalDue)  của  mỗi  khách  hàng  trong  một 
--tháng bất kỳ của  một năm bất kỳ (tham số tháng và năm) được nhập từ bàn phím, 
--thông tin gồm: CustomerID, SumOfTotalDue  =Sum(TotalDue)

create proc sp_totaldue
	@year int, @month int
as
select CustomerID, SumOfTotalDue  =Sum(TotalDue), year(OrderDate) as Year, month(OrderDate) as Month
from Sales.SalesOrderHeader
where year(OrderDate) = @year and month(OrderDate) = @month
group by CustomerID, year(OrderDate), month(OrderDate)
go

exec sp_totaldue  2007, 7
go

--2)  Viết một thủ tục dùng để xem doanh thu từ đầu năm cho đến ngày hiện tại của 
--một nhân viên bất kỳ, với một tham số đầu vào và một tham số đầu ra. Tham số 
--@SalesPerson nhận giá trị đầu vào theo chỉ định khi gọi thủ tục, tham số 
--@SalesYTD được sử dụng để chứa giá trị trả về của thủ tục.

create proc sp_Saler @SalesPerson int = null ,@SalesYTD int output
as 
	select  @SalesYTD = sum(SubTotal)
	from Sales.SalesOrderHeader
	where SalesPersonID = @SalesPerson and  Month(OrderDate) = Month(getdate()) 
	and Day(OrderDate) = Day(getdate()) and Year(OrderDate) = 2008
	group by SalesPersonID
go


declare @t int
exec sp_Saler @SalesYTD = @t output
select @t as YTB
go

--3)  Viết một thủ tục trả về một danh sách ProductID, ListPrice của các sản phẩm có 
--giá bán không vượt quá một giá trị chỉ định (tham số input @MaxPrice).
create proc sp_maxprice @MaxPrice int 
as
	select ProductID, UnitPrice as ListPrice
	from Sales.SalesOrderDetail
	where UnitPrice <= @MaxPrice
go

exec sp_maxprice 1000
go

--4)  Viết thủ tục tên NewBonus cập nhật lại tiền thưởng (Bonus) cho 1 nhân viên bán 
--hàng (SalesPerson), dựa trên tổng doanh thu của nhân viên  đó. Mức thưởng mới 
--bằng mức thưởng hiện tại cộng thêm 1% tổng doanh thu. Thông tin bao gồm 
--[SalesPersonID], NewBonus (thưởng mới), SumOfSubTotal. Trong đó: 
--SumOfSubTotal =sum(SubTotal) 
--NewBonus = Bonus+ sum(SubTotal)*0.01 
create proc sp_NewBonus
as
	update Sales.SalesPerson
	set Bonus = T.NewBonus
	from Sales.SalesPerson P join(
		select SalesPersonID, NewBonus = Bonus + sum(SubTotal) * 0.01
		from Sales.SalesPerson P join
		Sales.SalesOrderHeader SOH on P.BusinessEntityID = SOH.SalesPersonID
		group by SalesPersonID, Bonus) T on P.BusinessEntityID = T.SalesPersonID
go

exec sp_NewBonus
go

--5)  Viết một thủ tục dùng để xem thông tin của nhóm sản phẩm (ProductCategory) 
--có tổng số lượng (OrderQty) đặt hàng cao nhất trong một năm tùy ý (tham số 
--input), thông tin gồm: ProductCategoryID, Name, SumOfQty. Dữ liệu từ bảng 
--ProductCategory, ProductSubCategory, Product và SalesOrderDetail.
--(Lưu ý: dùng Sub Query) 

create proc sp_PC @Year int
as
	select top 1 PC.ProductCategoryID, PS.Name, SumOfQty = sum(OrderQty)
	from Production.ProductSubcategory PS join
	Production.Product P on PS.ProductSubcategoryID = P.ProductSubcategoryID join
	Sales.SalesOrderDetail SOD on P.ProductID = SOD.ProductID join
	Production.ProductCategory PC on PS.ProductCategoryID = PC.ProductCategoryID
	where SalesOrderID in (
		select SalesOrderID 
		from Sales.SalesOrderHeader
		where YEAR(OrderDate) = @Year )
	group by PC.ProductCategoryID, PS.Name
	order by SumOfQty desc
go

exec sp_PC 2005
go

--6)  Tạo thủ tục đặt tên là TongThu  có tham số vào là mã nhân viên, tham số đầu ra 
--là tổng trị giá các hóa đơn nhân viên đó bán được. Sử dụng lệnh RETURN để trả 
--về trạng thái thành công hay thất bsại của thủ  tục.

create proc sp_tongthu @manv int, @thd money output
as
	if not exists (select 1 from Sales.SalesPerson where BusinessEntityID = @manv)
	begin
		print N'Nhân viên không tồn tại'
		return -1
	end

	select @thd = sum(SubTotal)
	from Sales.SalesOrderHeader
	where SalesPersonID = @manv

	print N'Thực hiện thành công'
	return 1
go



DECLARE @TongTien MONEY
DECLARE @Status INT

EXEC @Status = sp_TongThu @MaNV = 27, @thd = @TongTien OUTPUT

PRINT N'Tổng trị giá: ' + CAST(@TongTien AS NVARCHAR)
PRINT N'Trạng thái: ' + CAST(@Status AS NVARCHAR)
go


--7)  Tạo thủ tục hiển thị tên và số tiền mua của cửa hàng mua nhiều hàng nhất theo 
--năm đã cho.

create proc sp_top1store @year int
as
	select top 1 Name , sum(TotalDue) as Money
	from Sales.Store as S join
	Sales.SalesPerson as SP on S.SalesPersonID = SP.BusinessEntityID join
	Sales.SalesOrderHeader as SOH on SP.BusinessEntityID = SOH.SalesPersonID
	where year(OrderDate) = @year
	group by Name
	order by Money desc
go

exec sp_top1store 2005
go


--8)  Viết thủ tục Sp_InsertProduct có tham số dạng input dùng để chèn một mẫu tin 
--vào bảng Production.Product. Yêu cầu: chỉ thêm vào các trường có giá trị not 
--null và các field là khóa  ngoại.

create proc Sp_InsertProduct
    @Name NVARCHAR(50),
    @ProductNumber NVARCHAR(25),
    @MakeFlag BIT,
    @FinishedGoodsFlag BIT,
    @SafetyStockLevel SMALLINT,
    @ReorderPoint SMALLINT,
    @StandardCost MONEY,
    @ListPrice MONEY,
    @DaysToManufacture INT,
    @SellStartDate DATETIME,
    @rowguid UNIQUEIDENTIFIER,
    @ModifiedDate DATETIME
AS
    insert into Production.Product(Name, ProductNumber, MakeFlag, FinishedGoodsFlag, SafetyStockLevel, ReorderPoint, StandardCost, ListPrice, DaysToManufacture, SellStartDate, rowguid, ModifiedDate)
    values (@Name, @ProductNumber, @MakeFlag, @FinishedGoodsFlag, @SafetyStockLevel, @ReorderPoint, @StandardCost, @ListPrice, @DaysToManufacture, @SellStartDate, @rowguid, @ModifiedDate)
go

DECLARE @Guid UNIQUEIDENTIFIER, @time datetime;
SET @Guid = NEWID() 
SET @time = GETDATE();

EXEC Sp_InsertProduct
    @Name = N'Bicycle',
    @ProductNumber = 'BK-1234',
    @MakeFlag = 1,
    @FinishedGoodsFlag = 1,
    @SafetyStockLevel = 100,
    @ReorderPoint = 50,
    @StandardCost = 500.00,
    @ListPrice = 1000.00,
    @DaysToManufacture = 5,
    @SellStartDate = '2025-03-03',
    @rowguid = @Guid,
    @ModifiedDate = @time
go

--9)  Viết thủ tục XoaHD, dùng để xóa 1 hóa đơn trong bảng Sales.SalesOrderHeader 
--khi  biết  SalesOrderID.  Lưu  ý  :  trước  khi  xóa  mẫu  tin  trong 
--Sales.SalesOrderHeader  thì  phải  xóa  các  mẫu  tin  của  hoá  đơn  đó  trong 
--Sales.SalesOrderDetail. 

create proc sp_xoahd @spid int
as
	delete from Sales.SalesOrderDetail
	where SalesOrderID = @spid

	delete from Sales.SalesOrderHeader
	where SalesOrderID = @spid
	
	print'Xoa thanh cong'
go

exec sp_xoahd 43659
go

--10)  Viết  thủ  tục  Sp_Update_Product  có  tham  số  ProductId  dùng  để  tăng  listprice
--lên 10%  nếu  sản phẩm này tồn  tại,  ngược  lại  hiện  thông  báo  không  có  sản  phẩm
--này.

create proc Sp_Update_Product
    @ProductId INT
as
    if exists (select 1 from Production.Product where ProductID = @ProductId)
    begin
        update Production.Product
		set ListPrice = ListPrice * 1.10
        where ProductID = @ProductId;
        print N'Cập nhật giá thành công';
    end
    else
        PRINT N'Không có sản phẩm này';
go

exec Sp_Update_Product 1